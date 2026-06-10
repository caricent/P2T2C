#!/usr/bin/env bash
set -euo pipefail

errors=0

error() {
  echo "ERROR: $*" >&2
  errors=1
}

required=(
  "P2T2C_AGENTS.md"
  "P2T2C_README.md"
  ".p2t2c/CHECKSUMS.sha256"
  ".p2t2c/VERSION"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  ".p2t2c/lock.sha256"
  ".p2t2c/P2T2C_LICENSE.md"
  ".p2t2c/templates/project_config.example.yaml"
  "docs/adr/README.md"
  "docs/submit_proposals/SP_TEMPLATE.md"
  "docs/submit_proposals/README.md"
  "docs/change_packs/CPK_TEMPLATE.md"
  "docs/change_packs/README.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md"
  "docs/sot/manifest.yaml"
  "specs/README.md"
  ".p2t2c/bin/check_p2t2c.sh"
  ".p2t2c/bin/p2t2c_install.sh"
  ".p2t2c/bin/p2t2c_upgrade.sh"
  ".p2t2c/migrations/README.md"
  ".p2t2c/migrations/0.11.0-to-0.12.0.md"
  ".p2t2c/prompts/01_intent_admission_prompt.md"
  ".p2t2c/prompts/02_risk_routing_and_truth_prompt.md"
  ".p2t2c/prompts/03_execute_work_batch_prompt.md"
  ".p2t2c/prompts/04_verify_and_repair_prompt.md"
  ".p2t2c/prompts/05_drift_and_closure_prompt.md"
  ".p2t2c/templates/adr/ADR_TEMPLATE.md"
  ".p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md"
  ".p2t2c/templates/execution/spec.md"
  ".p2t2c/templates/execution/plan.md"
  ".p2t2c/templates/execution/tasks.md"
  ".p2t2c/templates/install/INSTALL_REPORT_TEMPLATE.md"
  ".p2t2c/templates/truth/SOT_DOCUMENT_TEMPLATE.md"
  ".p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md"
  ".p2t2c/templates/upgrade/TEMPLATE_UPGRADE_PACK_TEMPLATE.md"
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || error "missing required file: $file"
done

check_phrase() {
  local file="$1" phrase="$2"
  [[ -f "$file" ]] || return
  grep -q -- "$phrase" "$file" || error "$file missing phrase: $phrase"
}

check_phrase ".p2t2c/VERSION" "0.12.0"
check_phrase ".p2t2c/manifest.yaml" 'version: "0.12.0"'
check_phrase ".p2t2c/manifest.yaml" 'risk_levels: "R0,R1,R2"'
check_phrase "docs/sot/manifest.yaml" "change_pack_root: docs/change_packs"
check_phrase "docs/sot/manifest.yaml" "intent_admission"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-009"
check_phrase "docs/change_packs/CPK_TEMPLATE.md" "artifact: change_pack"
check_phrase ".p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md" "artifact: closure_report"

obsolete_list() {
  local migration="$1"
  awk '
    /BEGIN_OBSOLETE_MANAGED/ { in_list=1; next }
    /END_OBSOLETE_MANAGED/ { in_list=0; next }
    in_list && $0 !~ /^```/ && $0 !~ /^$/ { print }
  ' "$migration"
}

managed_lock_hash() {
  local rel="$1"
  awk -v path="$rel" '$2 == path {print $1}' .p2t2c/lock.sha256 2>/dev/null | tail -n 1
}

for migration in .p2t2c/migrations/*.md; do
  [[ -f "$migration" ]] || continue
  while IFS= read -r obsolete; do
    [[ -n "$obsolete" ]] || continue
    if [[ -n "$(managed_lock_hash "$obsolete")" && -e "$obsolete" ]]; then
      error "obsolete locked managed file still exists: $obsolete"
    fi
  done < <(obsolete_list "$migration")
done

language="$(awk -F': *' '$1 == "language" {print $2; exit}' docs/sot/manifest.yaml 2>/dev/null || true)"
case "$language" in
  en-US)
    check_phrase "P2T2C_README.md" "Risk-Routed Workflow"
    check_phrase "P2T2C_AGENTS.md" "AI Entry Point"
    if perl -MFile::Find -CSD -e '
      my $found=0; find({wanted=>sub{return if $found || !-f $_; open my $f,"<:encoding(UTF-8)",$_ or return; while(<$f>){if(/\p{Han}/){$found=1;last}}},no_chdir=>1}, @ARGV); exit($found?0:1)
    ' P2T2C_AGENTS.md P2T2C_README.md docs .p2t2c/prompts .p2t2c/templates 2>/dev/null; then
      error "English release root contains CJK text in managed docs"
    fi
    ;;
  zh-CN)
    check_phrase "P2T2C_README.md" "风险路由工作流"
    check_phrase "P2T2C_AGENTS.md" "AI 操作入口"
    ;;
  *)
    error "unknown docs/sot/manifest.yaml language: $language"
    ;;
esac

frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_fm=1; next }
    in_fm && $0 == "---" { exit }
    in_fm && index($0, key ":") == 1 {
      value=$0; sub("^[^:]+:[[:space:]]*", "", value); gsub(/^"|"$/, "", value); print value; exit
    }
  ' "$file"
}

has_frontmatter() {
  [[ "$(head -n 1 "$1" 2>/dev/null || true)" == "---" ]]
}

validate_cpk() {
  local file="$1" base id artifact risk source truth_change gate_a status
  base="$(basename "$file" .md)"
  artifact="$(frontmatter_value "$file" artifact)"
  id="$(frontmatter_value "$file" id)"
  risk="$(frontmatter_value "$file" risk)"
  source="$(frontmatter_value "$file" source)"
  truth_change="$(frontmatter_value "$file" truth_change)"
  gate_a="$(frontmatter_value "$file" gate_a)"
  status="$(frontmatter_value "$file" status)"

  [[ "$artifact" == "change_pack" ]] || error "$file artifact must be change_pack"
  [[ "$id" == "$base" ]] || error "$file id must match filename: $base"
  [[ "$source" =~ ^(user_instruction|issue_path|sp_path)$ ]] || error "$file source must be user_instruction, issue_path, or sp_path"
  [[ "$status" =~ ^(ready|blocked|applied)$ ]] || error "$file has invalid status: $status"

  case "$risk" in
    R1)
      [[ "$truth_change" == "false" ]] || error "$file R1 must use truth_change: false"
      [[ "$gate_a" == "not_required" ]] || error "$file R1 must use gate_a: not_required"
      ;;
    R2)
      [[ "$truth_change" == "true" ]] || error "$file R2 must use truth_change: true"
      [[ "$gate_a" =~ ^(satisfied|pending)$ ]] || error "$file R2 gate_a must be satisfied or pending"
      if [[ "$gate_a" == "pending" && "$status" == "applied" ]]; then
        error "$file cannot be applied while gate_a is pending"
      fi
      ;;
    *)
      error "$file risk must be R1 or R2"
      ;;
  esac
}

while IFS= read -r file; do
  has_frontmatter "$file" && validate_cpk "$file"
done < <(find docs/change_packs -maxdepth 1 -type f -name 'CPK-*.md' 2>/dev/null | sort)

validate_spec() {
  local file="$1" artifact cpk gate_a
  artifact="$(frontmatter_value "$file" artifact)"
  [[ "$artifact" == "execution_spec" ]] || return
  cpk="$(frontmatter_value "$file" change_pack)"
  [[ "$cpk" == docs/change_packs/CPK-*.md ]] || error "$file must reference a docs/change_packs/CPK-*.md path"
  [[ -f "$cpk" ]] || { error "$file references missing CPK: $cpk"; return; }
  gate_a="$(frontmatter_value "$cpk" gate_a)"
  [[ "$gate_a" != "pending" ]] || error "$file cannot execute while referenced CPK gate_a is pending"
  [[ -f "$(dirname "$file")/plan.md" ]] || error "$file is missing sibling plan.md"
  [[ -f "$(dirname "$file")/tasks.md" ]] || error "$file is missing sibling tasks.md"
}

while IFS= read -r file; do
  has_frontmatter "$file" && validate_spec "$file"
done < <(find specs -mindepth 2 -maxdepth 2 -type f -name spec.md 2>/dev/null | sort)

path_exists() {
  [[ -f "$1" || -d "$1" ]]
}

validate_cr() {
  local file="$1" base artifact id risk cpk execution drift decision
  base="$(basename "$file" .md)"
  artifact="$(frontmatter_value "$file" artifact)"
  id="$(frontmatter_value "$file" id)"
  risk="$(frontmatter_value "$file" risk)"
  cpk="$(frontmatter_value "$file" change_pack)"
  execution="$(frontmatter_value "$file" execution_pack)"
  drift="$(frontmatter_value "$file" truth_drift)"
  decision="$(frontmatter_value "$file" decision)"

  [[ "$artifact" == "closure_report" ]] || error "$file artifact must be closure_report"
  [[ "$id" == "$base" ]] || error "$file id must match filename: $base"
  [[ "$risk" =~ ^R[012]$ ]] || error "$file risk must be R0, R1, or R2"
  [[ "$drift" =~ ^(none|resolved)$ ]] || error "$file truth_drift must be none or resolved"
  [[ "$decision" == "CLOSE" ]] || error "$file decision must be CLOSE"

  if [[ "$risk" == "R0" ]]; then
    [[ "$cpk" == "none" ]] || error "$file R0 change_pack must be none"
    [[ "$execution" == "none" ]] || error "$file R0 execution_pack must be none"
  else
    [[ "$cpk" == docs/change_packs/CPK-*.md && -f "$cpk" ]] || error "$file $risk must reference an existing CPK"
    [[ "$execution" != "none" ]] || error "$file $risk must reference an execution_pack"
    path_exists "$execution" || error "$file references missing execution_pack: $execution"
  fi

  grep -Eq '^## (Verification Evidence|验证证据)$' "$file" || error "$file missing verification evidence section"
  grep -Eq '^## (Remaining Risks|剩余风险)$' "$file" || error "$file missing remaining risks section"
  grep -Eq '^\| `[^`]+` \| (Pass|Fail|Not run)' "$file" || error "$file must record at least one actual verification command and result"
}

while IFS= read -r file; do
  has_frontmatter "$file" && validate_cr "$file"
done < <(find docs/closure -maxdepth 1 -type f -name 'CR-*.md' 2>/dev/null | sort)

duplicate_rules="$(
  find docs/sot -type f -name '*.md' ! -name '*_HISTORY.md' 2>/dev/null \
    | sort \
    | xargs grep -hE '^###[[:space:]]+RULE-[A-Z]+-[0-9]+|^##[[:space:]]+RULE-[A-Z]+-[0-9]+' 2>/dev/null \
    | grep -oE 'RULE-[A-Z]+-[0-9]+' \
    | sort | uniq -d || true
)"
[[ -z "$duplicate_rules" ]] || error "duplicate current Rule IDs: $(printf '%s' "$duplicate_rules" | paste -sd, -)"

if [[ "$errors" -eq 0 ]]; then
  echo "P2T2C checks passed."
else
  echo "P2T2C checks failed."
fi
exit "$errors"
