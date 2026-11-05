# Writing the menu core without Device Mode

The monitor core draws TangCore's main menu. The FPGA loads it from its own flash at power-on,
so it has to be written there with openFPGALoader, over Sipeed's USB debugger: the FPGA Partner
firmware on the BL616 (at flash address 0x0), next to TangCore (at 0x40000).

Normally TangCore hands the USB port to the debugger in Device Mode: see
[writing the menu core](installation.md#writing-the-menu-core). If the computer never sees
`SIPEED USB Debugger` that way, take TangCore out of the way instead: back up the BL616, erase
the TangCore slot, write the monitor core, and flash TangCore back. With nothing at 0x40000,
the Partner firmware comes up as the debugger by itself. Tested on a Nano 20K v3923 on
2026-11-04.

## What you need

- The board plugged straight into the computer: no OTG adapter, no hub.
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader).
- Bouffalo's flash tool. These steps use the open-source `bflb-mcu-tool` (PyPI,
  version 1.10.0). On Python 3.13 or later it needs a small patch: it imports `telnetlib`,
  which Python removed; the import is only used for OpenOCD and can be dropped.
- Three files:
  - The monitor core for your board, `monitor.bin`
    (`fpga_monitorcore/impl/pnr/monitor_<board>.bin`).
  - The TangCore firmware for your board, `tangcore_bl616.bin`
    (`fpga_firmware-bl616/build/build_out/`, built with `TANG_BOARD=<board>`).
  - A blank image to erase the TangCore slot: 741376 bytes (0xB5000) of 0xFF, which
    covers 0x40000-0xF4FFF:
    ```bash
    head -c 741376 /dev/zero | LC_ALL=C tr '\0' '\377' > blank_0x40000.bin
    ```

## Running the flash tool

The flash tool's read and write commands go through its flash loader module, which must be
run from the package folder. Give it absolute file paths.

```bash
cd <venv>/lib/python3.X/site-packages/bflb_mcu_tool
PY=<venv>/bin/python
LOADER="$PY -m libs.bflb_eflash_loader --chipname bl616 --interface uart --baudrate 2000000"
```

For writes, use a copy of `chips/bl616/eflash_loader/eflash_loader_cfg.conf` with
`verify = 1`, `decompress_write = false`, and `burn_en = false` under `[EFUSE_CFG]`. It's
called `write_cfg.conf` below. With `verify = 1`, the BL616 computes the SHA-256 of the
written range and the tool compares it with the file. The file is the same for every board.

## Update mode

Steps 1, 2 and 4 need the BL616 in update mode: unplug the board, hold its update button,
plug it into the computer, release. The button is **UPDATE** on the Nano 20K (next to the HDMI
connector) and **BOOT** on the Tang Console; the Primer 25K has none (short the two pins
shown in [installation](installation.md#firmware-installation)). It shows up as
`Bouffalo CDC DEMO`, a serial port:

```bash
PORT=$(ls /dev/cu.usbmodem* | head -1); echo $PORT    # macOS; on Linux /dev/ttyACM*
```

## 1. Back up the BL616 flash

In update mode, read the whole 4 MB flash:

```bash
$LOADER --port $PORT -c chips/bl616/eflash_loader/eflash_loader_cfg.conf \
    --read --flash --start 0x0 --end 0x3fffff --file /path/to/backup_bl616.bin
```

`--end` is inclusive: the file is exactly 4194304 bytes. To check the Partner firmware in
it, see [Checking the backup](#checking-the-backup).

## 2. Erase the TangCore slot

In update mode, write the blank image to 0x40000. The Partner firmware at 0x0 is not
touched: the tool only erases the 4 KB sectors the file covers.

```bash
$LOADER --port $PORT -c /path/to/write_cfg.conf \
    --write --flash --addr 0x40000 --file /path/to/blank_0x40000.bin
```

It should end with "verification succeeded".

## 3. Write the monitor core

Unplug the board and plug it back in normally (no button). With nothing at 0x40000, the
Partner firmware comes up as the debugger, `SIPEED USB Debugger`. Then write the monitor core
with the board's command from [writing the menu core](installation.md#writing-the-menu-core),
for example:

```bash
openFPGALoader -b tangnano20k -f monitor.bin
```

## 4. Flash TangCore back

In update mode, write the TangCore firmware to 0x40000:

```bash
$LOADER --port $PORT -c /path/to/write_cfg.conf \
    --write --flash --addr 0x40000 --file /path/to/tangcore_bl616.bin
```

It should end with "verification succeeded". Unplug, connect the SD card or USB drive, and
power up: the menu comes from the monitor core in FPGA flash.

## Checking the backup

On a Nano 20K v3923 the backup holds:

| Flash range | Contents |
|---|---|
| 0x0-0x1622F | Sipeed FPGA Partner firmware **2025030317** (90672 bytes), the newest for the Nano 20K. The rest up to 0x3FFFF is 0xFF. |
| 0x40000- | TangCore firmware, if installed; 0xFF after it. |
| 0x200000- | About 100 bytes of unidentified data, present from the factory. |

The Partner firmware is byte-identical to Sipeed's download:

| File | SHA-256 |
|---|---|
| [bl616_fpga_partner_20kNano.bin](https://api.dl.sipeed.com/TANG/Debugger/onboard/BL616/2025030317/bl616_fpga_partner_20kNano.bin) | `bc5b1f733a13562c898ff66b540038c116c3d77ca202d0afebd1e7af1c3b3203` |

Sipeed publishes the checksum next to the file
([.sha256](https://api.dl.sipeed.com/TANG/Debugger/onboard/BL616/2025030317/bl616_fpga_partner_20kNano.bin.sha256)).
To compare the first 90672 bytes of a backup with it:

```bash
head -c 90672 backup_bl616.bin | shasum -a 256
```

Other boards have their own Partner firmware; FPGA-Companion keeps a copy of each in
`src/bl616/bl616_fpga_partner/`.

## Recovery

- **TangCore doesn't start, or you want to go back:** write any earlier TangCore image to
  0x40000 as in step 4.
- **Something went wrong outside 0x40000:** the backup is the flash as stored, so writing it
  back to 0x0 unchanged, in update mode, should restore it. This has not been tested. The
  Partner firmware alone is also available from
  [Sipeed](https://wiki.sipeed.com/hardware/en/tang/common-doc/update_debugger.html).
