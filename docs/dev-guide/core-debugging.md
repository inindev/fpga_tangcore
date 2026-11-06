# Debugging your core

## GAO debugging

Gowin FPGA debugging is mostly done through Gowin Analyzer Oscilloscope (GAO) over JTAG. JTAG is normally provided by the Sipeed BL616 firmware through USB. Now that TangCore has taken over the BL616, we need another way to provide JTAG functionality. We can do that with SOM connector on the FPGA module:

![](som-debug.jpg)

Here we use the 8-pin debug wire (provided by Sipeed with their boards), and Sipeed RV Debugger dongle (available on Sipeed store) to connect JTAG and UART (BL616_UART_TX to the RV debugger's RX pin).

This way we can use Gowin Analyzer Oscilloscope to debug our gateware as normal. You can also put the debugging bitstream (`ao_0.bin`) on the USB drive and use TangCore menu to program it if you need to.

## Monitor MCU-FPGA communcation

The BL616 MCU acts as the master in UART communication. Communication happens in commands and responses. If you need to observe the communication to help debugging your core, you can do that with the script `fpga_firmware-bl616/scripts/liveuart.py`. It will try to decode and dump the communication. There are two streams - BL616 to FPGA, and FPGA to BL616. So it would be better if you use a 2-UART USB-serial adapter, and connect the wires like this:

![](tangcore_uart.drawio.svg)

The TX pin carries the BL616-to-FPGA stream, and vice versa. For instance, core loading looks like this with `python fpga_tangcore\fpga_firmware-bl616\scripts\liveuart.py <com_port>` on the TX line,

```
fatfs: found /dev/sda
mount_volume: disk_initialize success
mount_volume: find_volume()=0

Writing 2303277 bytes...
ID=0001481b, status=70006020
Erase: pollFlag...
Erase: OK
Erase: disableCfg...
Erase: disableCfg done...
Erase: status=0x30000020

Erasing again...
ID=0001481b, status=30000020
Erase: pollFlag...
Erase: OK
Erase: disableCfg...
Erase: disableCfg done...
Erase: status=0x30000020

Load SRAM

Usercode=0x0000, status=0x70006020

Time: total=2169121 us, jtag=0 us, flash=0 us, writetdi=75 us<get_core_id>
<overlay_state:b'\x01'>

       -== TangCore ==-
NES
SNES
Game Boy Advance
MegaDrive / Genesis
Cores
Options
Version: Mar  7 2025<get_core_id>
<overlay_state:b'\x01'>
```

In addition to the text messages. Those in brackets (e.g. `<get_core_id>`) are commands sent to the FPGA, as listed in the protocol description next section. So this `printf`-style debugging is helpful in checking what is happening in realtime. You can check the firmware source code (`fpga_firmware-bl616/main.cpp`) to pinpoint problems.

You can also watch the traffic the other way (FPGA to MCU) on the other pin (BL616_UART_RX) with `python liveuart.py -f <com_port>`. It contains mostly joypad status updates and responses to other commands from the MCU.

## UART Protocol

The protocol is handled in `iosys_bl616.v` (the comment there is the reference). If you need to debug BL616-FPGA communication, then here's the protocol in use.

Every message is a frame: `0xAA frame_len[15:0] payload`, where the payload is `frame_len` bytes and starts with the command or response byte. Data lengths below are implied by `frame_len`.

| Command | Description |
|-----|-----|
|0x01|get core ID (response 0x01). Used to identify the core and check whether it is ready|
|0x02|get core config string (response 0x02)|
|0x03 x[31:0]|set core config status|
|0x04 x[7:0] y[7:0]|move overlay text cursor to (x, y)|
|0x05 <codes>|display characters from the cursor, one byte per character: the font's Latin-1 code (the firmware converts its UTF-8 text)|
|0x06 loading_state[7:0]|set loading state (0: core running, non-0: loading)|
|0x07 <data>|load data to rom_do|
|0x08 x[7:0]|x[0]: turn overlay on/off; x[1]: strip, only columns 8-23 of rows 23-24 on a dark band over the running game (volume bar)|
|0x09 hid1[15:0] hid2[15:0]|USB joystick state|
|0x0a <data_sector>|a sector (512 bytes) of data for the floppy data FIFO|
|0x0b addr[15:0] data[15:0]|write to the disk management interface|
|0x0c <scancode>|PS/2 scancode|
|0x0d <string>|debug printf; the core ignores it|
|0x0e volume[7:0]|master volume 0-10 (above 10: 10), 3 dB per step, 0 = mute; 7 from power-up|
|0x0f row[7:0] x0[7:0] x1[7:0]|overlay highlight bar on columns x0-x1 of row (row 0xFF: none)|
|0x10 code[7:0] <bytes>|font bytes from character `code` on (8 per character, top row first, bit 0 leftmost); only codes 0x80-0x9F are written (the volume bar's bitmap)|

Messages from FPGA to BL616:

| Response | Description |
|-----|-----|
|0x01 core_id[7:0]|core ID|
|0x02 <string>|core config string|
|0x03 joy1[15:0] joy2[15:0]|every 20 ms, DS2/SNES joypad state|
|0x04 lba[15:0] <data_512>|write a sector to disk|
|0x05 lba[15:0]|read a sector from disk (answered with command 0x0a)|


