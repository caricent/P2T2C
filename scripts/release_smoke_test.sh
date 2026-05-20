#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/p2t2c-release-smoke.XXXXXX")"

cleanup() {
  if [[ "${KEEP_P2T2C_SMOKE:-0}" != "1" ]]; then
    rm -rf "$tmp_root"
  else
    echo "Keeping smoke test directory: $tmp_root"
  fi
}
trap cleanup EXIT

run_release_root() {
  local rel="$1"
  local release_root="$repo_root/$rel"
  local target="$tmp_root/$rel-target"

  mkdir -p "$target"

  echo "==> Checking $rel"
  make -C "$release_root" check
  (cd "$release_root" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256)

  echo "==> Installing $rel into smoke target"
  make -C "$release_root" p2t2c-install-dry-run TARGET="$target"
  make -C "$release_root" p2t2c-install TARGET="$target"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
  for internal_dir in prompts templates scripts sdd migrations; do
    if [[ -e "$target/$internal_dir" ]]; then
      echo "ERROR: installed target exposes internal directory: $internal_dir" >&2
      exit 1
    fi
  done
  for old_root_file in README.md AGENTS.md Makefile CHECKSUMS.sha256 P2T2C_TEMPLATE_VERSION P2T2C_LICENSE.md project_config.example.yaml; do
    if [[ -e "$target/$old_root_file" ]]; then
      echo "ERROR: installed target exposes old root file: $old_root_file" >&2
      exit 1
    fi
  done
  test -f "$target/P2T2C_README.md"
  test -f "$target/P2T2C_AGENTS.md"

  echo "==> Upgrading $rel smoke target from current source"
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --dry-run --source "$release_root")
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$release_root")
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
}

run_release_root "P2T2C_EN"
run_release_root "P2T2C_CN"

echo "P2T2C release smoke tests passed."
