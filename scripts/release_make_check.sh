#!/usr/bin/env bash
set -euo pipefail

work_id="${1:-}"
mode="normal"
args=()

if [[ -n "$work_id" && "$work_id" =~ ^CPK-[A-Za-z0-9._-]+$ ]]; then
  run_dir=".p2t2c/runs/$work_id"
  if [[ -d "$run_dir" && ! -L "$run_dir" \
    && -f "$run_dir/contract.json" && ! -L "$run_dir/contract.json" \
    && -f "$run_dir/events.jsonl" && ! -L "$run_dir/events.jsonl" ]]
  then
    mode="preclose"
    args=(--pre-close-work-id "$work_id")
  fi
fi

echo "P2T2C release check mode: $mode"
exec bash .p2t2c/bin/check_p2t2c.sh ${args[@]+"${args[@]}"}
