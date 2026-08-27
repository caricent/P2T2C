#!/usr/bin/env bash
set -euo pipefail
[[ -d .p2t2c && -d docs && ! -L .p2t2c ]] || { echo "ERROR: run from a safe project root" >&2; exit 2; }
script_dir="$(cd "$(dirname "$0")" && pwd)"
core="$script_dir/p2t2c_close.pl"
[[ -f "$core" && ! -L "$core" ]] || { echo "ERROR: missing or unsafe close core" >&2; exit 2; }
exec perl "$core" "$@"
