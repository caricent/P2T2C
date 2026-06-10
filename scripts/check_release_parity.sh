#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
en="$repo_root/P2T2C_EN"
cn="$repo_root/P2T2C_CN"
errors=0

error() {
  echo "ERROR: $*" >&2
  errors=1
}

en_version="$(tr -d '[:space:]' < "$en/.p2t2c/VERSION")"
cn_version="$(tr -d '[:space:]' < "$cn/.p2t2c/VERSION")"
[[ "$en_version" == "$cn_version" ]] || error "release versions differ: EN=$en_version CN=$cn_version"

for rel in .p2t2c/bin/check_p2t2c.sh .p2t2c/bin/p2t2c_install.sh .p2t2c/bin/p2t2c_upgrade.sh; do
  cmp -s "$en/$rel" "$cn/$rel" || error "script behavior differs: $rel"
done

list_paths() {
  local root="$1"
  (
    cd "$root"
    find . -type f \
      ! -path './.p2t2c/CHECKSUMS.sha256' \
      ! -path './.p2t2c/lock.sha256' \
      ! -path './.p2t2c/generated/*' \
      | sort
  )
}

path_diff="$(diff -u <(list_paths "$en") <(list_paths "$cn") || true)"
[[ -z "$path_diff" ]] || {
  echo "$path_diff" >&2
  error "managed release paths differ"
}

stable_manifest() {
  awk '
    /^language:/ { next }
    /^supported_languages:/ { skip_language=1; next }
    skip_language && /^  - / { skip_language=0; next }
    { print }
  ' "$1"
}

manifest_diff="$(diff -u <(stable_manifest "$en/docs/sot/manifest.yaml") <(stable_manifest "$cn/docs/sot/manifest.yaml") || true)"
[[ -z "$manifest_diff" ]] || {
  echo "$manifest_diff" >&2
  error "stable docs/sot manifest contract differs"
}

if [[ "$errors" -eq 0 ]]; then
  echo "P2T2C release parity checks passed."
else
  echo "P2T2C release parity checks failed."
fi
exit "$errors"
