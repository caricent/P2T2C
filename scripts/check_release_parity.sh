#!/usr/bin/env bash
set -euo pipefail

pre_close_work_id=""
if [[ $# -gt 0 ]]; then
  if [[ $# -eq 2 && "$1" == "--pre-close-work-id" && "$2" =~ ^CPK-[A-Za-z0-9._-]+$ ]]; then
    pre_close_work_id="$2"
  else
    echo "ERROR: usage: check_release_parity.sh [--pre-close-work-id CPK-ID]" >&2
    exit 2
  fi
fi
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

changelog="$repo_root/CHANGELOG.md"
if [[ ! -f "$changelog" ]]; then
  error "missing root CHANGELOG.md"
elif ! grep -Eq "^## ${en_version}( |$)" "$changelog"; then
  error "CHANGELOG.md missing release heading for $en_version"
fi

managed_manifest=".p2t2c/managed-files.txt"
cmp -s "$en/$managed_manifest" "$cn/$managed_manifest" || error "managed-file inventories differ"

managed_paths() {
  awk '{ line=$0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); if (line != "" && line !~ /^#/) print line }' "$1"
}

managed_files_equal() {
  cmp -s "$1" "$2"
}

while IFS= read -r rel; do
  [[ -f "$en/$rel" ]] || error "EN managed asset missing: $rel"
  [[ -f "$cn/$rel" ]] || error "CN managed asset missing: $rel"
  case "$rel" in
    .p2t2c/bin/*|.p2t2c/lib/*|.p2t2c/schemas/*|.p2t2c/defaults.yaml|.p2t2c/managed-files.txt|.p2t2c/managed-modes.txt)
      managed_files_equal "$en/$rel" "$cn/$rel" || error "language-neutral behavior differs: $rel"
      ;;
  esac
done < <(managed_paths "$en/$managed_manifest")

managed_count="$(managed_paths "$en/$managed_manifest" | wc -l | tr -d ' ')"
managed_unique_count="$(managed_paths "$en/$managed_manifest" | LC_ALL=C sort -u | wc -l | tr -d ' ')"
[[ "$managed_count" == "$managed_unique_count" ]] || error "managed-file inventory contains duplicate paths"

is_project_owned_closure_instance() {
  case "$1" in
    ./docs/closure/CR-*.md|docs/closure/CR-*.md|./docs/closure/evidence/EV-*.jsonl|docs/closure/evidence/EV-*.jsonl) return 0 ;;
    *) return 1 ;;
  esac
}

list_paths() {
  local root="$1" path
  (
    cd "$root"
    find . -type f \
      ! -path './.p2t2c/CHECKSUMS.sha256' \
      ! -path './.p2t2c/lock.sha256' \
      ! -path './.p2t2c/generated/*' \
      ! -path './.p2t2c/runs/*' \
      ! -path './.p2t2c/install/*' \
      ! -path './.p2t2c/upgrade/*' \
      | sort \
      | while IFS= read -r path; do
          is_project_owned_closure_instance "$path" && continue
          printf '%s\n' "$path"
        done
  )
}

parity_self_test() {
  local fixture left right path_diff
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/p2t2c-parity-selftest.XXXXXX")"
  left="$fixture/EN"; right="$fixture/CN"
  mkdir -p "$left/docs/closure/evidence" "$right/docs/closure/evidence" "$left/.p2t2c/bin" "$right/.p2t2c/bin"
  printf '%s\n' '# managed evidence directory' > "$left/docs/closure/evidence/README.md"
  printf '%s\n' '# managed evidence directory' > "$right/docs/closure/evidence/README.md"
  printf '%s\n' '# CN-only closure instance' > "$right/docs/closure/CR-cn-only.md"
  printf '%s\n' '{"event_type":"fixture"}' > "$right/docs/closure/evidence/EV-CN-only-0000000000000000000000000000000000000000000000000000000000000000.jsonl"
  path_diff="$(diff -u <(list_paths "$left") <(list_paths "$right") || true)"
  [[ -z "$path_diff" ]] || error "closure-instance parity exclusion self-test failed"
  is_project_owned_closure_instance 'docs/closure/CR-cn-only.md' || error "CR ownership classification self-test failed"
  is_project_owned_closure_instance 'docs/closure/evidence/EV-cn-only-0000000000000000000000000000000000000000000000000000000000000000.jsonl' \
    || error "EV ownership classification self-test failed"
  if is_project_owned_closure_instance 'docs/closure/evidence/README.md'; then error "managed evidence README was misclassified"; fi

  printf '%s\n' 'same managed bytes' > "$left/.p2t2c/bin/tool"
  printf '%s\n' 'same managed bytes' > "$right/.p2t2c/bin/tool"
  managed_files_equal "$left/.p2t2c/bin/tool" "$right/.p2t2c/bin/tool" || error "managed-byte equality self-test failed"
  printf '%s\n' 'different managed bytes' > "$right/.p2t2c/bin/tool"
  if managed_files_equal "$left/.p2t2c/bin/tool" "$right/.p2t2c/bin/tool"; then
    error "managed-byte difference self-test failed"
  fi
  rm -rf "$fixture"
}

parity_self_test

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
    /^[[:space:]]+sha256:/ { next }
    /^[[:space:]]+topics:/ { next }
    { print }
  ' "$1"
}

manifest_diff="$(diff -u <(stable_manifest "$en/docs/sot/manifest.yaml") <(stable_manifest "$cn/docs/sot/manifest.yaml") || true)"
[[ -z "$manifest_diff" ]] || {
  echo "$manifest_diff" >&2
  error "stable docs/sot manifest contract differs"
}

rule_contract() {
  local root="$1"
  grep -hE '^## RULE-[A-Z]+-[0-9]+' \
    "$root/docs/sot/governance/P2T2C_GOVERNANCE.md" \
    "$root/docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md" \
    | grep -oE 'RULE-[A-Z]+-[0-9]+' | LC_ALL=C sort
}

rule_diff="$(diff -u <(rule_contract "$en") <(rule_contract "$cn") || true)"
[[ -z "$rule_diff" ]] || {
  echo "$rule_diff" >&2
  error "stable governance Rule IDs differ"
}

frontmatter_contract() {
  local root="$1" file rel cpk_instance
  while IFS= read -r file; do
    [[ "$(head -n 1 "$file" 2>/dev/null || true)" == "---" ]] || continue
    rel="${file#"$root/"}"
    is_project_owned_closure_instance "$rel" && continue
    case "$rel" in docs/change_packs/CPK-*.md) cpk_instance=1 ;; *) cpk_instance=0 ;; esac
    printf '[%s]\n' "$rel"
    awk -v cpk_instance="$cpk_instance" '
      NR == 1 && $0 == "---" { in_fm=1; next }
      in_fm && $0 == "---" { exit }
      in_fm && /^[A-Za-z0-9_]+:[[:space:]]*/ {
        key=$0; sub(/:.*/, "", key)
        if (cpk_instance && key == "status") print key ": <workflow-local>"
        else if (key ~ /(_digest|_sha)$/) print key ": <opaque>"
        else print
      }
    ' "$file" | LC_ALL=C sort
  done < <(find \
    "$root/docs/change_packs" \
    "$root/docs/closure" \
    "$root/specs" \
    "$root/.p2t2c/templates/closure" \
    "$root/.p2t2c/templates/execution" \
    -type f -name '*.md' | LC_ALL=C sort)
}

frontmatter_parity_self_test() {
  local fixture left right diff_text
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/p2t2c-frontmatter-selftest.XXXXXX")"
  left="$fixture/EN"; right="$fixture/CN"
  for root in "$left" "$right"; do
    mkdir -p "$root/docs/change_packs" "$root/docs/closure" "$root/specs" "$root/.p2t2c/templates/closure" "$root/.p2t2c/templates/execution"
  done
  cat > "$left/docs/change_packs/CPK-local-status.md" <<'EOF'
---
artifact: change_pack
schema_version: 3
id: CPK-local-status
risk: R1
status: ready
execution_shape: bounded
---
EOF
  cat > "$right/docs/change_packs/CPK-local-status.md" <<'EOF'
---
artifact: change_pack
schema_version: 3
id: CPK-local-status
risk: R1
status: applied
execution_shape: bounded
---
EOF
  diff_text="$(diff -u <(frontmatter_contract "$left") <(frontmatter_contract "$right") || true)"
  [[ -z "$diff_text" ]] || error "CPK workflow-local status normalization self-test failed"
  perl -0pi -e 's/risk: R1/risk: R2/' "$right/docs/change_packs/CPK-local-status.md"
  diff_text="$(diff -u <(frontmatter_contract "$left") <(frontmatter_contract "$right") || true)"
  [[ -n "$diff_text" ]] || error "CPK non-status frontmatter difference self-test failed"
  rm -rf "$fixture"
}

frontmatter_parity_self_test

frontmatter_diff="$(diff -u <(frontmatter_contract "$en") <(frontmatter_contract "$cn") || true)"
[[ -z "$frontmatter_diff" ]] || {
  echo "$frontmatter_diff" >&2
  error "stable artifact frontmatter keys or enum values differ"
}

adr_contract() {
  local root="$1" file rel
  while IFS= read -r file; do
    rel="${file#"$root/"}"
    printf '[%s]\n' "$rel"
    grep -E '^(Status|Date|Change Pack):' "$file" || true
  done < <(find "$root/docs/adr" -maxdepth 1 -type f -name 'ADR-*.md' | LC_ALL=C sort)
}

adr_diff="$(diff -u <(adr_contract "$en") <(adr_contract "$cn") || true)"
[[ -z "$adr_diff" ]] || {
  echo "$adr_diff" >&2
  error "stable ADR metadata differs"
}

enum_contract() {
  local root="$1" file rel
  while IFS= read -r file; do
    rel="${file#"$root/"}"
    printf '[%s]\n' "$rel"
    grep -E '"(enum|const)"[[:space:]]*:' "$file" | sed 's/^[[:space:]]*//' || true
  done < <(find "$root/.p2t2c/schemas" -maxdepth 1 -type f -name '*.json' | LC_ALL=C sort)
}

enum_diff="$(diff -u <(enum_contract "$en") <(enum_contract "$cn") || true)"
[[ -z "$enum_diff" ]] || {
  echo "$enum_diff" >&2
  error "stable schema enum/const structure differs"
}

stable_project_config() {
  awk '
    /^[[:space:]]*#/ { next }
    /^  (name|description|language):/ { next }
    /^    gate_[ab]:/ { next }
    { print }
  ' "$1"
}

project_config_diff="$(diff -u \
  <(stable_project_config "$en/.p2t2c/project_config.yaml") \
  <(stable_project_config "$cn/.p2t2c/project_config.yaml") || true)"
[[ -z "$project_config_diff" ]] || {
  echo "$project_config_diff" >&2
  error "release-root project configuration behavior differs"
}

project_overlay_diff="$(diff -u \
  <(stable_project_config "$en/.p2t2c/templates/project_config.example.yaml") \
  <(stable_project_config "$cn/.p2t2c/templates/project_config.example.yaml") || true)"
[[ -z "$project_overlay_diff" ]] || {
  echo "$project_overlay_diff" >&2
  error "new-install compact overlay behavior differs"
}

for root in "$en" "$cn"; do
  grep -q '^version: "0.14.1"$' "$root/.p2t2c/manifest.yaml" || error "$root manifest is not version 0.14.1"
  grep -q 'managed_files: ".p2t2c/managed-files.txt"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare managed-files.txt"
  grep -q 'managed_modes: ".p2t2c/managed-modes.txt"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare managed-modes.txt"
  grep -q 'methodology_profile: "p2t2c-adaptive-v2"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare adaptive-v2"
  grep -q 'rollout: "advisory_until_real_agent_eval_targets_are_met"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare advisory rollout"
  grep -q 'release_root_enforcement: "required"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare required release enforcement"
  grep -q 'path_mapping_policy: "first_match_with_mandatory_final_catchall"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare total path mapping"
  grep -q 'context_views: "context-capsule-v1,work-status-v1,evidence-summary-v1"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare bounded context views"
  grep -q 'project_config_layering: "compact_overlay_over_managed_defaults"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare compact project overlays"
  grep -q 'partial_controlled_override: "hard_failure"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not reject partial controlled overrides"
  grep -q 'phase_skills: "admit-route,execute,verify-close"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare the three phase skills"
  grep -q 'closure_receipt_schema: "closure-receipt-v2"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare receipt v2"
  grep -q 'historical_closure_receipt_schema: "closure-receipt-v1"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not retain receipt v1 compatibility"
  grep -q 'release_smoke_suites: "contract,security,transaction,migration,locale,daily,all"' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not declare split release smoke"
  grep -q 'source_checksums_required_before_apply: true' "$root/.p2t2c/manifest.yaml" || error "$root manifest does not require source checksum verification"
  grep -q 'profile: "p2t2c-adaptive-v2"' "$root/.p2t2c/templates/project_config.example.yaml" || error "$root new-install config is not adaptive-v2"
  grep -q 'enforcement: "advisory"' "$root/.p2t2c/templates/project_config.example.yaml" || error "$root new-install config is not advisory"
  grep -q 'enforcement: "required"' "$root/.p2t2c/project_config.yaml" || error "$root release project config is not required"
  grep -q 'id: "release-smoke"' "$root/.p2t2c/project_config.yaml" || error "$root full profile omits root release smoke"
  grep -q 'run: "bash ../scripts/release_smoke_test.sh --suite all --jobs 3 --pre-close-work-id {work_id}"' "$root/.p2t2c/project_config.yaml" || error "$root release smoke command differs"
  grep -q 'read_only: true' "$root/.p2t2c/project_config.yaml" || error "$root verification commands omit read_only metadata"
  grep -q 'parallel_group: "p2t2c-check"' "$root/.p2t2c/project_config.yaml" || error "$root verification commands omit their safe parallel group"
  grep -q '"governance:p2t2c-check"' "$root/.p2t2c/project_config.yaml" || error "$root full verification omits governance coverage"
  awk '
    /id: "release-smoke"/ { in_release=1; next }
    in_release && /read_only: false/ { ro=1 }
    in_release && /parallel_group: "none"/ { pg=1 }
    in_release && /covers: \[\]/ { cv=1; exit }
    END { exit !(ro && pg && cv) }
  ' "$root/.p2t2c/project_config.yaml" || error "$root release-smoke must be non-read-only, ungrouped, and uncovered"
  if managed_paths "$root/$managed_manifest" | grep -qx '.p2t2c/project_config.yaml'; then
    error "$root project-owned project_config.yaml must not be managed"
  fi
  if grep -q '^verification:' "$root/.p2t2c/templates/project_config.example.yaml"; then
    error "$root compact project overlay duplicates inherited verification"
  fi
  [[ "$(wc -c < "$root/.p2t2c/templates/project_config.example.yaml" | tr -d ' ')" -lt 1024 ]] || error "$root project overlay is not compact"
  grep -q '^verification:' "$root/.p2t2c/defaults.yaml" || error "$root managed defaults omit verification profiles"
  grep -q '^  path_mapping:' "$root/.p2t2c/defaults.yaml" || error "$root managed defaults omit verification path mapping"
  [[ -f "$root/.p2t2c/migrations/0.13.0-to-0.14.0.md" ]] || error "$root missing 0.13.0-to-0.14.0 migration"
  [[ -f "$root/.p2t2c/migrations/0.14.0-to-0.14.1.md" ]] || error "$root missing 0.14.0-to-0.14.1 migration"
  [[ -x "$root/.p2t2c/bin/p2t2c" ]] || error "$root dispatcher is missing or not executable"
  [[ -f "$root/docs/closure/evidence/README.md" ]] || error "$root evidence sidecar README is missing"
  default_mode="$(awk '$1 == "default" {print $2}' "$root/.p2t2c/managed-modes.txt")"
  while IFS= read -r rel; do
    expected_mode="$(awk -v path="$rel" -v fallback="$default_mode" '$1 ~ /^0[0-7][0-7][0-7]$/ && $2 == path {chosen=$1} END {if (length(chosen)>0) print chosen; else print fallback}' "$root/.p2t2c/managed-modes.txt")"
    actual_mode="$(perl -e '@s=stat($ARGV[0]); printf "%04o\n", $s[2]&07777' "$root/$rel")"
    [[ "$actual_mode" == "$expected_mode" ]] || error "$root managed mode differs: $rel expected=$expected_mode actual=$actual_mode"
  done < <(managed_paths "$root/$managed_manifest")
done

fixture="$repo_root/scripts/fixtures/p2t2c-0.14.0-release-roots.tar.gz"
fixture_expected="72c785a2fa0e8835732abf76eb93012c9b68a36c2344e6674550a135d6eb0256"
if [[ ! -f "$fixture" ]]; then
  error "missing byte-exact 0.14.0 release fixture"
elif [[ "$(shasum -a 256 "$fixture" | awk '{print $1}')" != "$fixture_expected" ]]; then
  error "0.14.0 release fixture digest differs"
fi
[[ -f "$repo_root/scripts/release_smoke_coverage.json" ]] || error "missing release smoke coverage manifest"

if [[ "$errors" -eq 0 ]]; then
  echo "P2T2C release parity checks passed."
else
  echo "P2T2C release parity checks failed."
fi
exit "$errors"
