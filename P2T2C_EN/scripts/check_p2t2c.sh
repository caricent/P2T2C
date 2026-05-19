#!/usr/bin/env bash
set -euo pipefail

missing=0

required=(
  "AGENTS.md"
  "CHECKSUMS.sha256"
  "Makefile"
  "P2T2C_TEMPLATE_VERSION"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  ".p2t2c/lock.sha256"
  "README.md"
  "P2T2C_LICENSE.md"
  "project_config.example.yaml"
  "docs/adr/README.md"
  "docs/change_proposals/CP_TEMPLATE.md"
  "docs/change_proposals/README.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/manifest.yaml"
  "migrations/p2t2c/README.md"
  "migrations/p2t2c/0.1.0-to-0.2.0.md"
  "migrations/p2t2c/0.2.0-to-0.3.0.md"
  "migrations/p2t2c/0.3.0-to-0.4.0.md"
  "migrations/p2t2c/0.4.0-to-0.5.0.md"
  "prompts/01_bootstrap_repository_prompt.md"
  "prompts/02_generate_change_pack_prompt.md"
  "prompts/03_apply_change_pack_prompt.md"
  "prompts/04_generate_execution_pack_prompt.md"
  "prompts/05_execute_single_task_prompt.md"
  "prompts/06_acceptance_and_closure_prompt.md"
  "scripts/check_p2t2c.sh"
  "scripts/p2t2c_install.sh"
  "scripts/p2t2c_upgrade.sh"
  "sdd/templates/spec.md"
  "sdd/templates/plan.md"
  "sdd/templates/tasks.md"
  "specs/README.md"
  "templates/adr/ADR_TEMPLATE.md"
  "templates/change_pack/CHANGE_PACK_TEMPLATE.md"
  "templates/closure/CLOSURE_REPORT_TEMPLATE.md"
  "templates/install/INSTALL_REPORT_TEMPLATE.md"
  "templates/truth/SOT_DOCUMENT_TEMPLATE.md"
  "templates/truth/RULE_BLOCK_TEMPLATE.md"
  "templates/upgrade/TEMPLATE_UPGRADE_PACK_TEMPLATE.md"
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
  local migration="migrations/p2t2c/0.2.0-to-0.3.0.md"
  [[ -f "$migration" ]] || return 0
  awk '
    /BEGIN_OBSOLETE_MANAGED/ { in_list=1; next }
    /END_OBSOLETE_MANAGED/ { in_list=0; next }
    in_list && $0 !~ /^```/ && $0 !~ /^$/ { print }
  ' "$migration"
}

while IFS= read -r obsolete; do
  [[ -z "$obsolete" ]] && continue
  if [[ -e "$obsolete" ]]; then
    echo "ERROR: obsolete file still exists: $obsolete"
    missing=1
  fi
  if rg --fixed-strings --quiet "$obsolete" . --glob '!migrations/**' --glob '!docs/reference/**'; then
    echo "ERROR: obsolete file is referenced outside migration notes: $obsolete"
    missing=1
  fi
done < <(obsolete_list)

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

check_phrase "P2T2C_TEMPLATE_VERSION" "0.5.0"
check_phrase "docs/sot/manifest.yaml" "language_policy: monolingual_release_root"
check_phrase ".p2t2c/manifest.yaml" "version: \"0.5.0\""
check_phrase ".p2t2c/manifest.yaml" "language_policy: \"monolingual_release_root\""
check_phrase "P2T2C_LICENSE.md" "MIT License"
check_phrase "P2T2C_LICENSE.md" "Copyright (c) 2026 Caricent"
check_phrase "P2T2C_LICENSE.md" "jasonbaoly"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-006"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "Superseded by"
check_phrase "scripts/p2t2c_upgrade.sh" "--dry-run"
check_phrase "scripts/p2t2c_upgrade.sh" "--rollback"
check_phrase "scripts/p2t2c_upgrade.sh" "0.4.0-to-0.5.0.md"
check_phrase "scripts/p2t2c_install.sh" "--target"
check_phrase "scripts/p2t2c_install.sh" "0.4.0-to-0.5.0.md"
check_phrase "Makefile" "p2t2c-install-dry-run"
check_phrase "templates/change_pack/CHANGE_PACK_TEMPLATE.md" "Truth Patch Candidate: Not generated"
check_phrase "templates/closure/CLOSURE_REPORT_TEMPLATE.md" "Closure Decision"
check_phrase "templates/truth/RULE_BLOCK_TEMPLATE.md" "Supersedes"
check_phrase "sdd/templates/tasks.md" "Closure Report"
check_phrase "project_config.example.yaml" "monolingual_release_root"
check_phrase "migrations/p2t2c/0.4.0-to-0.5.0.md" "monolingual_release_root"

managed_doc_globs=(
  "AGENTS.md"
  "README.md"
  "P2T2C_LICENSE.md"
  "project_config.example.yaml"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  "docs/adr/README.md"
  "docs/change_proposals/README.md"
  "docs/change_proposals/CP_TEMPLATE.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/manifest.yaml"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "migrations/p2t2c"
  "prompts"
  "sdd/templates"
  "specs/README.md"
  "templates"
)

if [[ "$language" == "en-US" ]]; then
  check_phrase "README.md" "Human workflow"
  check_phrase "README.md" "English-only"
  check_phrase "AGENTS.md" "This is the only AI entrypoint"
  if rg -P --quiet "\\p{Han}" "${managed_doc_globs[@]}"; then
    echo "ERROR: English release root contains CJK text in managed docs"
    missing=1
  fi
elif [[ "$language" == "zh-CN" ]]; then
  check_phrase "README.md" "人类工作流"
  check_phrase "README.md" "中文单语"
  check_phrase "AGENTS.md" "AI 操作入口"
  if rg -P --quiet " / .*\\p{Han}" "${managed_doc_globs[@]}"; then
    echo "ERROR: Chinese release root contains same-line bilingual pairings"
    missing=1
  fi
else
  echo "ERROR: unknown docs/sot/manifest.yaml language: $language"
  missing=1
fi

if [[ $missing -eq 0 ]]; then
  echo "P2T2C checks passed."
else
  echo "P2T2C checks failed."
fi
exit $missing
