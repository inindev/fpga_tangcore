# Shared core HDL

Files every core needs in the same version. Each core keeps its own copy in
`src/`, so it still builds without this repo; `scripts/sync_common.sh` keeps the
copies in step.

| File | What |
|---|---|
| `iosys/iosys_bl616.v` | Serial link to the BL616 firmware: menu text, ROM loading, gamepads, core options |
| `iosys/textdisp.v` | 32x28 text overlay with the core's logo |
| `iosys/uart_fixed.v` | 2 Mbaud UART used by `iosys_bl616` |
| `hdmi/*.sv` | HDMI encoder (720p, audio, InfoFrames), in each core's `src/hdmi2/` or `src/hdmi/` |
| `video/video_out.v` | Line buffer, frame lock, 3x scaler and menu window; NES and SNES only, in `src/` |
| `usb/usb_hid_host.v`, `usb/usb_hid_host_rom.hex` | FPGA USB host for gamepads on the board's own USB ports, and `usb_hid_sync`, which brings its buttons into the core's clock; in `src/`, every core but `fpga_pctang` |

Per-core differences are parameters of `iosys_bl616` (`CORE_ID`, `FREQ`, `COLOR_LOGO`)
and `video_out` (`PIX_FMT`, `DW`, `AUDIO_RATE`), set where each core instantiates them.
`gowin_dpb_menu.v` is not shared: it holds the core's logo, and `scripts/font_glyphs.py`
generates it (the font is the same in all cores). Neither are `nes_video.sv` and
`snes_video.v`, which feed each core's picture into `video_out`.

Clock crossings: a register named `*_meta` is the first stage of a synchronizer
(`iosys_bl616`'s UART input, `usb_hid_sync`, pctang's overlay and audio). Every core's
`.sdc` has `set_false_path -to [get_regs {*_meta*}]`, so the timing report shows only
crossings that are not synchronized. Gowin uses only the last `.sdc` a build adds, and
rejects a constraint that matches nothing; `iosys_bl616` is in every build, so the line
always matches.

To change a shared file:

1. Edit it here.
2. `scripts/sync_common.sh` copies it into the cores that use it: iosys and HDMI into
   `fpga_nestang`, `fpga_snestang`, `fpga_smstang`, `fpga_gbatang`, `fpga_mdtang`,
   `fpga_pctang` and `fpga_monitorcore`; `video_out.v` into `fpga_nestang` and
   `fpga_snestang`; `usb/` into all of these but `fpga_pctang`.
3. Build and test, then commit in each core that changed and here.

`scripts/sync_common.sh --check` lists cores whose copies differ.
