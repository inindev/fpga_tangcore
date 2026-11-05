#!/bin/sh
# Copy the shared HDL in common/ into each core submodule, so every core keeps
# its own copy and still builds on its own.
#
#   scripts/sync_common.sh           copy common/ into the cores
#   scripts/sync_common.sh --check   list copies that differ from common/ (exit 1 if any)
#
# Change shared files in common/, run this, then commit in each core that changed.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
all="fpga_nestang fpga_snestang fpga_smstang fpga_gbatang fpga_monitorcore fpga_mdtang fpga_pctang"

# One line per group: <files in common/> | <folder in the core's src/> | <cores>
# A folder of "hdmi" means the core's own HDMI folder: src/hdmi2 or src/hdmi.
groups="
iosys/iosys_bl616.v iosys/textdisp.v iosys/uart_fixed.v | iosys | $all
video/video_out.v | . | fpga_nestang fpga_snestang
usb/usb_hid_host.v usb/usb_hid_host_rom.hex | . | fpga_nestang fpga_snestang fpga_smstang fpga_gbatang fpga_mdtang fpga_monitorcore
$(cd "$root/common" && ls hdmi/*.sv | tr '\n' ' ') | hdmi | $all
"

mode=sync
case "${1:-}" in
    --check) mode=check ;;
    "") ;;
    *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

rc=0
while IFS='|' read -r files dir cores; do
    [ -n "$files" ] || continue
    dir=$(echo $dir)
    for c in $cores; do
        if [ ! -d "$root/$c/src" ]; then
            echo "missing: $c (run: git submodule update --init -- $c)" >&2
            rc=1
            continue
        fi
        d=$dir
        if [ "$d" = hdmi ]; then
            if [ -d "$root/$c/src/hdmi2" ]; then d=hdmi2; else d=hdmi; fi
        fi
        for f in $files; do
            src="$root/common/$f"
            if [ "$d" = . ]; then rel=$c/src/$(basename "$f"); else rel=$c/src/$d/$(basename "$f"); fi
            dst="$root/$rel"
            if cmp -s "$src" "$dst"; then
                continue
            fi
            if [ "$mode" = check ]; then
                echo "differs: $rel"
                rc=1
            else
                cp "$src" "$dst"
                echo "updated: $rel"
            fi
        done
    done
done <<EOF
$groups
EOF
exit $rc
