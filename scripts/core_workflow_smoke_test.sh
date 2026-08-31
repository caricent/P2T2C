#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="${1:-$repo_root/P2T2C_EN}"
scope="${2:-all}"
case "$scope" in all|documents|migration-security|migration-transaction) ;; *) echo "ERROR: unknown core smoke scope: $scope" >&2; exit 2 ;; esac
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/p2t2c-core-smoke.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

write_r1() {
  local root="$1" id="$2" sp="$3" tests="${4:-passed}"
  mkdir -p "$root/docs/specs/$id"
  cat > "$root/docs/proposals/$sp.md" <<EOF
---
artifact: proposal
schema_version: 1
id: $sp
status: approved
risk: R1
decision: not_required
decision_ref: none
specs_ref: docs/specs/$id
truth_ref: none
truth_digest: none
---

# $sp

## Why

- Deliver a small mapped behavior.

## What changes

- Add one observable output.

## Non-goals

- Do not change unrelated behavior.

## Observable outcomes

- The output exists.

## Truth impact

- Existing SOT remains authoritative.

## Decision

- No new semantic decision.
EOF
  cat > "$root/docs/specs/$id/design.md" <<EOF
---
artifact: design
schema_version: 1
proposal: docs/proposals/$sp.md
status: ready
---

# Design

## Context references

- The proposal and current SOT.

## Technical decisions

- Use the smallest local implementation.

## Interfaces and data flow

- No external interface change.

## Data or migration design

- None.

## Risks and trade-offs

- None.

## Open questions

- None.
EOF
  cat > "$root/docs/specs/$id/tasks.md" <<EOF
---
artifact: implementation_tasks
schema_version: 1
proposal: docs/proposals/$sp.md
design: docs/specs/$id/design.md
status: in_progress
---

# Tasks

## Tasks

- [x] 1.1 Implement the output
- [x] 1.2 Run the selected project check

## Completion

- Tests: $tests
- Verify: not_run
- Known blockers: none
- Dangerous operations: none
- Authorization ref: none
- Summary: Business outcome delivered.
EOF
}

if [[ "$scope" == "all" || "$scope" == "documents" ]]; then
target="$tmp_root/project"
mkdir -p "$target/docs/sot/billing"
printf '%s\n' '# Project-owned billing Truth' > "$target/docs/sot/billing/CUSTOM.md"
custom_sot_before="$(shasum -a 256 "$target/docs/sot/billing/CUSTOM.md" | awk '{print $1}')"
bash "$source_root/.p2t2c/bin/p2t2c_install.sh" --apply --target "$target" >/dev/null
custom_sot_after="$(shasum -a 256 "$target/docs/sot/billing/CUSTOM.md" | awk '{print $1}')"
[[ "$custom_sot_before" == "$custom_sot_after" ]] || { echo "ERROR: install changed an unknown project SOT domain" >&2; exit 1; }

write_r1 "$target" "001-small-change" "SP-20260831-small-change"
(cd "$target" && ./.p2t2c/bin/p2t2c validate-docs --json) | grep -q '"state":"valid"'

shim="$tmp_root/shim"
sentinel="$tmp_root/project-command-ran"
mkdir -p "$shim"
for command in make npm pnpm yarn; do
  cat > "$shim/$command" <<EOF
#!/usr/bin/env bash
touch "$sentinel"
exit 99
EOF
  chmod +x "$shim/$command"
done
mkdir "$target/.p2t2c/.documents-lock"
printf '%s\n' '99999999' > "$target/.p2t2c/.documents-lock/owner"
archive_json="$(cd "$target" && PATH="$shim:$PATH" ./.p2t2c/bin/p2t2c archive --spec 001-small-change --json)"
printf '%s' "$archive_json" | grep -q '"state":"completed"'
grep -q '^status: completed$' "$target/docs/specs/001-small-change/tasks.md"
[[ ! -e "$sentinel" ]] || { echo "ERROR: Archive executed a project command" >&2; exit 1; }
[[ ! -d "$target/.p2t2c/runs" && ! -d "$target/docs/closure" ]] || { echo "ERROR: core Archive created legacy evidence" >&2; exit 1; }

git -C "$target" init -q
git -C "$target" config user.name p2t2c-fixture
git -C "$target" config user.email p2t2c-fixture@example.invalid
git -C "$target" add .
git -C "$target" commit -qm baseline
mkdir -p "$target/docs/closure"
mkdir "$target/.p2t2c/.documents-lock"
printf '%s\n' "$$" > "$target/.p2t2c/.documents-lock/owner"
lock_run_log="$tmp_root/shared-document-lock.log"
(cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id R0-shared-document-lock --event-type route \
  --risk R0 --execution-shape bounded --implementer lock-fixture --tdd-policy not_applicable \
  --from-risk R0 --to-risk R0 --from-shape bounded --to-shape bounded) >"$lock_run_log" 2>&1 &
lock_run_pid=$!
sleep 0.2
[[ ! -d "$target/.p2t2c/runs/R0-shared-document-lock" ]] || { echo "ERROR: legacy run ignored the shared document lock" >&2; exit 1; }
rm "$target/.p2t2c/.documents-lock/owner"
rmdir "$target/.p2t2c/.documents-lock"
set +e
wait "$lock_run_pid"
lock_run_status=$?
set -e
if [[ "$lock_run_status" -ne 0 ]]; then cat "$lock_run_log" >&2; echo "ERROR: legacy run failed after document lock release" >&2; exit 1; fi
[[ -f "$target/.p2t2c/runs/R0-shared-document-lock/events.jsonl" ]] || { echo "ERROR: legacy run did not resume after document lock release" >&2; exit 1; }
mv "$target/.p2t2c/runs" "$tmp_root/shared-lock-run"

write_r1 "$target" "008-concurrent-edit" "SP-20260831-concurrent-edit"
concurrent_tasks="$target/docs/specs/008-concurrent-edit/tasks.md"
concurrent_log="$tmp_root/archive-concurrent.log"
exec 9>>"$concurrent_tasks"
(cd "$target" && P2T2C_TEST_ARCHIVE_PAUSE_BEFORE_FINAL_CHECK_MS=1000 ./.p2t2c/bin/p2t2c archive --spec 008-concurrent-edit --json) >"$concurrent_log" 2>&1 &
concurrent_pid=$!
marker_seen=0
for _ in $(seq 1 200); do
  if grep -q 'P2T2C_TEST_MARKER:archive_before_final_check' "$concurrent_log" 2>/dev/null; then marker_seen=1; break; fi
  sleep 0.01
done
[[ "$marker_seen" -eq 1 ]] || { echo "ERROR: Archive concurrent-edit fixture missed its pause" >&2; exit 1; }
printf '%s\n' '' '# concurrent user edit' >&9
exec 9>&-
set +e
wait "$concurrent_pid"
concurrent_status=$?
set -e
[[ "$concurrent_status" -eq 4 ]] || { echo "ERROR: Archive accepted a concurrent edit to its original inode" >&2; exit 1; }
grep -q '# concurrent user edit' "$concurrent_tasks"
grep -q '^status: in_progress$' "$concurrent_tasks"
if find "$target/docs/specs/008-concurrent-edit" -maxdepth 1 -name '.p2t2c-doc-*' -print -quit | grep -q .; then
  echo "ERROR: Archive concurrent-edit rollback left transaction files" >&2; exit 1
fi

write_r1 "$target" "009-truth-race" "SP-20260831-truth-race"
truth_path="$target/docs/sot/governance/P2T2C_GOVERNANCE.md"
truth_digest="$(shasum -a 256 "$truth_path" | awk '{print $1}')"
perl -0pi -e 's/^risk: R1$/risk: R2/m;s/^decision: not_required$/decision: approved/m;s/^decision_ref: none$/decision_ref: user-20260831-truth-race/m;s{^truth_ref: none$}{truth_ref: docs/sot/governance/P2T2C_GOVERNANCE.md}m;s/^truth_digest: none$/truth_digest: '"$truth_digest"'/m' "$target/docs/proposals/SP-20260831-truth-race.md"
truth_backup="$tmp_root/governance.before-truth-race"
cp "$truth_path" "$truth_backup"
truth_race_log="$tmp_root/archive-truth-race.log"
(cd "$target" && P2T2C_TEST_ARCHIVE_PAUSE_BEFORE_FINAL_CHECK_MS=1000 ./.p2t2c/bin/p2t2c archive --spec 009-truth-race --json) >"$truth_race_log" 2>&1 &
truth_race_pid=$!
marker_seen=0
for _ in $(seq 1 200); do
  if grep -q 'P2T2C_TEST_MARKER:archive_before_final_check' "$truth_race_log" 2>/dev/null; then marker_seen=1; break; fi
  sleep 0.01
done
[[ "$marker_seen" -eq 1 ]] || { echo "ERROR: Archive Truth-race fixture missed its pause" >&2; exit 1; }
printf '\n' >> "$truth_path"
set +e
wait "$truth_race_pid"
truth_race_status=$?
set -e
cp "$truth_backup" "$truth_path"
[[ "$truth_race_status" -eq 4 ]] || { echo "ERROR: Archive accepted Truth drift during final install" >&2; exit 1; }
grep -q '^status: in_progress$' "$target/docs/specs/009-truth-race/tasks.md"

write_r1 "$target" "010-crlf" "SP-20260831-crlf"
crlf_tasks="$target/docs/specs/010-crlf/tasks.md"
crlf_expected="$tmp_root/tasks-crlf.expected"
perl -0pi -e 's/\r?\n/\r\n/g' "$target/docs/proposals/SP-20260831-crlf.md" "$target/docs/specs/010-crlf/design.md" "$crlf_tasks"
cp "$crlf_tasks" "$crlf_expected"
perl -0pi -e 's/^(status:\h*)in_progress(\h*)\r$/${1}completed${2}\r/m' "$crlf_expected"
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 010-crlf --json) >/dev/null
cmp -s "$crlf_expected" "$crlf_tasks" || { echo "ERROR: Archive rewrote bytes beyond the CRLF status value" >&2; exit 1; }

write_r1 "$target" "004-duplicate-completion" "SP-20260831-duplicate-completion"
perl -0pi -e 's/- Tests: passed/- Tests: passed\n- Tests: passed/' "$target/docs/specs/004-duplicate-completion/tasks.md"
set +e
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 004-duplicate-completion --json) >/dev/null
duplicate_completion_status=$?
set -e
[[ "$duplicate_completion_status" -eq 4 ]] || { echo "ERROR: duplicate Completion field did not block Archive" >&2; exit 1; }

write_r1 "$target" "005-invalid-deferral" "SP-20260831-invalid-deferral"
perl -0pi -e 's/- \[x\] 1\.2 Run the selected project check/- [-] 1.2 Defer the selected project check; decision: none/' "$target/docs/specs/005-invalid-deferral/tasks.md"
set +e
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 005-invalid-deferral --json) >/dev/null
invalid_deferral_status=$?
set -e
[[ "$invalid_deferral_status" -eq 4 ]] || { echo "ERROR: sentinel deferral reference did not block Archive" >&2; exit 1; }

write_r1 "$target" "006-unindexed-r2" "SP-20260831-unindexed-r2"
unindexed_digest="$(shasum -a 256 "$target/docs/sot/billing/CUSTOM.md" | awk '{print $1}')"
perl -0pi -e 's/^risk: R1$/risk: R2/m;s/^decision: not_required$/decision: approved/m;s/^decision_ref: none$/decision_ref: user-20260831-unindexed/m;s{^truth_ref: none$}{truth_ref: docs/sot/billing/CUSTOM.md}m;s/^truth_digest: none$/truth_digest: '"$unindexed_digest"'/m' "$target/docs/proposals/SP-20260831-unindexed-r2.md"
set +e
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 006-unindexed-r2 --json) >/dev/null
unindexed_r2_status=$?
set -e
[[ "$unindexed_r2_status" -eq 4 ]] || { echo "ERROR: unindexed R2 Truth did not block Archive" >&2; exit 1; }

write_r1 "$target" "007-history-r2" "SP-20260831-history-r2"
history_digest="$(shasum -a 256 "$target/docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md" | awk '{print $1}')"
perl -0pi -e 's/^risk: R1$/risk: R2/m;s/^decision: not_required$/decision: approved/m;s/^decision_ref: none$/decision_ref: user-20260831-history/m;s{^truth_ref: none$}{truth_ref: docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md}m;s/^truth_digest: none$/truth_digest: '"$history_digest"'/m' "$target/docs/proposals/SP-20260831-history-r2.md"
set +e
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 007-history-r2 --json) >/dev/null
history_r2_status=$?
set -e
[[ "$history_r2_status" -eq 4 ]] || { echo "ERROR: history R2 Truth did not block Archive" >&2; exit 1; }

write_r1 "$target" "002-known-failure" "SP-20260831-known-failure" failed
set +e
blocked="$(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 002-known-failure --json)"
blocked_status=$?
set -e
[[ "$blocked_status" -eq 4 ]] || { echo "ERROR: failed tests did not block Archive" >&2; exit 1; }
printf '%s' "$blocked" | grep -q '"state":"blocked"'

mkdir -p "$target/docs/specs/003-pending-r2"
cp "$target/docs/specs/002-known-failure/design.md" "$target/docs/specs/003-pending-r2/design.md"
cp "$target/docs/specs/002-known-failure/tasks.md" "$target/docs/specs/003-pending-r2/tasks.md"
cat > "$target/docs/proposals/SP-20260831-pending-r2.md" <<'EOF'
---
artifact: proposal
schema_version: 1
id: SP-20260831-pending-r2
status: proposed
risk: R2
decision: pending
decision_ref: none
specs_ref: docs/specs/003-pending-r2
truth_ref: docs/sot/governance/P2T2C_GOVERNANCE.md
truth_digest: none
---

# SP-20260831-pending-r2

## Why

- Resolve an undecided semantic change.

## What changes

- Pending.

## Non-goals

- Do not implement before approval.

## Observable outcomes

- None before approval.

## Truth impact

- Governance Truth may change.

## Decision

- Pending.
EOF
perl -0pi -e 's{docs/proposals/SP-20260831-known-failure\.md}{docs/proposals/SP-20260831-pending-r2.md}g;s{docs/specs/002-known-failure}{docs/specs/003-pending-r2}g;s/Tests: failed/Tests: passed/' "$target/docs/specs/003-pending-r2/design.md" "$target/docs/specs/003-pending-r2/tasks.md"
set +e
(cd "$target" && ./.p2t2c/bin/p2t2c archive --spec 003-pending-r2 --json) >/dev/null
pending_status=$?
set -e
[[ "$pending_status" -eq 4 ]] || { echo "ERROR: pending R2 did not block Archive" >&2; exit 1; }
fi

if [[ "$scope" == "all" || "$scope" == migration-* ]]; then
migration="$tmp_root/migration"
mkdir -p "$migration"
bash "$source_root/.p2t2c/bin/p2t2c_install.sh" --apply --target "$migration" >/dev/null
write_r1 "$migration" "111-core-before-rollback" "SP-20260831-core-before-rollback"
mkdir -p "$migration/.p2t2c/upgrade/fake-rollback"
set +e
(cd "$migration" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/fake-rollback) >/dev/null 2>&1
core_template_rollback_status=$?
set -e
[[ "$core_template_rollback_status" -ne 0 ]] || { echo "ERROR: template rollback accepted active 0.15 core documents" >&2; exit 1; }
mkdir -p "$migration/docs/submit_proposals" "$migration/specs/900-legacy" "$migration/docs/adr" "$migration/docs/change_packs" "$migration/docs/sot/product"
cat > "$migration/docs/submit_proposals/SP-20200101-legacy.md" <<'EOF'
# SP-20200101-legacy

## Intent

- Historical proposal.
- See specs/900-legacy/spec.md and docs/adr/ADR-900-legacy.md.
EOF
printf 'legacy spec\n' > "$migration/specs/900-legacy/spec.md"
printf '# ADR-900\n\nHistorical decision.\n' > "$migration/docs/adr/ADR-900-legacy.md"
printf '%s\n' '---' 'artifact: change_pack' 'schema_version: 2' 'id: CPK-900-legacy' 'risk: R1' 'source: user_instruction' 'truth_change: false' 'gate_a: not_required' 'status: applied' '---' > "$migration/docs/change_packs/CPK-900-legacy.md"
cat > "$migration/docs/sot/product/PRODUCT.md" <<'EOF'
# Product Truth

## DEC-900: Legacy Decision

Status: Active
Source: docs/adr/ADR-900-legacy.md
EOF
product_before_digest="$(shasum -a 256 "$migration/docs/sot/product/PRODUCT.md" | awk '{print $1}')"
perl -0pi -e 's/^risk: R1$/risk: R2/m;s/^decision: not_required$/decision: approved/m;s/^decision_ref: none$/decision_ref: user-20260831-product-decision/m;s{^truth_ref: none$}{truth_ref: docs/sot/product/PRODUCT.md}m;s/^truth_digest: none$/truth_digest: '"$product_before_digest"'/m' "$migration/docs/proposals/SP-20260831-core-before-rollback.md"
P2T2C_PRODUCT_DIGEST="$product_before_digest" perl -0pi -e 's{\nadrs: \[\]}{\n  - path: "docs/sot/product/PRODUCT.md"\n    sha256: "$ENV{P2T2C_PRODUCT_DIGEST}"\n    rule_ids: []\n    decision_ids: ["DEC-900"]\n    topics: ["product"]\n\nadrs: []}' "$migration/docs/sot/manifest.yaml"
fixture_manifest_digest="$(shasum -a 256 "$migration/docs/sot/manifest.yaml" | awk '{print $1}')"
P2T2C_MANIFEST_DIGEST="$fixture_manifest_digest" perl -0pi -e 's/^[0-9a-f]{64}  docs\/sot\/manifest\.yaml$/$ENV{P2T2C_MANIFEST_DIGEST}  docs\/sot\/manifest.yaml/m' "$migration/.p2t2c/CHECKSUMS.sha256" "$migration/.p2t2c/lock.sha256"
fixture_checksums_digest="$(shasum -a 256 "$migration/.p2t2c/CHECKSUMS.sha256" | awk '{print $1}')"
P2T2C_CHECKSUMS_DIGEST="$fixture_checksums_digest" perl -0pi -e 's/^[0-9a-f]{64}  \.p2t2c\/CHECKSUMS\.sha256$/$ENV{P2T2C_CHECKSUMS_DIGEST}  .p2t2c\/CHECKSUMS.sha256/m' "$migration/.p2t2c/lock.sha256"
cat > "$migration/ACTIVE.md" <<'EOF'
See docs/adr/ADR-900-legacy.md and docs/change_packs/CPK-900-legacy.md.
Keep the current path docs/specs/001-current/design.md unchanged.
EOF
printf '%s\n' 'LEGACY_DECISION = "docs/adr/ADR-900-legacy.md"' > "$migration/ACTIVE.py"
cat > "$migration/decision-map.json" <<'EOF'
{"docs/adr/ADR-900-legacy.md":"docs/sot/product/PRODUCT.md#DEC-900"}
EOF
mkdir -p "$migration/.p2t2c/runs/active-fixture"
printf 'active\n' > "$migration/.p2t2c/runs/active-fixture/marker"
if [[ "$scope" == "all" || "$scope" == "migration-security" ]]; then
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
active_status=$?
set -e
[[ "$active_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted an active legacy run" >&2; exit 1; }
rm -rf "$migration/.p2t2c/runs/active-fixture"
rmdir "$migration/.p2t2c/runs" 2>/dev/null || true
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
unclosed_status=$?
set -e
[[ "$unclosed_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted an unclosed legacy CPK" >&2; exit 1; }
else
rm -rf "$migration/.p2t2c/runs/active-fixture"
rmdir "$migration/.p2t2c/runs" 2>/dev/null || true
fi
mkdir -p "$migration/docs/closure"
cat > "$migration/docs/closure/CR-900-legacy.md" <<'EOF'
---
artifact: closure_report
schema_version: 2
id: CR-900-legacy
risk: R1
change_pack: docs/change_packs/CPK-900-legacy.md
execution_pack: specs/900-legacy
truth_drift: none
decision: CLOSE
verification_policy: fresh_pass
---

# CR-900-legacy

## Verification Evidence

| Command | Result |
|---|---|
| `fixture` | Pass |

## Remaining Risks

- None.
EOF
if [[ "$scope" == "all" || "$scope" == "migration-security" ]]; then
mkdir -p "$migration/docs/reference/archive/adr"
printf 'collision\n' > "$migration/docs/reference/archive/adr/ADR-900-legacy.md"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
collision_status=$?
set -e
[[ "$collision_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted an archive collision" >&2; exit 1; }
rm "$migration/docs/reference/archive/adr/ADR-900-legacy.md"
target_parent="$tmp_root/target-parent"
mkdir -p "$target_parent"
rmdir "$migration/docs/reference/archive/adr"
ln -s "$target_parent" "$migration/docs/reference/archive/adr"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
parent_symlink_status=$?
set -e
[[ "$parent_symlink_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted a symlinked target parent" >&2; exit 1; }
rm "$migration/docs/reference/archive/adr"
mv "$migration/docs/adr/ADR-900-legacy.md" "$tmp_root/ADR-900-original.md"
ln -s "$tmp_root/ADR-900-original.md" "$migration/docs/adr/ADR-900-legacy.md"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
symlink_status=$?
set -e
[[ "$symlink_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted a symlinked source" >&2; exit 1; }
rm "$migration/docs/adr/ADR-900-legacy.md"
mv "$tmp_root/ADR-900-original.md" "$migration/docs/adr/ADR-900-legacy.md"
fi
before="$(find "$migration" -type f -not -path '*/.git/*' -exec shasum -a 256 {} \; | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
legacy_before="$(find "$migration/docs/submit_proposals" "$migration/specs" "$migration/docs/adr" "$migration/docs/change_packs" "$migration/docs/closure" -type f -exec shasum -a 256 {} \; | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
mkdir -p "$migration/node_modules"
ln -s "$tmp_root/target-parent" "$migration/node_modules/unrelated-package-link"
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) | grep -q '"status":"planned"'
after_dry="$(find "$migration" -type f -not -path '*/.git/*' -exec shasum -a 256 {} \; | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
[[ "$before" == "$after_dry" ]] || { echo "ERROR: docs-migrate dry-run wrote files" >&2; exit 1; }
if [[ "$scope" == "all" || "$scope" == "migration-transaction" ]]; then
set +e
(cd "$migration" && P2T2C_TEST_DOCS_MIGRATE_FAIL_AT=after_first_source_unlink ./.p2t2c/bin/p2t2c docs-migrate --apply --decision-map decision-map.json --json) >/dev/null
injected_status=$?
set -e
[[ "$injected_status" -eq 4 ]] || { echo "ERROR: docs-migrate failure injection did not fail" >&2; exit 1; }
legacy_after_injection="$(find "$migration/docs/submit_proposals" "$migration/specs" "$migration/docs/adr" "$migration/docs/change_packs" "$migration/docs/closure" -type f -exec shasum -a 256 {} \; | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
[[ "$legacy_before" == "$legacy_after_injection" ]] || { echo "ERROR: docs-migrate failure did not restore legacy bytes" >&2; exit 1; }
grep -q 'docs/adr/ADR-900-legacy.md' "$migration/ACTIVE.md"
pending_report="$(find "$migration/.p2t2c/docs-migrate" -mindepth 2 -maxdepth 2 -type f -name report.json -print | LC_ALL=C sort | tail -1)"
perl -0pi -e 's/"status":"rolled_back"/"status":"applying"/' "$pending_report"
pending_before="$(shasum -a 256 "$pending_report" | awk '{print $1}')"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --dry-run --decision-map decision-map.json --json) >/dev/null
pending_report_status=$?
set -e
pending_after="$(shasum -a 256 "$pending_report" | awk '{print $1}')"
[[ "$pending_report_status" -eq 4 && "$pending_before" == "$pending_after" ]] || { echo "ERROR: docs-migrate dry-run recovered or rewrote pending state" >&2; exit 1; }
perl -0pi -e 's/"status":"applying"/"status":"rolled_back"/' "$pending_report"
set +e
partial_output="$(cd "$migration" && P2T2C_TEST_DOCS_MIGRATE_HARD_EXIT_AT=rewrite_tmp_partial ./.p2t2c/bin/p2t2c docs-migrate --apply --decision-map decision-map.json --json)"
partial_exit_status=$?
set -e
[[ "$partial_exit_status" -eq 92 ]] || { printf '%s\n' "$partial_output" >&2; echo "ERROR: docs-migrate partial-write fixture did not stop inside CAS temporary" >&2; exit 1; }
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c archive --spec 111-core-before-rollback --json) >/dev/null
archive_during_pending_status=$?
set -e
[[ "$archive_during_pending_status" -eq 4 ]] || { echo "ERROR: Archive ignored an unfinished document migration" >&2; exit 1; }
set +e
(cd "$migration" && P2T2C_TEST_DOCS_MIGRATE_HARD_EXIT_AT=cas_after_detach ./.p2t2c/bin/p2t2c docs-migrate --apply --decision-map decision-map.json --json) >/dev/null
hard_exit_status=$?
set -e
[[ "$hard_exit_status" -eq 91 ]] || { echo "ERROR: docs-migrate hard-interrupt fixture did not stop inside CAS" >&2; exit 1; }
apply_json="$(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --apply --decision-map decision-map.json --json)"
report="$(V3_JSON="$apply_json" perl -MJSON::PP -e 'print decode_json($ENV{V3_JSON})->{report}')"
[[ -f "$migration/docs/proposals/SP-20200101-legacy.md" ]]
[[ -f "$migration/docs/reference/archive/adr/ADR-900-legacy.md" ]]
[[ -f "$migration/docs/reference/archive/specs/900-legacy/spec.md" ]]
grep -q 'docs/sot/product/PRODUCT.md#DEC-900' "$migration/ACTIVE.md"
grep -q 'docs/sot/product/PRODUCT.md#DEC-900' "$migration/ACTIVE.py"
grep -q 'docs/specs/001-current/design.md' "$migration/ACTIVE.md"
grep -q 'docs/specs/' "$migration/P2T2C_AGENTS.md"
grep -q 'docs/reference/archive/specs/900-legacy/spec.md' "$migration/docs/proposals/SP-20200101-legacy.md"
grep -q 'docs/sot/product/PRODUCT.md#DEC-900' "$migration/docs/proposals/SP-20200101-legacy.md"
product_after_digest="$(shasum -a 256 "$migration/docs/sot/product/PRODUCT.md" | awk '{print $1}')"
[[ "$product_after_digest" != "$product_before_digest" ]] || { echo "ERROR: Truth reference rewrite did not change its digest" >&2; exit 1; }
grep -q "sha256: \"$product_after_digest\"" "$migration/docs/sot/manifest.yaml"
grep -q "truth_digest: $product_after_digest" "$migration/docs/proposals/SP-20260831-core-before-rollback.md"
(cd "$migration" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null && shasum -a 256 -c .p2t2c/lock.sha256 >/dev/null)
set +e
(cd "$migration" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/fake-rollback) >/dev/null 2>&1
template_rollback_status=$?
set -e
[[ "$template_rollback_status" -ne 0 ]] || { echo "ERROR: template rollback accepted an applied document migration" >&2; exit 1; }
report_backup="$tmp_root/applied-migration-report.json"
cp "$migration/$report" "$report_backup"
perl -0pi -e 's/"status":"applied"/"status":"rolled_back"/' "$migration/$report"
set +e
(cd "$migration" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/fake-rollback) >/dev/null 2>&1
tampered_template_status=$?
set -e
[[ "$tampered_template_status" -ne 0 ]] || { echo "ERROR: template rollback trusted a tampered migration status" >&2; exit 1; }
cp "$report_backup" "$migration/$report"
mv "$migration/$report" "$tmp_root/deleted-applied-report.json"
set +e
(cd "$migration" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback .p2t2c/upgrade/fake-rollback) >/dev/null 2>&1
missing_report_template_status=$?
set -e
[[ "$missing_report_template_status" -ne 0 ]] || { echo "ERROR: template rollback ignored a deleted applied migration report" >&2; exit 1; }
mv "$tmp_root/deleted-applied-report.json" "$migration/$report"
fake_dir="$migration/.p2t2c/docs-migrate/forged"
mkdir -p "$fake_dir"
cp "$migration/$report" "$fake_dir/report.json"
perl -0pi -e 's/"operation_id":"[^"]+"/"operation_id":"forged"/;s/"source":"[^"]+"/"source":"..\/outside"/' "$fake_dir/report.json"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --rollback .p2t2c/docs-migrate/forged/report.json --json) >/dev/null
forged_status=$?
set -e
[[ "$forged_status" -eq 4 ]] || { echo "ERROR: docs-migrate accepted a forged rollback report" >&2; exit 1; }
rm "$fake_dir/report.json"
rmdir "$fake_dir"
set +e
(cd "$migration" && P2T2C_TEST_DOCS_MIGRATE_FAIL_AT=rollback_after_first_rewrite ./.p2t2c/bin/p2t2c docs-migrate --rollback "$report" --json) >/dev/null
rollback_injected_status=$?
set -e
[[ "$rollback_injected_status" -eq 4 ]] || { echo "ERROR: docs-migrate rollback failure injection did not fail" >&2; exit 1; }
grep -q '"status":"applied"' "$migration/$report"
[[ -f "$migration/docs/reference/archive/adr/ADR-900-legacy.md" && ! -e "$migration/docs/adr/ADR-900-legacy.md" ]]
grep -q 'docs/sot/product/PRODUCT.md#DEC-900' "$migration/ACTIVE.md"
active_after_backup="$tmp_root/ACTIVE.applied"
cp "$migration/ACTIVE.md" "$active_after_backup"
rollback_race_log="$tmp_root/rollback-race.log"
(cd "$migration" && P2T2C_TEST_DOCS_MIGRATE_PAUSE_BEFORE_ROLLBACK_MS=1000 ./.p2t2c/bin/p2t2c docs-migrate --rollback "$report" --json) >"$rollback_race_log" 2>&1 &
rollback_race_pid=$!
marker_seen=0
for _ in $(seq 1 200); do
  if grep -q 'P2T2C_TEST_MARKER:before_rollback_mutation' "$rollback_race_log" 2>/dev/null; then marker_seen=1; break; fi
  sleep 0.01
done
[[ "$marker_seen" -eq 1 ]] || { echo "ERROR: rollback race fixture missed its pause" >&2; exit 1; }
printf '%s\n' 'concurrent rollback edit' >> "$migration/ACTIVE.md"
set +e
wait "$rollback_race_pid"
rollback_race_status=$?
set -e
[[ "$rollback_race_status" -eq 4 ]] || { echo "ERROR: rollback accepted a post-preflight concurrent edit" >&2; exit 1; }
grep -q '"status":"applied"' "$migration/$report"
grep -q 'concurrent rollback edit' "$migration/ACTIVE.md"
[[ -f "$migration/docs/reference/archive/adr/ADR-900-legacy.md" && ! -e "$migration/docs/adr/ADR-900-legacy.md" ]]
cp "$active_after_backup" "$migration/ACTIVE.md"
cp "$migration/docs/reference/archive/adr/ADR-900-legacy.md" "$tmp_root/archive-before-conflict.md"
printf 'concurrent edit\n' >> "$migration/docs/reference/archive/adr/ADR-900-legacy.md"
set +e
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --rollback "$report" --json) >/dev/null
rollback_conflict_status=$?
set -e
[[ "$rollback_conflict_status" -eq 4 ]] || { echo "ERROR: docs-migrate rollback overwrote a concurrent edit" >&2; exit 1; }
[[ ! -e "$migration/docs/adr/ADR-900-legacy.md" ]] || { echo "ERROR: conflicting rollback partially restored sources" >&2; exit 1; }
cp "$tmp_root/archive-before-conflict.md" "$migration/docs/reference/archive/adr/ADR-900-legacy.md"
(cd "$migration" && ./.p2t2c/bin/p2t2c docs-migrate --rollback "$report" --json) | grep -q '"status":"rolled_back"'
[[ -f "$migration/docs/adr/ADR-900-legacy.md" && -f "$migration/specs/900-legacy/spec.md" ]]
grep -q 'docs/adr/ADR-900-legacy.md' "$migration/ACTIVE.md"
grep -q 'docs/adr/ADR-900-legacy.md' "$migration/ACTIVE.py"
grep -q "truth_digest: $product_before_digest" "$migration/docs/proposals/SP-20260831-core-before-rollback.md"
(cd "$migration" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null && shasum -a 256 -c .p2t2c/lock.sha256 >/dev/null)
legacy_after="$(find "$migration/docs/submit_proposals" "$migration/specs" "$migration/docs/adr" "$migration/docs/change_packs" "$migration/docs/closure" -type f -exec shasum -a 256 {} \; | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"
[[ "$legacy_before" == "$legacy_after" ]] || { echo "ERROR: docs-migrate rollback was not byte-exact" >&2; exit 1; }
fi
fi

echo "core workflow smoke passed: $scope"
