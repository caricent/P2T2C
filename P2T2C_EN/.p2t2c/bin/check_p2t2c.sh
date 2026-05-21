#!/usr/bin/env bash
set -euo pipefail

missing=0

required=(
  "P2T2C_AGENTS.md"
  ".p2t2c/CHECKSUMS.sha256"
  ".p2t2c/VERSION"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  ".p2t2c/lock.sha256"
  "P2T2C_README.md"
  ".p2t2c/P2T2C_LICENSE.md"
  ".p2t2c/templates/project_config.example.yaml"
  "docs/adr/README.md"
  "docs/change_proposals/CP_TEMPLATE.md"
  "docs/change_proposals/README.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/manifest.yaml"
  "specs/README.md"
  ".p2t2c/bin/check_p2t2c.sh"
  ".p2t2c/bin/p2t2c_install.sh"
  ".p2t2c/bin/p2t2c_upgrade.sh"
  ".p2t2c/migrations/README.md"
  ".p2t2c/migrations/0.1.0-to-0.2.0.md"
  ".p2t2c/migrations/0.2.0-to-0.3.0.md"
  ".p2t2c/migrations/0.3.0-to-0.4.0.md"
  ".p2t2c/migrations/0.4.0-to-0.5.0.md"
  ".p2t2c/migrations/0.5.0-to-0.6.0.md"
  ".p2t2c/migrations/0.6.0-to-0.7.0.md"
  ".p2t2c/migrations/0.7.0-to-0.8.0.md"
  ".p2t2c/prompts/01_bootstrap_repository_prompt.md"
  ".p2t2c/prompts/02_generate_change_pack_prompt.md"
  ".p2t2c/prompts/03_apply_change_pack_prompt.md"
  ".p2t2c/prompts/04_generate_execution_pack_prompt.md"
  ".p2t2c/prompts/05_execute_single_task_prompt.md"
  ".p2t2c/prompts/06_acceptance_and_closure_prompt.md"
  ".p2t2c/templates/adr/ADR_TEMPLATE.md"
  ".p2t2c/templates/change_pack/CHANGE_PACK_TEMPLATE.md"
  ".p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md"
  ".p2t2c/templates/execution/spec.md"
  ".p2t2c/templates/execution/plan.md"
  ".p2t2c/templates/execution/tasks.md"
  ".p2t2c/templates/install/INSTALL_REPORT_TEMPLATE.md"
  ".p2t2c/templates/truth/SOT_DOCUMENT_TEMPLATE.md"
  ".p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md"
  ".p2t2c/templates/upgrade/TEMPLATE_UPGRADE_PACK_TEMPLATE.md"
)

for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing required file: $f"
    missing=1
  fi
done

check_phrase() {
  local file="$1" phrase="$2"
  if [[ -f "$file" ]] && ! grep -q -- "$phrase" "$file"; then
    echo "ERROR: $file missing phrase: $phrase"
    missing=1
  fi
}

obsolete_list() {
  local migration="$1"
  [[ -f "$migration" ]] || return 0
  awk '
    /BEGIN_OBSOLETE_MANAGED/ { in_list=1; next }
    /END_OBSOLETE_MANAGED/ { in_list=0; next }
    in_list && $0 !~ /^```/ && $0 !~ /^$/ { print }
  ' "$migration"
}

managed_lock_hash() {
  local rel="$1"
  local lock_file=".p2t2c/lock.sha256"
  [[ -f "$lock_file" ]] || return 0
  awk -v path="$rel" '$2 == path {print $1}' "$lock_file" | tail -n 1
}

for migration in ".p2t2c/migrations/0.2.0-to-0.3.0.md" ".p2t2c/migrations/0.5.0-to-0.6.0.md" ".p2t2c/migrations/0.6.0-to-0.7.0.md"; do
  while IFS= read -r obsolete; do
    [[ -z "$obsolete" ]] && continue
    locked_hash="$(managed_lock_hash "$obsolete" || true)"
    if [[ -n "$locked_hash" && -e "$obsolete" ]]; then
      echo "ERROR: obsolete file still exists: $obsolete"
      missing=1
    fi
    if [[ "$obsolete" == */* ]]; then
      matches="$(rg -n --fixed-strings "$obsolete" . --glob '!.p2t2c/migrations/**' --glob '!docs/reference/**' || true)"
      matches="$(printf "%s\n" "$matches" | grep -v -- ".p2t2c/$obsolete" || true)"
      if [[ -n "$matches" ]]; then
        echo "ERROR: obsolete file is referenced outside migration notes: $obsolete"
        missing=1
      fi
    fi
  done < <(obsolete_list "$migration")
done

template_instance_files=()
while IFS= read -r generated; do
  [[ -z "$generated" ]] && continue
  template_instance_files+=("$generated")
done < <(find docs/change_proposals docs/adr -maxdepth 1 -type f \( -name 'CP-*.md' -o -name 'ADR-*.md' \) | sort)

if [[ "${#template_instance_files[@]}" -gt 0 ]]; then
  echo "ERROR: release root must be an empty template; remove CP/ADR instance files:"
  for generated in "${template_instance_files[@]}"; do
    echo "ERROR: unexpected instance file: $generated"
  done
  missing=1
fi

language="unknown"
if [[ -f "docs/sot/manifest.yaml" ]]; then
  language="$(awk -F': *' '$1 == "language" {print $2; exit}' docs/sot/manifest.yaml)"
fi

check_phrase ".p2t2c/VERSION" "0.8.0"
check_phrase "docs/sot/manifest.yaml" "language_policy: monolingual_release_root"
check_phrase ".p2t2c/manifest.yaml" "version: \"0.8.0\""
check_phrase ".p2t2c/manifest.yaml" "language_policy: \"monolingual_release_root\""
check_phrase ".p2t2c/P2T2C_LICENSE.md" "MIT License"
check_phrase ".p2t2c/P2T2C_LICENSE.md" "Copyright (c) 2026 Caricent"
check_phrase ".p2t2c/P2T2C_LICENSE.md" "jasonbaoly"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-006"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "Superseded by"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-007"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-009"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-010"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-011"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "--dry-run"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "--rollback"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "0.7.0-to-0.8.0.md"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "--target"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "0.7.0-to-0.8.0.md"
check_phrase ".p2t2c/templates/change_pack/CHANGE_PACK_TEMPLATE.md" "Truth Patch Candidate: Not generated"
check_phrase ".p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md" "Closure Decision"
check_phrase ".p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md" "Supersedes"
check_phrase ".p2t2c/templates/execution/tasks.md" "Closure Report"
check_phrase ".p2t2c/templates/project_config.example.yaml" "monolingual_release_root"
check_phrase ".p2t2c/migrations/0.4.0-to-0.5.0.md" "monolingual_release_root"
check_phrase ".p2t2c/migrations/0.6.0-to-0.7.0.md" ".p2t2c"

managed_doc_globs=(
  "P2T2C_AGENTS.md"
  "P2T2C_README.md"
  ".p2t2c/P2T2C_LICENSE.md"
  ".p2t2c/templates/project_config.example.yaml"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  "docs/adr/README.md"
  "docs/change_proposals/README.md"
  "docs/change_proposals/CP_TEMPLATE.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/manifest.yaml"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "specs/README.md"
  ".p2t2c/migrations"
  ".p2t2c/prompts"
  ".p2t2c/templates"
)

if [[ "$language" == "en-US" ]]; then
  check_phrase "P2T2C_README.md" "Human workflow"
  check_phrase "P2T2C_README.md" "English-only"
  check_phrase "P2T2C_AGENTS.md" "This is the only AI entrypoint"
  if rg -P --quiet "\\p{Han}" "${managed_doc_globs[@]}"; then
    echo "ERROR: English release root contains CJK text in managed docs"
    missing=1
  fi
elif [[ "$language" == "zh-CN" ]]; then
  check_phrase "P2T2C_README.md" "人类工作流"
  check_phrase "P2T2C_README.md" "中文单语"
  check_phrase "P2T2C_AGENTS.md" "AI 操作入口"
  if rg -P --quiet " / .*\\p{Han}" "${managed_doc_globs[@]}"; then
    echo "ERROR: Chinese release root contains same-line bilingual pairings"
    missing=1
  fi
else
  echo "ERROR: unknown docs/sot/manifest.yaml language: $language"
  missing=1
fi

# --- RULE-GOV-009: SoT rule identifier integrity ---------------------------
# Scans docs/sot/**/*.md for Rule Blocks and validates:
#   - unique RULE-IDs across all SoT
#   - bidirectional Supersedes / Superseded by links
#   - no dangling lifecycle references
#   - no superseded-yet-Active rule
sot_report="$(
  find docs/sot -type f -name '*.md' 2>/dev/null | sort | while IFS= read -r f; do
    [[ -n "$f" ]] && cat "$f" && printf '\n'
  done | awk '
    function flush() {
      if (cur != "") {
        if (cur in seen) { print "ERROR: duplicate RULE-ID: " cur }
        seen[cur] = 1
        status[cur] = cur_status
        sup[cur] = cur_sup
        supby[cur] = cur_supby
      }
      cur = ""; cur_status = ""; cur_sup = "None"; cur_supby = "None"
    }
    /^###[[:space:]]+RULE-[A-Z]+-[0-9]+/ {
      flush()
      match($0, /RULE-[A-Z]+-[0-9]+/); cur = substr($0, RSTART, RLENGTH)
      next
    }
    cur != "" && /^Status:/        { s = $0; sub(/^Status:[[:space:]]*/, "", s); cur_status = s; next }
    cur != "" && /^Supersedes:/    { s = $0; sub(/^Supersedes:[[:space:]]*/, "", s); gsub(/`/, "", s); cur_sup = s; next }
    cur != "" && /^Superseded by:/ { s = $0; sub(/^Superseded by:[[:space:]]*/, "", s); gsub(/`/, "", s); cur_supby = s; next }
    END {
      flush()
      for (r in seen) {
        # dangling + bidirectional for Superseded by
        if (supby[r] != "" && supby[r] != "None") {
          n = split(supby[r], t, /[,[:space:]]+/)
          for (i = 1; i <= n; i++) {
            id = t[i]; if (id !~ /^RULE-/) continue
            if (!(id in seen)) { print "ERROR: " r " Superseded by references missing RULE-ID: " id; continue }
            if (sup[id] !~ ("(^|[, ])" r "([, ]|$)")) print "ERROR: broken link: " r " Superseded by " id " but " id " does not Supersede " r
          }
        }
        # dangling + bidirectional for Supersedes
        if (sup[r] != "" && sup[r] != "None") {
          n = split(sup[r], t, /[,[:space:]]+/)
          for (i = 1; i <= n; i++) {
            id = t[i]; if (id !~ /^RULE-/) continue
            if (!(id in seen)) { print "ERROR: " r " Supersedes references missing RULE-ID: " id; continue }
            if (supby[id] !~ ("(^|[, ])" r "([, ]|$)")) print "ERROR: broken link: " r " Supersedes " id " but " id " is not Superseded by " r
          }
        }
        # superseded-yet-Active
        if (supby[r] != "" && supby[r] != "None" && status[r] ~ /Active/)
          print "ERROR: " r " is Superseded by " supby[r] " but still Status: Active"
      }
    }
  '
)"
if [[ -n "$sot_report" ]]; then
  printf "%s\n" "$sot_report"
  missing=1
fi

# --- RULE-GOV-010: code-to-Truth back-reference anchors (soft) -------------
# Only runs when a project src/ tree exists; the empty template root skips it.
if [[ -d "src" ]]; then
  active_ids="$(
    find docs/sot -type f -name '*.md' 2>/dev/null | sort | while IFS= read -r f; do
      [[ -n "$f" ]] && cat "$f" && printf '\n'
    done | awk '
      /^###[[:space:]]+RULE-[A-Z]+-[0-9]+/ { match($0, /RULE-[A-Z]+-[0-9]+/); cur = substr($0, RSTART, RLENGTH); next }
      cur != "" && /^Status:/ { if ($0 ~ /Active/) print cur; cur = "" }
    '
  )"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    loc="${line%:*}"
    id="$(printf "%s" "$line" | grep -o 'RULE-[A-Z]\+-[0-9]\+')"
    [[ -z "$id" ]] && continue
    if ! printf "%s\n" "$active_ids" | grep -qx -- "$id"; then
      echo "ERROR: code anchor references missing or non-Active RULE-ID: $id ($loc)"
      missing=1
    fi
  done < <(rg --no-heading -n "Implements:[[:space:]]*RULE-[A-Z]+-[0-9]+" src 2>/dev/null \
            | grep -o '^[^:]*:[0-9]*:.*RULE-[A-Z]\+-[0-9]\+' || true)
fi

if [[ $missing -eq 0 ]]; then
  echo "P2T2C checks passed."
else
  echo "P2T2C checks failed."
fi
exit $missing
