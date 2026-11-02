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
cores="fpga_nestang fpga_snestang fpga_smstang fpga_gbatang fpga_monitorcore"
files="iosys/iosys_bl616.v iosys/textdisp.v iosys/uart_fixed.v"

mode=sync
case "${1:-}" in
    --check) mode=check ;;
    "") ;;
    *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

status=0
for c in $cores; do
    if [ ! -d "$root/$c/src" ]; then
        echo "missing: $c (run: git submodule update --init -- $c)" >&2
        status=1
        continue
    fi
    for f in $files; do
        src="$root/common/$f"
        dst="$root/$c/src/$f"
        if cmp -s "$src" "$dst"; then
            continue
        fi
        if [ "$mode" = check ]; then
            echo "differs: $c/src/$f"
            status=1
        else
            cp "$src" "$dst"
            echo "updated: $c/src/$f"
        fi
    done
done
exit $status
