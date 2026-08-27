#!/usr/bin/env bash
set -euo pipefail
[[ -d .p2t2c && -d docs && ! -L .p2t2c ]] || { echo "ERROR: run from a safe project root containing .p2t2c and docs" >&2; exit 2; }
script_dir="$(cd "$(dirname "$0")" && pwd)"
core="$script_dir/check_p2t2c.pl"
[[ -f "$core" && ! -L "$core" ]] || { echo "ERROR: missing or unsafe checker core: $core" >&2; exit 2; }
exec perl "$core" "$@"
