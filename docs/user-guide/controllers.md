# Game Controllers

TangCore supports several types of game controllers including Dualshock 2 (DS2), USB HID, and USB Xinput devices. Controller compatibility will continue to improve with future updates. 

Instructions for USB controllers,

* To connect the SNES-style USB controllers sold by Sipeed with Tang Console, you can plug them into the bottom two USA-A ports of the board. These two ports are connected to the FPGA, and currently the FPGA only supports this model of USB gamepad directly.
* **For other USB controllers, you need a USB hub** with at least 3 ports - one for the USB drive and two for controllers. The hub also needs to support "power passthrough", so it provides power to the board. Here is [a list of working USB hubs](https://github.com/nand2mario/tangcore/wiki/Compatible-USB-Hubs). The hub should be plugged into the bottom-left USB-C port of the board, i.e. connecting to the BL616 MCU.

Here are some test results for controllers.

| Controller | Status | Photo |
|-----|-----|-----|
| DualShock 2 or compatible | ✅ Fully working (requires DS2 PMOD adapter) | ![](gamepad_ds2.jpg){: style="width:150px"} |
| Sipeed SNES-style USB Controller | ✅ Fully working | ![](gamepad_snes.jpg){: style="width:150px"} |
| 8BitDo SN30 Pro Wired Controller | ✅ Fully working (USB hub needed) | ![](gamepad_sn30pro.jpg){: style="width:150px"} |
| 8BitDo Wireless USB Adapter | ✅ Fully working (USB hub needed) | ![](gamepad_8bitdo_adapter.jpg){: style="width:150px"} |

My personal favorite is the 8BitDo wireless adapter paired with an 8BitDo Pro 2 controller. It offers excellent button layout, reliable wireless connectivity, and minimal input lag. Please note that each adapter can only pair with one controller, so you'll need two adapters for two-player gaming.

USB keyboards work too, through the hub: in the menu, and in the PC/XT core.

## Controls

In the menu:

| | Gamepad | Keyboard |
|---|---|---|
| Move | Up / Down | Arrow keys |
| Previous / next page | Left / Right (wraps around from the last page to the first) | Arrow keys |
| Choose | B in the main menu, A or B in file lists | Space or S is B, Enter or D is A |

The row under the menu shows which buttons apply on each screen.

While a game runs:

| | Gamepad | Keyboard |
|---|---|---|
| Open the menu | Hold Select + Start for half a second | F12 |
| Close the menu, back to the game | Select + Start, or **Resume game** at the top of the main menu | F12 |
| Volume down / up | Select + L / Select + R | Ctrl + `-` / Ctrl + `=` |

The gamepad's menu button can be Select + Right instead: see [options](#options).

The volume has 11 steps, from mute to 10, and starts at 7. Each press shows a volume bar over
the game for a moment; the Game Boy Advance core on the 60K boards changes the volume without
showing the bar.

## Options

**Options** in the main menu sets:

| Setting | Choices |
|---|---|
| Font | **Serif** (default) or Sans, for all the menu text |
| Menu button | **Select + Start** (default) or Select + Right, the gamepad buttons that open and close the menu |

Left and Right change the highlighted setting, and a new font shows at once; A or B go back.
The settings are saved when you leave Options, in `tangcore.ini` at the root of the SD card or
USB drive. The file is hidden, and you can also edit it on a computer:

```ini
[TangCore]
; menu font: serif or sans
font=serif
; gamepad button for the menu: select+start or select+right
menu_button=select+start
```

Without the file, or with a value TangCore doesn't know, the default is used.

