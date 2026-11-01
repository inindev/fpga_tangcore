# Shared core HDL

Files every core needs in the same version. Each core keeps its own copy in
`src/`, so it still builds without this repo; `scripts/sync_common.sh` keeps the
copies in step.

| File | What |
|---|---|
| `iosys/iosys_bl616.v` | Serial link to the BL616 firmware: menu text, ROM loading, gamepads, core options |
| `iosys/textdisp.v` | 32x28 text overlay with the core's logo |
| `iosys/uart_fixed.v` | 2 Mbaud UART used by `iosys_bl616` |

Per-core differences are parameters of `iosys_bl616` (`CORE_ID`, `FREQ`, `COLOR_LOGO`),
set where each core instantiates it. `gowin_dpb_menu.v` is not shared: it is
generated per FPGA family and holds the core's logo.

To change a shared file:

1. Edit it here.
2. `scripts/sync_common.sh` copies it into `fpga_nestang`, `fpga_snestang` and `fpga_monitorcore`.
3. Build and test, then commit in each core that changed and here.

`scripts/sync_common.sh --check` lists cores whose copies differ.
