// Modified for tangcore (2026-11-14): one strobe per received byte, setup watchdog, clock
// enable (CE_NUM/CE_DEN), from the low-speed pad fixes in inindev's fpga_game_consoles; ROM
// grown for the longer setup in firmware/ukp.s. See git history.
//
// Usb_hid_host: A compact USB HID host core.
//
// nand2mario, 8/2023, based on work by hi631
//
// This should support keyboard, mouse and gamepad input out of the box, over low-speed
// USB (1.5Mbps). Just connect D+, D-, VBUS (5V) and GND, and two 15K resistors between
// D+ and GND, D- and GND. Then provide a 12Mhz clock through usbclk.
//
// Without a 12 MHz clock, use a faster usbclk and set CE_NUM/CE_DEN so that
// usbclk * CE_NUM / CE_DEN = 12 MHz (e.g. 86.4 MHz * 5/36). The core then advances on an
// internal clock enable that averages exactly 12 MHz; each edge it drives or samples is
// off by at most one usbclk period. Pulses (report) last one clock-enable period.
//
// See https://github.com/nand2mario/usb_hid_host
//
// 3/22/2025: add LB and RB buttons, and SNES layout output `game_snes`

module usb_hid_host #(
    parameter CE_NUM = 1,           // clock enable rate = CE_NUM / CE_DEN of usbclk
    parameter CE_DEN = 1,           // 1/1: usbclk is 12 MHz
    parameter SETUP_TIMEOUT = 18_000_000    // clock-enable ticks (1.5 s), see setup watchdog
) (
    input  usbclk,		            // 12MHz clock, or faster with CE_NUM/CE_DEN
    input  usbrst_n,	            // reset
    inout  usb_dm, usb_dp,          // USB D- and D+

    output reg [1:0] typ,           // device type. 0: no device, 1: keyboard, 2: mouse, 3: gamepad
    output reg report,              // pulse after report received from device. 
                                    // key_*, mouse_*, game_* valid depending on typ
    output conerr,                  // connection or protocol error

    // keyboard
    output reg [7:0] key_modifiers,
    output reg [7:0] key1, key2, key3, key4,

    // mouse
    output reg [7:0] mouse_btn,     // {5'bx, middle, right, left}
    output reg signed [7:0] mouse_dx,      // signed 8-bit, cleared after `report` pulse
    output reg signed [7:0] mouse_dy,      // signed 8-bit, cleared after `report` pulse

    // gamepad 
    output [11:0] game_snes,        // SNES layout buttons (R L X A RT LT DN UP START SELECT Y B)
    output reg game_l, game_r, game_u, game_d,  // left right up down
    output reg game_a, game_b, game_x, game_y, game_sel, game_sta,  // buttons 
    output reg game_lb, game_rb,

    // debug
    output connected,               // device set up and being polled
    output reg restart,             // pulse: setup watchdog restarted the device

    output [63:0] dbg_hid_report	// last HID report
);

// Clock enable: CE_NUM ticks every CE_DEN usbclk cycles, as evenly spaced as possible.
reg [15:0] ce_acc = 0;
reg ce = 0;
always @(posedge usbclk) begin
    if (ce_acc + CE_NUM >= CE_DEN) begin
        ce_acc <= ce_acc + CE_NUM - CE_DEN;
        ce <= 1;
    end else begin
        ce_acc <= ce_acc + CE_NUM;
        ce <= 0;
    end
end

wire data_rdy;          // data ready
wire data_strobe;       // data strobe for each byte
wire [7:0] ukpdat;		// actual data
reg [7:0] regs [7];     // 0 (VID_L), 1 (VID_H), 2 (PID_L), 3 (PID_H), 4 (INTERFACE_CLASS), 5 (INTERFACE_SUBCLASS), 6 (INTERFACE_PROTOCOL)
wire save;			    // save dat[b] to output register r
wire [3:0] save_r;      // which register to save to
wire [3:0] save_b;      // dat[b]
reg retry = 0;          // retry because we did not detect a HID device

assign game_snes = {game_rb, game_lb, game_x, game_a, game_r, game_l, game_d, game_u, game_sta, game_sel, game_y, game_b};

ukp ukp(
    .usbrst_n(usbrst_n & ~retry & ~restart), .usbclk(usbclk), .ce(ce),
    .usb_dp(usb_dp), .usb_dm(usb_dm), .usb_oe(),
    .ukprdy(data_rdy), .ukpstb(data_strobe), .ukpdat(ukpdat), .save(save), .save_r(save_r), .save_b(save_b),
    .connected(connected), .conerr(conerr));

// Setup watchdog. The ukp program repeats each setup step for as long as the device NAKs
// or does not answer, and every attempt resets ukp's own watchdog, so a device that missed
// a setup packet leaves the core stuck before `connected`. Restart the ukp if a device is
// attached but not connected for SETUP_TIMEOUT ticks (normal setup takes ~0.3 s).
// Attached: not a long SE0. An empty port reads SE0 (both pull-downs); with a low-speed
// device D- is high between packets, and SE0 lasts only for EOPs and bus resets (10 ms).
reg        line_dp = 0, line_dm = 0;
reg [10:0] se0_cnt = 0;                 // ticks of continuous SE0, saturating
reg [24:0] setup_cnt = 0;
initial restart = 0;
wire       se0_long = se0_cnt == 11'd1200;              // 100 us
always @(posedge usbclk) if (ce) begin
    line_dp <= usb_dp; line_dm <= usb_dm;
    if (line_dp | line_dm) se0_cnt <= 0;
    else if (~se0_long)    se0_cnt <= se0_cnt + 11'd1;
    restart <= 0;
    if (~usbrst_n || connected || se0_long) setup_cnt <= 0;
    else if (setup_cnt == SETUP_TIMEOUT) begin
        setup_cnt <= 0;
        restart <= 1;
    end else
        setup_cnt <= setup_cnt + 25'd1;
end

reg  [3:0] rcvct;		// counter for recv data
reg  data_strobe_r, data_rdy_r;	// delayed data_strobe and data_rdy
reg  [7:0] dat[8];		// data in last response
assign dbg_hid_report = {dat[7], dat[6], dat[5], dat[4], dat[3], dat[2], dat[1], dat[0]};
// assign dbg_regs = regs;

// Gamepad types, see response_recognition below
// localparam D_GENERIC = 0;
// localparam D_GAMEPAD = 1;			
// localparam D_DS2_ADAPTER = 2;
// reg [3:0] dev = D_GENERIC;			// device type recognized through VID/PID
// assign dbg_dev = dev;

reg valid = 0;		    // whether current gamepad report is valid

always @(posedge usbclk) if (ce) begin : process_in_data
    data_rdy_r <= data_rdy; data_strobe_r <= data_strobe;
    report <= 0;                    // ensure pulse
    if (report == 1) begin
        // clear mouse movement for later
        mouse_dx <= 0; mouse_dy <= 0;
    end
    if(~data_rdy) rcvct <= 0;
    else begin
        if(data_strobe && ~data_strobe_r) begin  // rising edge of ukp data strobe
            dat[rcvct] <= ukpdat;

            if (typ == 1) begin     // keyboard
                case (rcvct)
                0: key_modifiers <= ukpdat;
                2: key1 <= ukpdat;
                3: key2 <= ukpdat;
                4: key3 <= ukpdat;
                5: key4 <= ukpdat;
                endcase
            end else if (typ == 2) begin    // mouse
                case (rcvct)
                0: mouse_btn <= ukpdat;
                1: mouse_dx <= ukpdat;
                2: mouse_dy <= ukpdat;
                endcase
            end else if (typ == 3) begin    // gamepad
                // A typical report layout:
                // - d[3] is X axis (0: left, 255: right)
                // - d[4] is Y axis
                // - d[5][7:4] is buttons YBAX
                // - d[6][5:4] is buttons START,SELECT
                // - d[6][1:0] is buttons LB,RB
                // Variations:
                // - Some gamepads uses d[0] and d[1] for X and Y axis.
                // - Some transmits a different set when d[0][1:0] is 2 (a dualshock adapater)
                case (rcvct)
                0: begin
                    if (ukpdat[1:0] != 2'b10) begin
                        // for DualShock2 adapter, 2'b10 marks an irrelevant record
                        valid <= 1;
                        // game_l <= 0; game_r <= 0; game_u <= 0; game_d <= 0;
                    end else
                        valid <= 0;
                    if (ukpdat==8'h00) {game_l, game_r} <= 2'b10;
                    if (ukpdat==8'h7f) {game_l, game_r} <= 2'b00;
                    if (ukpdat==8'hff) {game_l, game_r} <= 2'b01;
                end
                1: begin
                    if (ukpdat==8'h00) {game_u, game_d} <= 2'b10;
                    if (ukpdat==8'h7f) {game_u, game_d} <= 2'b00;
                    if (ukpdat==8'hff) {game_u, game_d} <= 2'b01;
                end
                // 3: if (valid) begin 
                //     if (ukpdat[7:6]==2'b00) {game_l, game_r} <= 2'b10;
                //     if (ukpdat[7:6]==2'b11) {game_l, game_r} <= 2'b01;
                // end
                // 4: if (valid) begin 
                //     if (ukpdat[7:6]==2'b00) {game_u, game_d} <= 2'b10;
                //     if (ukpdat[7:6]==2'b11) {game_u, game_d} <= 2'b01;
                // end
                5: if (valid) begin
                    game_x <= ukpdat[4];
                    game_a <= ukpdat[5];
                    game_b <= ukpdat[6];
                    game_y <= ukpdat[7];
                end
                6: if (valid) begin
                    game_sel <= ukpdat[4];
                    game_sta <= ukpdat[5];
                    game_lb <= ukpdat[0];
                    game_rb <= ukpdat[1];
                end
                endcase
                // TODO: add any special handling if needed 
                // (using the detected controller type in 'dev')                
            end
            rcvct <= rcvct + 1;
        end
    end
    if(~data_rdy && data_rdy_r && typ != 0)    // falling edge of ukp data ready
        report <= 1;
    if (conerr) begin                          // clear everything on connection error
        game_l <= 0; game_r <= 0; game_u <= 0; game_d <= 0;
        game_a <= 0; game_b <= 0; game_x <= 0; game_y <= 0;
        game_sel <= 0; game_sta <= 0;
        game_lb <= 0; game_rb <= 0;
    end
end

reg save_delayed;
reg connected_r;
always @(posedge usbclk) if (ce) begin : response_recognition
    save_delayed <= save;
    retry <= 0;
    if (save) begin
        regs[save_r] <= dat[save_b];
    end else if (save_delayed && ~save && save_r == 6) begin     
        // falling edge of save for bInterfaceProtocol
        if (regs[4] == 3) begin  // bInterfaceClass. 3: HID, other: non-HID
            if (regs[5] == 1)    // bInterfaceSubClass. 1: Boot device
                typ <= regs[6] == 1 ? 1 : 2;     // bInterfaceProtocol. 1: keyboard, 2: mouse
            else
                typ <= 3;       // gamepad
        end else
            retry <= 1;  // not a HID device, wait a while (200ms) and retry
    end
    connected_r <= connected;
    if (~connected & connected_r) typ <= 0;   // clear device type on disconnect
    if (restart) typ <= 0;
end

endmodule

module ukp(
    input usbrst_n,
    input usbclk,				// 12MHz clock, or faster with ce
    input ce,                   // clock enable, averaging 12 MHz (1 if usbclk is 12 MHz)
    inout usb_dp, usb_dm,		// D+, D-
    output usb_oe,
    output reg ukprdy, 			// data frame is outputing
    output ukpstb,				// strobe for a byte within the frame
    output reg [7:0] ukpdat,	// output data when ukpstb=1
    output reg save,			// save: regs[save_r] <= dat[save_b]
    output reg [3:0] save_r, save_b,
    output reg connected,
    output conerr
);

    parameter S_OPCODE = 0;
    parameter S_LDI0 = 1;
    parameter S_LDI1 = 2;
    parameter S_B0 = 3;
    parameter S_B1 = 4;
    parameter S_B2 = 5;
    parameter S_S0 = 6;
    parameter S_S1 = 7;
    parameter S_S2 = 8;
    parameter S_TOGGLE0 = 9;
    parameter S_TOGGLE1 = 10;

    wire [3:0] inst;
    reg  [3:0] insth;
    wire sample;						// 1: an IN sample is available
    // reg connected = 0;
    reg inst_ready = 0, up = 0, um = 0, cond = 0, nak = 0, dmis = 0;
    reg ug, ugw, nrzon;					// ug=1: output enabled, 0: hi-Z
    reg bank = 0, record1 = 0;
    reg [1:0] mbit = 0;					// 1: out4/outb is transmitting
    reg [3:0] state = 0, stated;
    reg [7:0] wk = 0;					// W register
    reg [7:0] sb = 0;					// out value
    reg [3:0] sadr;						// out4/outb write ptr
    reg [13:0] pc = 0, wpc;				// program counter, wpc = next pc
    reg [2:0] timing = 0;				// T register (0~7)
    reg [3:0] lb4 = 0, lb4w;
    reg [13:0] interval = 0;
    reg [6:0] bitadr = 0;				// 0~127
    reg [7:0] data = 0;					// received data
    reg [2:0] nrztxct, nrzrxct;			// NRZI trans/recv count for bit stuffing
    wire interval_cy = interval == 12001;
    wire next = ~(state == S_OPCODE & (
        inst ==2 & dmi |								// start
        (inst==4 || inst==5) & timing != 0 |			// out0/hiz
        inst ==13 & (~sample | (dpi | dmi) & wk != 1) |	// in 
        inst ==14 & ~interval_cy						// wait
    ));
    wire branch = state == S_B1 & cond;
    wire retpc  = state == S_OPCODE && inst==7  ? 1 : 0;
    wire jmppc  = state == S_OPCODE && inst==15 ? 1 : 0;
    wire dbit   = sb[7-sadr[2:0]];
    wire record;
    reg  dmid;
    reg [6:0] stb_adr = 7'h7f;          // bitadr of the last byte strobe in this packet
    reg [23:0] conct;
    assign conerr = conct[23] || ~usbrst_n;

    usb_hid_host_rom ukprom(.clk(usbclk), .ce(ce), .adr(pc), .data(inst));

    always @(posedge usbclk) if (ce) begin
        if(~usbrst_n) begin 
            pc <= 0; connected <= 0; cond <= 0; inst_ready <= 0; state <= S_OPCODE; timing <= 0; 
            mbit <= 0; bitadr <= 0; nak <= 1; ug <= 0;
            save <= 0;
            dpi <= usb_dp; dmi <= usb_dm;
        end else begin
            dpi <= usb_dp; dmi <= usb_dm;
            save <= 0;		// ensure pulse
            if (inst_ready) begin
                // Instruction decoding
                case(state)
                    S_OPCODE: begin
                        insth <= inst;
                        if(inst==1) state <= S_LDI0;						// op=ldi
                        if(inst==3) begin sadr <= 3; state <= S_S0; end		// op=out4
                        if(inst==4) begin ug <= 9; up <= 0; um <= 0; end
                        if(inst==5) begin ug <= 0; end
                        if(inst==6) begin sadr <= 7; state <= S_S0; end		// op=outb
                        if (inst[3:2]==2'b10) begin							// op=10xx(BZ,BC,BNAK,DJNZ)
                            state <= S_B0;
                            case (inst[1:0])
                                2'b00: cond <= ~dmi;
                                2'b01: cond <= connected;
                                2'b10: cond <= nak;
                                2'b11: cond <= wk != 1;
                            endcase
                        end
                        if(inst==11 | inst==13 & sample) wk <= wk - 8'd1;	// op=DJNZ,IN
                        if(inst==15) begin state <= S_B2; cond <= 1; end	// op=jmp
                        if(inst==12) state <= S_TOGGLE0;
                    end
                    // Instructions with operands
                    // ldi
                    S_LDI0: begin	wk[3:0] <= inst; state <= S_LDI1;	end
                    S_LDI1: begin	wk[7:4] <= inst; state <= S_OPCODE; end
                    // branch/jmp
                    S_B2: begin lb4w <= inst; state <= S_B0; end
                    S_B0: begin lb4  <= inst; state <= S_B1; end
                    S_B1: state <= S_OPCODE;
                    // out
                    S_S0: begin sb[3:0] <= inst; state <= S_S1; end
                    S_S1: begin sb[7:4] <= inst; state <= S_S2; mbit <= 1; end
                    // toggle and save
                    S_TOGGLE0: begin 
                        if (inst == 15) connected <= ~connected;// toggle
                        else save_r <= inst;                    // save
                        state <= S_TOGGLE1;
                      end
                    S_TOGGLE1: begin
                        if (inst != 15) begin
                            save_b <= inst;
                            save <= 1;
                        end
                        state <= S_OPCODE;
                    end
                endcase
                // pc control
                if (mbit==0) begin 
                    if(jmppc) wpc <= pc + 4;
                    if (next | branch | retpc) begin
                        if(retpc) pc <= wpc;					// ret
                        else if(branch)
                            if(insth==15)						// jmp
                                pc <= { inst, lb4, lb4w, 2'b00 };
                            else								// branch
                                pc <= { 4'b0000, inst, lb4, 2'b00 };
                        else	pc <= pc + 1;					// next
                        inst_ready <= 0;
                    end
                end
            end
            else inst_ready <= 1;
            // bit transmission (out4/outb)
            if (mbit==1 && timing == 0) begin
                if(ug==0) nrztxct <= 0;
                else
                    if(dbit) nrztxct <= nrztxct + 1;
                    else     nrztxct <= 0;
                if(insth == 4'd6) begin
                    if(nrztxct!=6) begin up <= dbit ?  up : ~up; um <= dbit ? ~up :  up; end
                    else           begin up <= ~up; um <= up; nrztxct <= 0; end
                end else begin
                    up <=  sb[{1'b1,sadr[1:0]}]; um <= sb[sadr[2:0]];
                end
                ug <= 1'b1; 
                if(nrztxct!=6) sadr <= sadr - 4'd1;
                if(sadr==0) begin mbit <= 0; state <= S_OPCODE; end
            end
            // start instruction
            dmid <= dmi;
            if (inst_ready & state == S_OPCODE & inst == 4'b0010) begin // op=start 
                bitadr <= 0; nak <= 1; nrzrxct <= 0; stb_adr <= 7'h7f;
            end else
                if(ug==0 && dmi!=dmid) timing <= 1;
                else                   timing <= timing + 1;
            // IN instruction
            if (sample) begin
                if (bitadr == 8) nak <= dmi;
                if(nrzrxct!=6) begin
                    data[6:0] <= data[7:1]; 
                    data[7] <= dmis ~^ dmi;		    // ~^/^~ is XNOR, testing bit equality
                    bitadr <= bitadr + 1; nrzon <= 0;
                end else nrzon <= 1;
                dmis <= dmi;
                if(dmis ~^ dmi) nrzrxct <= nrzrxct + 1;
                else           nrzrxct <= 0;
                if (~dmi && ~dpi) ukprdy <= 0;      // SE0: packet is finished. Mouses send length 4 reports.
            end
            if (ug==0) begin
                if(bitadr==24) ukprdy <= 1;			// ignore first 3 bytes
                if(bitadr==88) ukprdy <= 0;			// output next 8 bytes
            end
            if ((bitadr>11 & bitadr[2:0] == 3'b000) & (timing == 2)) ukpdat <= data;
            if (ukpstb) stb_adr <= bitadr;     // see ukpstb below
            // Timing
            interval <= interval_cy ? 0 : interval + 1;
            record1 <= record;
            if (~record & record1) bank <= ~bank;
            // Connection status & WDT
            ukprdyd <= ukprdy;
            nakd <= nak;
            if (ukprdy && ~ukprdyd || inst_ready && state == S_OPCODE && inst == 4'b0010) 
                conct <= 0;     // reset watchdog on data received or START instruction
            else begin 
                if(conct[23:22]!=2'b11) conct <= conct + 1;
                else begin pc <= 0; conct <= 0; end		// !! WDT ON
            end 
        end
    end

    assign usb_dp = ug ? up : 1'bZ;
    assign usb_dm = ug ? um : 1'bZ;
    assign usb_oe = ug;
    assign sample = inst_ready & state == S_OPCODE & inst == 4'b1101 & timing == 4; // IN
    assign record = connected & ~nak;
    // One strobe per byte. After the longest run without transitions (7 bit times, e.g.
    // bytes 7F 7F) a slow device's next edge can arrive after `timing` wraps, so timing == 2
    // can occur twice for the same bitadr; stb_adr suppresses the second one.
    assign ukpstb = ~nrzon & ukprdy & (bitadr[2:0] == 3'b100) & (timing == 2) & (bitadr != stb_adr);
    reg    dpi, dmi; 
    reg    ukprdyd;
    reg    nakd;
endmodule

module usb_hid_host_rom(clk, ce, adr, data);
	input clk;
	input ce;
	input [13:0] adr;
	output [3:0] data;
	reg [3:0] data;
	reg [3:0] mem [844];            // size of usb_hid_host_rom.hex (firmware/asukp.py prints it)
	initial $readmemh("usb_hid_host_rom.hex", mem);
	always @(posedge clk) if (ce) data <= mem[adr];
endmodule

// Two-flop synchronizer for the button outputs (game_snes), into the clock of the logic that
// reads them. Each button is its own bit, so bit by bit is enough: a report that lands on a
// clock edge shows a changed button one sample early or late. The first stage, usb_meta,
// matches the *_meta false path in each core's .sdc.
module usb_hid_sync #(parameter W = 12) (
    input clk,
    input [W-1:0] d,                // from the usbclk domain
    output reg [W-1:0] q
);
reg [W-1:0] usb_meta;
always @(posedge clk) begin
    usb_meta <= d;
    q <= usb_meta;
end
endmodule
