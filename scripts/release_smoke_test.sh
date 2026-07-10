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

create_contract_samples() {
  local target="$1"

  mkdir -p "$target/docs/closure"
  cat > "$target/docs/closure/CR-20260610-r0-smoke.md" <<'EOF'
---
artifact: closure_report
id: CR-20260610-r0-smoke
risk: R0
change_pack: none
execution_pack: none
truth_drift: none
decision: CLOSE
---
# R0 smoke
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `make check` | Pass | R0 contract |
## Remaining Risks
- None
EOF

  mkdir -p "$target/specs/001-r1-smoke"
  cat > "$target/docs/change_packs/CPK-20260610-r1-smoke.md" <<'EOF'
---
artifact: change_pack
id: CPK-20260610-r1-smoke
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: applied
---
# R1 smoke
EOF
  cat > "$target/specs/001-r1-smoke/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260610-r1-smoke.md
---
# R1 smoke spec
EOF
  printf '# R1 smoke plan\n' > "$target/specs/001-r1-smoke/plan.md"
  printf '# R1 smoke tasks\n' > "$target/specs/001-r1-smoke/tasks.md"
  cat > "$target/docs/closure/CR-20260610-r1-smoke.md" <<'EOF'
---
artifact: closure_report
id: CR-20260610-r1-smoke
risk: R1
change_pack: docs/change_packs/CPK-20260610-r1-smoke.md
execution_pack: specs/001-r1-smoke
truth_drift: none
decision: CLOSE
---
# R1 smoke
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `make check` | Pass | R1 contract |
## Remaining Risks
- None
EOF

  mkdir -p "$target/specs/002-r2-smoke"
  cat > "$target/docs/change_packs/CPK-20260610-r2-smoke.md" <<'EOF'
---
artifact: change_pack
id: CPK-20260610-r2-smoke
risk: R2
source: user_instruction
truth_change: true
gate_a: pending
status: blocked
---
# R2 smoke
EOF
  cat > "$target/specs/002-r2-smoke/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260610-r2-smoke.md
---
# R2 smoke spec
EOF
  printf '# R2 smoke plan\n' > "$target/specs/002-r2-smoke/plan.md"
  printf '# R2 smoke tasks\n' > "$target/specs/002-r2-smoke/tasks.md"
}

complete_r2_sample() {
  local target="$1"
  perl -0pi -e 's/gate_a: pending/gate_a: satisfied/; s/status: blocked/status: applied/' "$target/docs/change_packs/CPK-20260610-r2-smoke.md"
  cat > "$target/docs/closure/CR-20260610-r2-smoke.md" <<'EOF'
---
artifact: closure_report
id: CR-20260610-r2-smoke
risk: R2
change_pack: docs/change_packs/CPK-20260610-r2-smoke.md
execution_pack: specs/002-r2-smoke
truth_drift: resolved
decision: CLOSE
---
# R2 smoke
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `make check` | Pass | R2 contract |
## Remaining Risks
- None
EOF
}

add_required_method_sample() {
  local target="$1"

  cp "$target/.p2t2c/templates/project_config.example.yaml" "$target/.p2t2c/project_config.yaml"
  mkdir -p "$target/specs/004-method-r2-smoke"
  cat > "$target/docs/change_packs/CPK-20260710-method-r2-smoke.md" <<'EOF'
---
artifact: change_pack
id: CPK-20260710-method-r2-smoke
risk: R2
source: user_instruction
truth_change: true
gate_a: satisfied
status: applied
methodology_profile: p2t2c-balanced-v1
---
# Method-enabled R2 smoke

## Method Checkpoints

- Test-first behavior or exemption: Exemption: workflow fixture validates configuration behavior.
- Isolation and baseline: Clean fixture baseline.
- Independent review required: Yes
EOF
  cat > "$target/specs/004-method-r2-smoke/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260710-method-r2-smoke.md
---
# Method-enabled R2 smoke spec
EOF
  printf '# plan\n' > "$target/specs/004-method-r2-smoke/plan.md"
  printf '# tasks\n' > "$target/specs/004-method-r2-smoke/tasks.md"
  cat > "$target/docs/closure/CR-20260710-method-r2-smoke.md" <<'EOF'
---
artifact: closure_report
id: CR-20260710-method-r2-smoke
risk: R2
change_pack: docs/change_packs/CPK-20260710-method-r2-smoke.md
execution_pack: specs/004-method-r2-smoke
truth_drift: none
decision: CLOSE
---
# Method-enabled R2 smoke
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `bash .p2t2c/bin/check_p2t2c.sh` | Pass | Required fixture |
## Remaining Risks
- None
EOF
}

complete_required_method_sample() {
  local target="$1"

  cat >> "$target/docs/closure/CR-20260710-method-r2-smoke.md" <<'EOF'

## Method Evidence

- Test-first: Exemption: this workflow fixture has no production behavior; Alternative evidence: `bash .p2t2c/bin/check_p2t2c.sh` Pass.
- Root-cause repair record: Not applicable; no repair occurred.
- Independent review: Pass; Critical: 0; Important: 0; Minor: 0 resolved.
- Isolation and baseline: Host-managed fixture workspace; baseline governance check passed.
EOF
}

add_required_method_r1_sample() {
  local target="$1"

  mkdir -p "$target/specs/005-method-r1-smoke"
  cat > "$target/docs/change_packs/CPK-20260710-method-r1-smoke.md" <<'EOF'
---
artifact: change_pack
id: CPK-20260710-method-r1-smoke
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: applied
methodology_profile: p2t2c-balanced-v1
production_code_change: true
---
# Method-enabled R1 production-code smoke
EOF
  cat > "$target/specs/005-method-r1-smoke/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260710-method-r1-smoke.md
---
# Method-enabled R1 smoke spec
EOF
  printf '# plan\n' > "$target/specs/005-method-r1-smoke/plan.md"
  printf '# tasks\n' > "$target/specs/005-method-r1-smoke/tasks.md"
  cat > "$target/docs/closure/CR-20260710-method-r1-smoke.md" <<'EOF'
---
artifact: closure_report
id: CR-20260710-method-r1-smoke
risk: R1
change_pack: docs/change_packs/CPK-20260710-method-r1-smoke.md
execution_pack: specs/005-method-r1-smoke
truth_drift: none
decision: CLOSE
---
# Method-enabled R1 smoke
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `bash .p2t2c/bin/check_p2t2c.sh` | Pass | Required fixture |
## Method Evidence

- Test-first: Exemption: this workflow fixture has no production behavior; Alternative evidence: `bash .p2t2c/bin/check_p2t2c.sh` Pass.
- Root-cause repair record: Not applicable; no repair occurred.
- Isolation and baseline: Host-managed fixture workspace; baseline governance check passed.
## Remaining Risks
- None
EOF
}

complete_required_method_r1_sample() {
  local target="$1"

  cat >> "$target/docs/closure/CR-20260710-method-r1-smoke.md" <<'EOF'
- Independent review: Pass; Critical: 0; Important: 0; Minor: 0 resolved.
EOF
}

add_locked_obsolete_011_assets() {
  local target="$1"
  local rel hash
  printf '0.11.0\n' > "$target/.p2t2c/VERSION"
  hash="$(shasum -a 256 "$target/.p2t2c/VERSION" | awk '{print $1}')"
  printf '%s  %s\n' "$hash" ".p2t2c/VERSION" >> "$target/.p2t2c/lock.sha256"
  for rel in \
    .p2t2c/prompts/05_execute_single_task_prompt.md \
    .p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md
  do
    mkdir -p "$target/$(dirname "$rel")"
    printf '0.11.0 obsolete smoke asset\n' > "$target/$rel"
    hash="$(shasum -a 256 "$target/$rel" | awk '{print $1}')"
    printf '%s  %s\n' "$hash" "$rel" >> "$target/.p2t2c/lock.sha256"
  done
  mkdir -p "$target/.p2t2c/generated"
  printf '# Auto-generated by check_p2t2c.sh (RULE-GOV-012). Do not edit by hand.\n' > "$target/.p2t2c/generated/phase_rules.txt"
}

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
  test -f "$target/docs/change_packs/CPK_TEMPLATE.md"
  test -f "$target/.p2t2c/project_config.yaml"
  test -f "$target/.p2t2c/skills/risk-aware-tdd/SKILL.md"
  test -f "$target/docs/reference/SUPERPOWERS_ATTRIBUTION.md"

  echo "==> Checking $rel workflow contracts"
  create_contract_samples "$target"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: R2 gate_a pending did not block execution docs" >&2
    exit 1
  fi
  complete_r2_sample "$target"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)

  echo "==> Checking $rel required method evidence"
  add_required_method_sample "$target"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: required method-enabled R2 closure passed without method evidence" >&2
    exit 1
  fi
  complete_required_method_sample "$target"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)

  perl -0pi -e 's/\| `bash \.p2t2c\/bin\/check_p2t2c\.sh` \| Pass \| Required fixture \|/| `bash .p2t2c\/bin\/check_p2t2c.sh` | Fail | Required fixture |/' "$target/docs/closure/CR-20260710-method-r2-smoke.md"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: required method-enabled R2 closure accepted a failed verification command" >&2
    exit 1
  fi
  perl -0pi -e 's/\| `bash \.p2t2c\/bin\/check_p2t2c\.sh` \| Fail \| Required fixture \|/| `bash .p2t2c\/bin\/check_p2t2c.sh` | Pass | Required fixture |/' "$target/docs/closure/CR-20260710-method-r2-smoke.md"

  perl -0pi -e 's/Independent review: Pass; Critical: 0; Important: 0;/Independent review: Pass; Critical: 0; Important: 1;/' "$target/docs/closure/CR-20260710-method-r2-smoke.md"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: required method-enabled R2 closure accepted an Important review finding" >&2
    exit 1
  fi
  perl -0pi -e 's/Independent review: Pass; Critical: 0; Important: 1;/Independent review: Pass; Critical: 0; Important: 0;/' "$target/docs/closure/CR-20260710-method-r2-smoke.md"

  perl -0pi -e 's/Test-first: Exemption: [^\n]+/Test-first: unstructured evidence/' "$target/docs/closure/CR-20260710-method-r2-smoke.md"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: required method-enabled R2 closure accepted unstructured test-first evidence" >&2
    exit 1
  fi
  perl -0pi -e 's/Test-first: unstructured evidence/Test-first: Exemption: this workflow fixture has no production behavior; Alternative evidence: `bash .p2t2c\/bin\/check_p2t2c.sh` Pass./' "$target/docs/closure/CR-20260710-method-r2-smoke.md"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)

  add_required_method_r1_sample "$target"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: required method-enabled R1 production code passed without independent review" >&2
    exit 1
  fi
  complete_required_method_r1_sample "$target"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)

  cat > "$target/docs/closure/CR-20260610-invalid.md" <<'EOF'
---
artifact: closure_report
id: CR-20260610-invalid
risk: R0
change_pack: none
execution_pack: none
truth_drift: none
decision: CLOSE
---
# Invalid CR without evidence
EOF
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: CR without verification evidence passed contract checks" >&2
    exit 1
  fi
  rm "$target/docs/closure/CR-20260610-invalid.md"

  cat > "$target/docs/closure/CR-20260610-fresh-pass-invalid.md" <<'EOF'
---
artifact: closure_report
schema_version: 2
id: CR-20260610-fresh-pass-invalid
risk: R0
change_pack: none
execution_pack: none
truth_drift: none
decision: CLOSE
verification_policy: fresh_pass
---
# Invalid fresh-pass CR
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `make check` | Not run | Deliberately negative fixture |
## Remaining Risks
- None
EOF
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: fresh-pass CR without a passing verification command passed contract checks" >&2
    exit 1
  fi
  rm "$target/docs/closure/CR-20260610-fresh-pass-invalid.md"

  cat > "$target/docs/closure/CR-20260610-schema-v2-invalid.md" <<'EOF'
---
artifact: closure_report
schema_version: 2
id: CR-20260610-schema-v2-invalid
risk: R0
change_pack: none
execution_pack: none
truth_drift: none
decision: CLOSE
---
# Invalid v2 CR
## Verification Evidence
| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `make check` | Pass | Deliberately negative fixture |
## Remaining Risks
- None
EOF
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: schema v2 CR without fresh_pass verification policy passed contract checks" >&2
    exit 1
  fi
  rm "$target/docs/closure/CR-20260610-schema-v2-invalid.md"

  mkdir -p "$target/specs/003-missing-cpk"
  cat > "$target/specs/003-missing-cpk/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260610-missing.md
---
# Missing CPK
EOF
  printf '# plan\n' > "$target/specs/003-missing-cpk/plan.md"
  printf '# tasks\n' > "$target/specs/003-missing-cpk/tasks.md"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null 2>&1); then
    echo "ERROR: spec referencing a missing CPK passed contract checks" >&2
    exit 1
  fi
  rm -rf "$target/specs/003-missing-cpk"

  mkdir -p "$target/docs/sot/product"
  printf '# Historical project Truth\n' > "$target/docs/sot/product/HISTORICAL.md"
  truth_before="$(shasum -a 256 "$target/docs/sot/product/HISTORICAL.md" | awk '{print $1}')"
  cpk_before="$(shasum -a 256 "$target/docs/change_packs/CPK-20260610-r1-smoke.md" | awk '{print $1}')"
  spec_before="$(shasum -a 256 "$target/specs/001-r1-smoke/spec.md" | awk '{print $1}')"
  cr_before="$(shasum -a 256 "$target/docs/closure/CR-20260610-r1-smoke.md" | awk '{print $1}')"
  add_locked_obsolete_011_assets "$target"

  echo "==> Upgrading $rel smoke target with 0.11 managed assets"
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --dry-run --source "$release_root")
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$release_root")
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
  test ! -e "$target/.p2t2c/prompts/05_execute_single_task_prompt.md"
  test ! -e "$target/.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md"
  test ! -e "$target/.p2t2c/generated/phase_rules.txt"
  test "$truth_before" = "$(shasum -a 256 "$target/docs/sot/product/HISTORICAL.md" | awk '{print $1}')"
  test "$cpk_before" = "$(shasum -a 256 "$target/docs/change_packs/CPK-20260610-r1-smoke.md" | awk '{print $1}')"
  test "$spec_before" = "$(shasum -a 256 "$target/specs/001-r1-smoke/spec.md" | awk '{print $1}')"
  test "$cr_before" = "$(shasum -a 256 "$target/docs/closure/CR-20260610-r1-smoke.md" | awk '{print $1}')"

  echo "==> Rolling back $rel smoke upgrade"
  upgrade_dir="$(find "$target/.p2t2c/upgrade" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
  (cd "$target" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback "$upgrade_dir")
  test "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" = "0.11.0"
  test -f "$target/.p2t2c/prompts/05_execute_single_task_prompt.md"
  test -f "$target/.p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md"
  test -f "$target/.p2t2c/generated/phase_rules.txt"
  test "$truth_before" = "$(shasum -a 256 "$target/docs/sot/product/HISTORICAL.md" | awk '{print $1}')"
  test "$cpk_before" = "$(shasum -a 256 "$target/docs/change_packs/CPK-20260610-r1-smoke.md" | awk '{print $1}')"
  test "$spec_before" = "$(shasum -a 256 "$target/specs/001-r1-smoke/spec.md" | awk '{print $1}')"
  test "$cr_before" = "$(shasum -a 256 "$target/docs/closure/CR-20260610-r1-smoke.md" | awk '{print $1}')"
}

run_release_root "P2T2C_EN"
run_release_root "P2T2C_CN"

echo "P2T2C release smoke tests passed."
