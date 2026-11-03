#!/bin/sh
# Copy finished core builds from a build host into build/, in the SD card's layout:
#   build/cores/<board>/<core>.bin                     DS2 (or the only) variant
#   build/snescontroller/cores/<board>/<core>.bin      SNES-controller variant
#
# The BL616 firmware build writes one tangcore_bl616.bin for whichever board it was built
# for, so it isn't collected here.
#
#   scripts/collect_builds.sh [host]      host defaults to fpga@carbone
#
# Copy build/cores/ (or build/snescontroller/cores/) to the card's cores/ folder.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
host=${1:-fpga@carbone}
remote=fpga/fpga_tangcore
cores="fpga_nestang fpga_snestang fpga_smstang fpga_gbatang fpga_mdtang fpga_pctang fpga_monitorcore"
boards="nano20k primer25k mega60k mega138k console60k console138k"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for c in $cores; do
    mkdir -p "$tmp/$c"
    rsync -t "$host:$remote/$c/impl/pnr/*.bin" "$tmp/$c/" 2>/dev/null || true
done

# <core>_<board>[_<ctrl>].bin -> build tree. monitor_* is the monitor core, pcxt_*/pctang_* PC.
for f in "$tmp"/*/*.bin; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .bin)
    name=${base%%_*}
    rest=${base#*_}
    board=${rest%%_*}
    ctrl=${rest#"$board"}; ctrl=${ctrl#_}
    case " $boards " in *" $board "*) ;; *) echo "skipped: $base.bin (board $board)"; continue ;; esac
    case $ctrl in
        ""|ds2) dir=$root/build/cores/$board ;;
        snes)   dir=$root/build/snescontroller/cores/$board ;;
        *)      echo "skipped: $base.bin (variant $ctrl)"; continue ;;
    esac
    mkdir -p "$dir"
    cp -p "$f" "$dir/$name.bin"
    chmod u+w "$dir/$name.bin"
    echo "$base.bin -> ${dir#"$root"/}/$name.bin"
done
