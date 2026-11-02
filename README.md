# TangCore - FPGA Gaming Distribution for Sipeed Tang

<p align="right">
  <a title="Documentation" href="https://nand2mario.github.io/tangcore"><img src="https://img.shields.io/website.svg?label=nand2mario.github.io%2Ftangcore&longCache=true&style=flat-square&url=http%3A%2F%2Fnand2mario.github.io%2Ftangcore%2F&logo=GitHub"></a><!--
  -->
  <a title="Releases" href="https://github.com/nand2mario/tangcore/releases"><img src="https://img.shields.io/github/commits-since/nand2mario/tangcore/latest.svg?longCache=true&style=flat-square&logo=git&logoColor=fff"></a>
</p>

TangCore is a comprehensive FPGA gaming distribution that brings classic gaming systems to Sipeed Tang FPGA boards. It combines multiple high-quality gaming cores into a single package with an easy-to-use menu system.

Please [file an issue](https://github.com/nand2mario/tangcore/issues) if you run into any problems, like game compatibility and display glitches.

> [!NOTE]
> This is a fork of [nand2mario/tangcore](https://github.com/nand2mario/tangcore). The `inindev` branch adds
> **Tang Nano 20K** support (NES and SNES) and uses forks of six submodules with the fixes it needs:
> [fpga_nestang](https://github.com/inindev/fpga_nestang), [fpga_snestang](https://github.com/inindev/fpga_snestang),
> [fpga_smstang](https://github.com/inindev/fpga_smstang), [fpga_gbatang](https://github.com/inindev/fpga_gbatang),
> [fpga_monitorcore](https://github.com/inindev/fpga_monitorcore) and
> [fpga_firmware-bl616](https://github.com/inindev/fpga_firmware-bl616) (now on the official Bouffalo SDK).
> See [Tang Nano 20K](#-tang-nano-20k) below. This branch has been tested on the Tang Nano 20K and the Tang Console 138K.

## 🎮 Supported Systems

<div align="center">
  <img src="doc/tangcore-nes.png" width="300" />
  <img src="doc/tangcore-snes.png" width="300" />
  <img src="doc/tangcore-gba.png" width="300" />
  <img src="doc/tangcore-genesis.png" width="300" />
</div>

- **[NESTang](https://github.com/nand2mario/nestang/)** - Nintendo Entertainment System
  - Cycle-accurate NES emulation
  - Extensive mapper support
  - 720p HDMI output

- **[SNESTang](https://github.com/nand2mario/snestang/)** - Super Nintendo Entertainment System
  - Support for LoROM, HiROM and ExHiROM
  - DSP-1/2/3/4, S-RTC, OBC-1 extension chips

- **[GBATang](https://github.com/nand2mario/gbatang/)** - Game Boy Advance
  - High compatibility
  - Open source BIOS included
  - Full 32MB gamepak support

- **[MDTang](https://github.com/nand2mario/mdtang/)** - Sega Genesis/Mega Drive
  - Accurate Genesis/Mega Drive emulation

- **[SMSTang](https://github.com/nand2mario/smstang/)** - Sega Master System

- 🌟🌟 **Try the new [486Tang](https://github.com/nand2mario/486tang)**

## 💻 Supported Hardware

| Board Model | Status | Notes |
|------------|--------|-------|
| [Tang Console 60K](https://sipeed.com/tangconsole) | ✅ Recommended | Best overall experience |
| Tang Console 138K | ✅ Experimental | Supported since April 2025 |
| Tang Primer 25K | ✅ Experimental | NES/SNES only |
| Tang Nano 20K | ✅ Experimental (this fork) | NES/SNES only, USB gamepads and keyboard |

<img src="doc/tangcore-boards.jpg" width=450> 

## 🔌 Tang Nano 20K

The Nano 20K runs the TangCore firmware on its on-board BL616, next to Sipeed's FPGA Partner
firmware, in place of [FPGA-Companion](https://github.com/MiSTle-Dev/FPGA-Companion).

1. Build the cores and firmware: [building from sources](docs/dev-guide/building.md#tang-nano-20k-linux).
2. Write the firmware to the BL616 at 0x40000: [installation](docs/user-guide/installation.md#tang-nano-20k).
3. Put the cores on a USB drive as `cores/nano20k/monitor.bin`, `nestang.bin` and `snestang.bin`,
   with ROMs in `nes/` and `snes/`. The board's TF slot can't be used (it's wired to the FPGA);
   a USB microSD reader works.
4. Connect the drive, gamepads and keyboard through a USB hub and an OTG adapter with power
   pass-through on the USB-C port.

## 🚀 Quick Start

For detailed setup instructions, please refer to our [Installation Guide](https://nand2mario.github.io/tangcore/user-guide/installation/). Here's a quick overview:

1. Download the latest [TangCore release](https://github.com/nand2mario/tangcore/releases)
2. Flash the firmware using Bouffalo Lab Dev Cube
3. Prepare a USB drive with FPGA cores and your game ROMs
4. Connect required peripherals (HDMI and controller)
5. Power on and enjoy!

## 🛠️ Documentation

TangCore uses a different architecture compared to individual cores (NESTang/SNESTang):
- Firmware runs on BL616 MCU instead of FPGA
- Fast core switching via JTAG
- USB storage support
- SOM-connector debugging interface

For detailed development information, see an introduction to [TangCore archtecture](https://nand2mario.github.io/tangcore/dev-guide/architecture/), [building from sources](docs/dev-guide/building.md), how to [develop a new core](https://nand2mario.github.io/tangcore/dev-guide/core-development/), and [core debugging guide](https://nand2mario.github.io/tangcore/dev-guide/core-debugging/).

My blog post on TangCore,

* [MCU for Better FPGA Gaming on Tang Console](https://nand2mario.github.io/posts/2025/mcu_for_better_fpga_gaming/)

## 📝 License

TangCore firmware is licensed under Apache 2.0. Each core maintains its original license - please check individual core directories for details.

## 🙏 Acknowledgments

- MiSTer FPGA cores and their developers
- openFPGALoader by Gwenhael Goavec-Merou


## 📫 Contact

For updates and announcements, follow [@nand2mario](https://x.com/nand2mario) on X.

For support, please use the [GitHub Issues](https://github.com/nand2mario/tangcore/issues) page.  
