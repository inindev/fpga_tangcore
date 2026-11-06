// Testbench for the master volume in hdmi/hdmi.sv: all 11 steps against the table in the
// audio plan, the largest and smallest samples (no overflow), a volume change being picked
// up, and a step above 10 reading as 10.
//
//   iverilog -g2012 -o tb_hdmi_gain.vvp common/test/tb_hdmi_gain.sv common/hdmi/hdmi.sv
//   vvp tb_hdmi_gain.vvp
//
// Icarus can't elaborate the packet modules, so this file has stand-ins for hdmi.sv's
// submodules: the packet_picker stand-in shows the scaled samples hdmi.sv hands it.

`timescale 1ns / 1ps

module tb_hdmi_gain;

logic clk = 0;
always #6.734 clk = ~clk;               // 74.25 MHz

logic [15:0] sample [1:0];
logic [3:0]  volume = 4'd7;
logic [2:0]  tmds;
logic        tmds_clock;
logic [10:0] cx;
logic [9:0]  cy;

hdmi #(.VIDEO_ID_CODE(4), .DVI_OUTPUT(0), .VIDEO_REFRESH_RATE(60.0), .AUDIO_RATE(48000),
       .AUDIO_BIT_WIDTH(16)) dut (
    .clk_pixel_x5(1'b0), .clk_pixel(clk), .clk_audio(1'b0), .reset(1'b0), .rgb(24'd0),
    .audio_sample_word(sample), .volume(volume),
    .tmds(tmds), .tmds_clock(tmds_clock), .cx(cx), .cy(cy), .frame_width(), .frame_height());

// k for gain = k / 256, steps 0-10 (audio_plan.md)
int k_table [0:10] = '{0, 11, 16, 23, 32, 46, 64, 91, 128, 181, 256};
int db_table [0:10] = '{0, -27, -24, -21, -18, -15, -12, -9, -6, -3, 0};

int errors = 0;
int checks = 0;

function automatic int scaled(input int ch);
    scaled = $signed(tb_hdmi_gain.dut.true_hdmi_output.packet_picker.audio_sample_word[ch]);
endfunction

// both channels after a few clocks: the multiplier alternates between them
task automatic check_samples(input int l, input int r, input int k);
    int got_l, got_r, exp_l, exp_r;
    sample[0] = l[15:0];
    sample[1] = r[15:0];
    repeat (6) @(posedge clk);
    #1;
    exp_l = (l * k) >>> 8;
    exp_r = (r * k) >>> 8;
    got_l = scaled(0);
    got_r = scaled(1);
    checks += 2;
    if (got_l !== exp_l || got_r !== exp_r) begin
        errors++;
        $display("  FAIL k=%0d: in %0d/%0d, out %0d/%0d, expected %0d/%0d",
                 k, l, r, got_l, got_r, exp_l, exp_r);
    end
    // no overflow: the output keeps the input's sign and is no larger
    if ((l < 0 && got_l > 0) || (l > 0 && got_l < 0) || (got_l > l && l >= 0) || (got_l < l && l < 0)) begin
        errors++;
        $display("  FAIL k=%0d: %0d became %0d", k, l, got_l);
    end
endtask

task automatic set_volume(input int v);
    volume = v[3:0];
    repeat (8) @(posedge clk);          // 2 synchronizer stages, 2 to agree, gain, multiplier
endtask

initial begin
    sample[0] = 0;
    sample[1] = 0;
    repeat (4) @(posedge clk);

    $display("step  dB    k   gain  32767 ->  -32768 ->  12345 ->  -1 ->");
    for (int v = 0; v <= 10; v++) begin
        set_volume(v);
        checks++;
        if (dut.true_hdmi_output.gain !== k_table[v]) begin
            errors++;
            $display("  FAIL step %0d: gain %0d, expected %0d", v, dut.true_hdmi_output.gain, k_table[v]);
        end
        check_samples(32767, -32768, k_table[v]);
        if (v == 0)
            $write("%4d  mute", v);
        else
            $write("%4d  %3d ", v, db_table[v]);
        $write("  %3d  %0.3f  %6d   ", k_table[v], k_table[v] / 256.0, scaled(0));
        $write("%7d   ", scaled(1));
        check_samples(-32768, 32767, k_table[v]);
        check_samples(12345, -1, k_table[v]);
        $display("%6d   %3d", scaled(0), scaled(1));
        check_samples(1, -12345, k_table[v]);
        check_samples(0, 0, k_table[v]);
        check_samples(-2, 255, k_table[v]);
    end

    // a change while samples keep coming: 3 -> 9, the first clock the new gain shows
    set_volume(3);
    sample[0] = 16'd20000;
    sample[1] = 16'd20000;
    repeat (6) @(posedge clk);
    volume = 4'd9;
    begin
        int n;
        for (n = 1; n <= 40; n++) begin
            @(posedge clk);
            #1;
            if (scaled(0) == (20000 * 181) >>> 8 && scaled(1) == (20000 * 181) >>> 8)
                break;
        end
        checks++;
        if (n > 40) begin
            errors++;
            $display("FAIL volume change 3 -> 9 not picked up after 40 clocks");
        end else
            $display("volume 3 -> 9: 20000 -> %0d after %0d pixel clocks", scaled(0), n);
    end

    // above 10 reads as 10 (0 dB)
    set_volume(15);
    checks++;
    if (dut.true_hdmi_output.gain !== 256) begin
        errors++;
        $display("FAIL volume 15: gain %0d, expected 256", dut.true_hdmi_output.gain);
    end
    check_samples(32767, -32768, 256);
    $display("volume 15: 32767 -> %0d, -32768 -> %0d", scaled(0), scaled(1));

    $display("%0d checks, %0d failed: %s", checks, errors, errors ? "FAIL" : "PASS");
    $finish;
end

endmodule

// Stand-ins for hdmi.sv's submodules
module packet_picker #(
    parameter int VIDEO_ID_CODE = 4,
    parameter real VIDEO_RATE = 0,
    parameter bit IT_CONTENT = 1'b0,
    parameter int AUDIO_BIT_WIDTH = 0,
    parameter int AUDIO_RATE = 0,
    parameter bit [8*8-1:0] VENDOR_NAME = 0,
    parameter bit [8*16-1:0] PRODUCT_DESCRIPTION = 0,
    parameter bit [7:0] SOURCE_DEVICE_INFORMATION = 0,
    parameter bit [1:0] RGB_QUANTIZATION_RANGE = 2'b00,
    parameter bit [1:0] CONTENT_TYPE = 2'b00
) (
    input logic clk_pixel,
    input logic clk_audio,
    input logic reset,
    input logic video_field_end,
    input logic packet_enable,
    input logic [4:0] packet_pixel_counter,
    input logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word [1:0],
    output logic [23:0] header,
    output logic [55:0] sub [3:0]
);
assign header = 24'd0;
assign sub[0] = 56'd0;
assign sub[1] = 56'd0;
assign sub[2] = 56'd0;
assign sub[3] = 56'd0;
endmodule

module packet_assembler (
    input logic clk_pixel,
    input logic reset,
    input logic data_island_period,
    input logic [23:0] header,
    input logic [55:0] sub [3:0],
    output logic [8:0] packet_data,
    output logic [4:0] counter
);
assign packet_data = 9'd0;
assign counter = 5'd0;
endmodule

module tmds_channel #(parameter int CN = 0) (
    input logic clk_pixel,
    input logic [7:0] video_data,
    input logic [3:0] data_island_data,
    input logic [1:0] control_data,
    input logic [2:0] mode,
    output logic [9:0] tmds
);
assign tmds = 10'd0;
endmodule

module serializer #(parameter int NUM_CHANNELS = 3, parameter real VIDEO_RATE = 0) (
    input logic clk_pixel,
    input logic clk_pixel_x5,
    input logic reset,
    input logic [9:0] tmds_internal [NUM_CHANNELS-1:0],
    output logic [2:0] tmds,
    output logic tmds_clock
);
assign tmds = 3'd0;
assign tmds_clock = 1'b0;
endmodule
