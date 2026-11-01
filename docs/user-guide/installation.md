# TangCore Retro Gaming Installation Guide

## 🎮 Supported Devices

| Board Model       | FPGA Capacity | Compatible Cores             | Status        |
|-------------------|---------------|------------------------------|---------------|
| Tang Console 60K  | 60K LUT       | All cores                    | ✔️ Great     |
| Tang Console 138K | 138K LUT      | All cores                    | ✔️ Great     |
| Tang Primer 25K   | 25K LUT       | NESTang, SNESTang            | ✔️ Experimental (v0.7) |
| Tang Nano 20K     | 20K LUT       | NESTang, SNESTang            | ✔️ Experimental (inindev fork), see [below](#tang-nano-20k) |

---

## 📦 Pre-Install Checklist
- [ ] Bouffalo Flash Cube v1.1 (in `tools/bflb_tools/bouffalo_flash_cube` of [Bouffalo SDK](https://github.com/bouffalolab/bouffalo_sdk), also a [local standalone version here](https://nand2mario.github.io/tangcore/user-guide/assets/bouffalo_flash_cube-1.1.zip))
- [ ] MicroSD card or USB 2.0 drive (FAT32/exFAT, ≤32GB recommended)
- [ ] USB-C OTG adapter with **power pass-through**
- [ ] Valid GBA BIOS (`gba_bios.bin`)
- [ ] Valid PC/XT BIOS (`bios.bin`)
- [ ] Latest [TangCore Release Package](https://github.com/nand2mario/tangcore/releases)

---

## 🔧 Firmware Installation

1. Extract release package
2. Launch Flash Cube → **Browse** → Select:
   ```bash
   /firmware-bl616/flash_<board-model>.ini
   ```
   *(e.g., `flash_console60k.ini`)*

3. Boot Mode Activation:
   - Hold **BOOT** button → Connect USB → Release after connection

   ![Boot Button](boot_button.jpg)

   - Note for Tang Primer 25K: the primer does not have a BOOT button. [Short these two pins](https://nand2mario.github.io/tangcore/user-guide/primer25k.jpg) and connect USB instead.

4. Flash Process:
   - Refresh COM ports → Select Port/SN → **Download**
   - Confirm success screen:

   ![Firmware Flash Success](dev_cube.png)  
   *Green status indicates successful programming*

---

## 🕹️ Game System Setup

### SD/USB drive content
```bash
📁 /                
├── 📁 cores/        # `cores` directory from release
│    ├── 📁 console60k/
│    └── 📁 console138k/
├── 📁 nes/          # .nes rom files
├── 📁 snes/         # .smc/.sfc files
├── 📁 gba/
│    └── 🗎 gba_bios.bin  # GBA BIOS
├── 📁 genesis/      # .bin/.md files
├── 📁 sms/          # .sms files
└── 📁 pc/           # .img floppy images
│    └── 🗎 bios.bin  # PC 5160 BIOS
```

### Hardware Assembly
1. Connect components as shown (DS2 controller setup shown):
   ![](tangcore-user.jpg)

   *Left: OTG+USB | Right: DS2 PMOD+Wireless Receiver | Top: HDMI output*

2. Power sequence:
   - Insert USB drive → Connect OTG → Apply power

3. Initial Boot:
   - FPGA auto-programs (5-7 sec)
   - Main menu appears 

   ![](tangcore-menu.png)

   *Navigation using gamepad*

---

## Tang Nano 20K

The steps above are for the Tang Console. On the Nano 20K, TangCore runs on the on-board
BL616 next to Sipeed's FPGA Partner firmware, in the slot FPGA-Companion would use. There is no
release package yet; build the cores and firmware as in [building from sources](../dev-guide/building.md#tang-nano-20k-linux).

### Firmware

1. The BL616 needs Sipeed's FPGA Partner firmware (`bl616_fpga_partner_20kNano.bin`) at flash
   address 0x0. Boards that run [FPGA-Companion](https://github.com/MiSTle-Dev/FPGA-Companion) on
   the BL616 already have it; it's in FPGA-Companion's `src/bl616/bl616_fpga_partner/`.
2. Put the BL616 in update mode: unplug the board, hold **UPDATE** (next to the HDMI connector),
   plug it into the computer, release. It shows up as `Bouffalo CDC DEMO`.
3. Write `fpga_firmware-bl616/build/build_out/tangcore_bl616.bin` to address 0x40000 with
   Bouffalo's flash tool (`BLFlashCommand`, or the open-source `bflb-mcu-tool`).

With TangCore installed, the board no longer shows up as a USB debugger when plugged into a
computer, because the BL616 starts TangCore instead. To flash the FPGA with openFPGALoader again,
erase 0x40000 or write FPGA-Companion back there.

### USB drive

```bash
📁 /
├── 📁 cores/
│    └── 📁 nano20k/
│         ├── 🗎 monitor.bin    # from monitor_nano20k.bin
│         ├── 🗎 nestang.bin    # from nestang_nano20k.bin
│         └── 🗎 snestang.bin   # from snestang_nano20k.bin
├── 📁 nes/          # .nes rom files
└── 📁 snes/         # .smc/.sfc files
```

- The board's TF slot is wired to the FPGA, not the BL616, so it can't hold the cores or ROMs.
  A USB microSD reader works.
- On macOS, eject the drive before unplugging it. Otherwise Finder leaves `._` files that show up
  in the menu as games; `dot_clean -m /Volumes/<drive>` removes them.

### Hardware

- Connect the USB drive, gamepads and keyboard to the USB-C port through a hub (up to 7 ports)
  and an OTG adapter with power pass-through.
- A USB keyboard works in the menu: arrow keys move, Enter or D is A, Space or S is B.
- Status messages appear just above the TangCore logo.

---

[Report Issue](https://github.com/nand2mario/tangcore/issues)

