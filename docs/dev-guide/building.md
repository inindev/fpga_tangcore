# Building TangCore

How to build the firmware, the monitor (menu) core and the game cores.

## Getting the source

```sh
git clone -b inindev --recurse-submodules https://github.com/inindev/fpga_tangcore.git
cd fpga_tangcore
```

The `fpga_*` submodules are inindev forks that follow their `inindev` branch. To move them to
the newest commits: `git submodule update --remote`.

| Folder | What |
|---|---|
| `fpga_firmware-bl616` | BL616 firmware (menu, core loading, USB) |
| `fpga_monitorcore` | Monitor core: the menu screen, loaded by the FPGA from its own flash |
| `fpga_nestang`, `fpga_snestang` | NES and SNES cores |
| `fpga_smstang` | Master System core (Tang Console only; fork for a Linux build fix) |
| `fpga_gbatang` | Game Boy Advance core (Tang Console only; fork with the 138K overlay fix) |
| `fpga_mdtang`, `fpga_pctang` | Genesis and PC/XT cores (Tang Console only) |

## Tang Nano 20K (Linux)

Tested with Gowin IDE 1.9.11.03 Education and the official Bouffalo SDK on Debian 13.

### Cores

Each core folder has a `build.tcl`; run it with Gowin's `gw_sh` from that folder. On a machine
without a display, set `QT_QPA_PLATFORM=offscreen`.

```sh
for c in fpga_nestang fpga_snestang fpga_monitorcore; do
    (cd $c && $GOWIN_HOME/bin/gw_sh build.tcl nano20k)
done
```

About 3 minutes per core. Outputs: `<core>/impl/pnr/<name>_nano20k.{fs,bin}`, e.g.
`fpga_nestang/impl/pnr/nestang_nano20k.bin`. Timing is in `impl/pnr/<name>_nano20k_tr_content.html`;
the HDMI clock must reach 74.25 MHz.

### Firmware

You need T-Head GCC v2.6.1 (`xuantie-gcc-riscv-v2.6.1-linux-x86_64`, from
[bouffalolab/toolchain](https://github.com/bouffalolab/toolchain)) and the official
[Bouffalo SDK](https://github.com/bouffalolab/bouffalo_sdk), tested at commit `237ed9378`.

```sh
git clone https://github.com/bouffalolab/bouffalo_sdk.git
git -C bouffalo_sdk checkout 237ed9378
export BL_SDK_BASE=$PWD/bouffalo_sdk
export PATH=/path/to/xuantie-gcc-riscv-v2.6.1-linux-x86_64/bin:$BL_SDK_BASE/tools/cmake/bin:$PATH

cd fpga_firmware-bl616
make TANG_BOARD=nano20k
```

Output: `fpga_firmware-bl616/build/build_out/tangcore_bl616.bin`.

### USB drive

Copy the cores to the drive under the names the firmware looks for:

| Build output | On the USB drive |
|---|---|
| `fpga_nestang/impl/pnr/nestang_nano20k.bin` | `cores/nano20k/nestang.bin` |
| `fpga_snestang/impl/pnr/snestang_nano20k.bin` | `cores/nano20k/snestang.bin` |

`monitor_nano20k.bin` goes to the FPGA's flash instead (see the
[installation guide](../user-guide/installation.md#tang-nano-20k)); on the drive as
`cores/nano20k/monitor.bin` it is only loaded from the Cores menu.

Installing the firmware is described in the [installation guide](../user-guide/installation.md#tang-nano-20k).

## Tang Console and other boards (Windows)

Upstream's build, with this fork's folder names. It hasn't been tested on this branch.

* Windows 10 or 11
* Gowin IDE 1.9.10.3 and 1.9.11. Both are needed for the building process.
* [git for windows](https://git-scm.com/downloads/win)
* The BL616 firmware now needs the official Bouffalo SDK (see above), not vossstef's or
  nand2mario's patched SDK. Add the T-Head toolchain's `bin` and the SDK's `tools\make`,
  `tools\cmake\bin` and `tools\ninja` to the path.

### Build the firmware

Obtain Sipeed's **official firmware** [here](https://dl.sipeed.com/shareURL/TANG/Console/09_MCU_FW) and save it in `fpga_firmware-bl616`.

```batch
cd fpga_firmware-bl616

buildall         # build for all boards

set TANG_BOARD=primer25k
make             # build for one board
```

### Build the cores

```batch
cd fpga_nestang
buildall         # build for all boards

# the same for fpga_snestang, fpga_gbatang, fpga_mdtang, fpga_pctang and fpga_monitorcore
```

### Collect building results

```batch
build package
```

This collects all built artifacts in `build/`.
