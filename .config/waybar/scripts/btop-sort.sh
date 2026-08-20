#!/usr/bin/env bash
set -euo pipefail

case "$1" in
    cpu) sort_mode="cpu lazy" ;;
    mem) sort_mode="memory" ;;
    *) echo "usage: $0 {cpu|mem}" >&2; exit 1 ;;
esac

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/btop"
sed "s/^proc_sorting.*/proc_sorting = \"$sort_mode\"/" "$HOME/.config/btop/btop.conf" > "$tmpdir/btop/btop.conf"

XDG_CONFIG_HOME="$tmpdir" btop
