# Troubleshooting

## There's no video output

Check the following,

* Have you flashed the correct firmware for your board with Bouffalo Flash Cube? There's one .ini file for each board.
* Make sure the monitor core, the bitstream that displays the menu, is in the FPGA's own flash: see [writing the menu core](installation.md#writing-the-menu-core). The FPGA loads it at power-on; `cores/<your_board>/monitor.bin` on the drive is only loaded from the Cores menu.
* For Primer/Console, use USB-OTG dongle with power pass-through to connect USB and power.
* For Mega, either use OTG or the USB-A Host port on the board to connect USB drive. If USB-A is used, make sure the switch below is set to "DBG" instead of "FPGA".
* Do NOT connect the board to PC for power when you intend to run TangCore. Use a separate power supply. The Sipeed firmware enters JTAG/debug mode when PC is detected, and TangCore itself switches to it (Device Mode) when it finds no SD card or USB drive and nothing on its USB port.
* If the screen shows "Device Mode", TangCore found no SD card or USB drive: connect one and power cycle.
* For Tang Mega, don't forget to turn on power (long press POWER button on top)

## I cannot navigate the menu

Check controller connection. Dualshock controller support is most stable:

* For Mega, insert the DS2 pmod into the left pmod socket (pmod0).
* For Console, use the top pmod socket (pmod1).
* For Primer, use the middle pmod socket for DS2.

If you use USB controllers,

* Only the Sipeed-provided USB gamepads can be used with the on-board USB-A port. If it is not recognized, replug the pad.
* Other types of USB gamepads needs a USB hub to work. Please follow instructions on the [controllers page](controllers.md).
* A keyboard or mouse on the hub, including wireless receivers such as Logitech's Bolt, doesn't
  take a gamepad's place: plug gamepads and keyboards in any order.
* Hubs with 8 or more ports work.

