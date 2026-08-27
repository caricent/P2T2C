#!/usr/bin/env bash
set -euo pipefail
umask 077

usage() {
  cat <<'EOF'
Usage:
  p2t2c_run.sh --work-id ID --event-type verification
    --verification-profile PROFILE --command-id ID

  p2t2c_run.sh --work-id ID --event-type exploration|tdd_red|tdd_green|mutation
    --command-label SAFE_LABEL -- COMMAND [ARG ...]

  p2t2c_run.sh --work-id ID --event-type tdd_exemption --reason-digest SHA256
  p2t2c_run.sh --work-id ID --event-type route
    --from-risk R0|R1|R2 --to-risk R0|R1|R2
    --from-shape spike|bounded|architectural --to-shape spike|bounded|architectural
  p2t2c_run.sh --work-id ID --event-type isolation
    --workspace-kind worktree|branch|shared_owned --branch NAME --baseline-sha OID --clean true|false
  p2t2c_run.sh --work-id ID --event-type repair --repair-round 1|2
    --hypothesis-digest SHA256 --implementer ID --failure-digest SHA256
    --fix-base-sha OID --fix-head-sha OID --fix-diff-digest SHA256
  p2t2c_run.sh --work-id ID --event-type gate_b --gate-b-decision VALUE --gate-b-ref VALUE
  p2t2c_run.sh --work-id ID --event-type review
    --implementer ID --reviewer ID --reviewer-session ID --review-role batch|global|specialist|re_review
    [--batch-id ID]
    --scope-digest SHA256 --base-sha OID --verdict pass|fail
    --critical N --important N --minor N

Add --show-output to echo raw command output; default recording is quiet.

For a new R0 audit run (no CPK), the first event also requires:
  --risk R0 --execution-shape bounded|architectural --implementer ID
  --tdd-policy required|exempt|not_applicable
Optional R0 flags default false: --production-code-change, --multi-agent,
--governance-change, --specialist-review-required.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

safe_id() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,191}$ ]]
}

json_field() {
  local key="$1"
  P2T2C_JSON_INPUT="$context_json" perl -MJSON::PP -e '
    $o=JSON::PP->new->utf8(1)->decode($ENV{P2T2C_JSON_INPUT});
    $v=$o->{$ARGV[0]};
    if (JSON::PP::is_bool($v)) { print $v ? q(true) : q(false) }
    else { print $v }
  ' "$key"
}

acquire_lifecycle() {
  local attempt=0
  while [[ $attempt -lt 200 ]]; do
    if mkdir "$lifecycle_lock" 2>/dev/null; then
      chmod 700 "$lifecycle_lock"
      printf '%s\n' "$owner_token" > "$lifecycle_lock/owner"
      chmod 600 "$lifecycle_lock/owner"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.1
  done
  die "timed out waiting for run lifecycle lock"
}

release_lifecycle() {
  [[ -f "$lifecycle_lock/owner" ]] || die "lifecycle lock has no owner"
  [[ "$(sed -n '1p' "$lifecycle_lock/owner")" == "$owner_token" ]] || die "refusing to release another lifecycle owner"
  rm -f "$lifecycle_lock/owner"
  rmdir "$lifecycle_lock"
}

work_id=""
event_type=""
verification_profile=""
command_id=""
command_label=""
risk=""
execution_shape=""
implementer=""
tdd_policy=""
production_code_change="false"
multi_agent="false"
governance_change="false"
specialist_review_required="false"
reason_digest=""
from_risk=""
to_risk=""
from_shape=""
to_shape=""
workspace_kind=""
branch=""
baseline_sha=""
clean=""
repair_round=""
hypothesis_digest=""
gate_b_decision=""
gate_b_ref=""
reviewer=""
reviewer_session=""
review_role=""
scope_digest=""
base_sha=""
verdict=""
critical=""
important=""
minor=""
failure_digest=""
fix_base_sha=""
fix_head_sha=""
fix_diff_digest=""
batch_id=""
show_output="false"
command=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-id|--event-type|--verification-profile|--command-id|--command-label|--risk|--execution-shape|--implementer|--tdd-policy|--production-code-change|--multi-agent|--governance-change|--specialist-review-required|--reason-digest|--from-risk|--to-risk|--from-shape|--to-shape|--workspace-kind|--branch|--baseline-sha|--clean|--repair-round|--hypothesis-digest|--failure-digest|--fix-base-sha|--fix-head-sha|--fix-diff-digest|--gate-b-decision|--gate-b-ref|--reviewer|--reviewer-session|--review-role|--batch-id|--scope-digest|--base-sha|--verdict|--critical|--important|--minor)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      key="${1#--}"
      key="${key//-/_}"
      printf -v "$key" '%s' "$2"
      shift 2
      ;;
    --show-output)
      show_output="true"; shift
      ;;
    --)
      shift
      command=("$@")
      break
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$work_id" && "$work_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "valid --work-id is required"
[[ -n "$event_type" ]] || die "--event-type is required"
[[ -d .p2t2c && -d docs ]] || die "run from the project root containing .p2t2c and docs"
[[ ! -L .p2t2c ]] || die ".p2t2c must not be a symlink"

script_dir="$(cd "$(dirname "$0")" && pwd)"
helper="$script_dir/p2t2c_evidence.pl"
[[ -f "$helper" && ! -L "$helper" ]] || die "missing or unsafe evidence helper"

cpk_path="docs/change_packs/$work_id.md"
run_root=".p2t2c/runs"
run_dir="$run_root/$work_id"
contract_file="$run_dir/contract.json"
ledger="$run_dir/events.jsonl"

[[ ! -L "$run_root" && ! -L "$run_dir" && ! -L "$contract_file" && ! -L "$ledger" ]] || die "run paths must not be symlinks"
mkdir -p "$run_root"
chmod 700 "$run_root"
if [[ ! -e "$run_root/.gitignore" ]]; then
  printf '*\n!.gitignore\n' > "$run_root/.gitignore"
fi
[[ ! -L "$run_root/.gitignore" && -f "$run_root/.gitignore" ]] || die "unsafe runs .gitignore"
chmod 600 "$run_root/.gitignore"
[[ "$(sed -n '1,2p' "$run_root/.gitignore")" == $'*\n!.gitignore' ]] || die "$run_root/.gitignore must contain '*' and '!.gitignore'"
mkdir -p "$run_dir"
chmod 700 "$run_dir"

if [[ -f "$cpk_path" ]]; then
  context_json="$(perl "$helper" --action context-cpk --file "$cpk_path" --work-id "$work_id")"
else
  if [[ -f "$contract_file" ]]; then
    context_json="$(sed -n '1p' "$contract_file")"
  else
    [[ "$risk" == "R0" ]] || die "no CPK found; a new run must declare --risk R0"
    [[ "$execution_shape" =~ ^(bounded|architectural)$ ]] || die "R0 audit execution shape must be bounded or architectural"
    safe_id "$implementer" || die "R0 audit requires a safe --implementer"
    [[ "$tdd_policy" =~ ^(required|exempt|not_applicable)$ ]] || die "R0 audit requires --tdd-policy"
    for pair in "production_code_change:$production_code_change" "multi_agent:$multi_agent" "governance_change:$governance_change" "specialist_review_required:$specialist_review_required"; do
      [[ "${pair#*:}" =~ ^(true|false)$ ]] || die "${pair%%:*} must be true or false"
    done
    export P2T2C_R0_WORK_ID="$work_id" P2T2C_R0_SHAPE="$execution_shape" P2T2C_R0_IMPLEMENTER="$implementer"
    export P2T2C_R0_TDD="$tdd_policy" P2T2C_R0_PRODUCTION="$production_code_change" P2T2C_R0_MULTI="$multi_agent"
    export P2T2C_R0_GOVERNANCE="$governance_change" P2T2C_R0_SPECIALIST="$specialist_review_required"
    context_json="$(perl -MDigest::SHA=sha256_hex -MJSON::PP -e '
      $j=JSON::PP->new->canonical(1)->utf8(1);
      %core=(work_id=>$ENV{P2T2C_R0_WORK_ID},risk=>q(R0),execution_shape=>$ENV{P2T2C_R0_SHAPE},
        production_code_change=>$ENV{P2T2C_R0_PRODUCTION} eq q(true)?$j->true:$j->false,
        multi_agent=>$ENV{P2T2C_R0_MULTI} eq q(true)?$j->true:$j->false,work_pack=>q(none),
        implementer=>$ENV{P2T2C_R0_IMPLEMENTER},tdd_policy=>$ENV{P2T2C_R0_TDD},
        governance_change=>$ENV{P2T2C_R0_GOVERNANCE} eq q(true)?$j->true:$j->false,
        specialist_review_required=>$ENV{P2T2C_R0_SPECIALIST} eq q(true)?$j->true:$j->false,
        gate_a=>q(not_required),truth_patch_ref=>q(none),truth_patch_digest=>q(none),
        gate_b_status=>q(not_triggered),gate_b_decision=>q(none),gate_b_ref=>q(none),
        ownership_batches=>($ENV{P2T2C_R0_SHAPE} eq q(architectural)?q(r0-audit):q(none)),
        legacy_startup_evidence=>$j->false);
      $digest=sha256_hex($j->encode(\%core));
      %context=(schema_version=>1,%core,status=>q(audit),cpk_path=>q(none),
        evidence_target=>q(docs/closure/CR-).($ENV{P2T2C_R0_WORK_ID}=~s/^R0-//r).q(.md),contract_digest=>$digest);
      print $j->encode(\%context);
    ')"
  fi
fi

current_contract_status="$(json_field status)"
if [[ -e "$contract_file" ]]; then
  [[ -f "$contract_file" && ! -L "$contract_file" ]] || die "unsafe run contract"
  existing_context="$(sed -n '1p' "$contract_file")"
  P2T2C_EXISTING_CONTEXT="$existing_context" P2T2C_CURRENT_CONTEXT="$context_json" perl -MJSON::PP -e '
    $j=JSON::PP->new->canonical(1)->utf8(1);
    $a=$j->decode($ENV{P2T2C_EXISTING_CONTEXT}); $b=$j->decode($ENV{P2T2C_CURRENT_CONTEXT});
    delete $a->{status}; delete $b->{status}; delete $a->{baseline_sha}; delete $b->{baseline_sha};
    exit($j->encode($a) eq $j->encode($b) ? 0 : 1);
  ' || die "run contract differs from current CPK/R0 contract outside ignored status"
  context_json="$existing_context"
else
  frozen_baseline="$(perl "$helper" --action head)"
  context_json="$(P2T2C_CONTEXT_JSON="$context_json" P2T2C_FROZEN_BASELINE="$frozen_baseline" perl -MJSON::PP -e '
    $j=JSON::PP->new->canonical(1)->utf8(1); $o=$j->decode($ENV{P2T2C_CONTEXT_JSON});
    $o->{baseline_sha}=$ENV{P2T2C_FROZEN_BASELINE}; print $j->encode($o);
  ')"
fi

evidence_target="$(json_field evidence_target)"
contract_digest="$(json_field contract_digest)"
contract_risk="$(json_field risk)"
contract_shape="$(json_field execution_shape)"
contract_implementer="$(json_field implementer)"
contract_gate_a="$(json_field gate_a)"
contract_status="$current_contract_status"
contract_baseline="$(json_field baseline_sha)"

if [[ ! -e "$contract_file" ]]; then
  temporary_contract="$run_dir/.contract-$$"
  printf '%s\n' "$context_json" > "$temporary_contract"
  chmod 600 "$temporary_contract"
  mv "$temporary_contract" "$contract_file"
fi
chmod 600 "$contract_file"
if [[ ! -e "$ledger" ]]; then
  : > "$ledger"
fi
[[ -f "$ledger" && ! -L "$ledger" ]] || die "unsafe evidence ledger"
chmod 600 "$ledger"
ledger_identity="$(perl -e '@s=lstat($ARGV[0]); @s or die "missing ledger\n"; -f _ && !-l _ or die "unsafe ledger\n"; print "$s[0]:$s[1]\n"' "$ledger")"

if [[ -f "$cpk_path" ]]; then
  perl "$helper" --action validate-run-state --work-id "$work_id" --cpk "$cpk_path" >/dev/null
else
  perl "$helper" --action validate-run-state --work-id "$work_id" >/dev/null
fi

if [[ "$contract_risk" == "R2" && "$contract_gate_a" == "pending" && ! "$event_type" =~ ^(exploration|route|isolation)$ ]]; then
  die "Gate A pending permits only exploration, route, or isolation events"
fi
if [[ "$contract_status" == "blocked" && ! "$event_type" =~ ^(exploration|route|isolation)$ ]]; then
  die "blocked contract permits only exploration, route, or isolation events"
fi
if [[ ! -s "$ledger" && "$event_type" != "route" ]]; then
  die "the first evidence event must be route"
fi

case "$event_type" in
  verification)
    [[ "$verification_profile" =~ ^(fast|impacted|full|governance)$ ]] || die "verification requires --verification-profile"
    [[ "$command_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || die "verification requires a safe --command-id"
    [[ ${#command[@]} -eq 0 ]] || die "verification commands come from project_config; do not pass argv"
    command_info="$(perl "$helper" --action verification-command --verification-profile "$verification_profile" --command-id "$command_id" --work-id "$work_id")"
    run_command="$(P2T2C_JSON_INPUT="$command_info" perl -MJSON::PP -e '$o=decode_json($ENV{P2T2C_JSON_INPUT}); print $o->{run}')"
    command_label="$(P2T2C_JSON_INPUT="$command_info" perl -MJSON::PP -e '$o=decode_json($ENV{P2T2C_JSON_INPUT}); print $o->{command_label}')"
    argv_digest="$(P2T2C_JSON_INPUT="$command_info" perl -MJSON::PP -e '$o=decode_json($ENV{P2T2C_JSON_INPUT}); print $o->{argv_digest}')"
    profile_config_digest="$(P2T2C_JSON_INPUT="$command_info" perl -MJSON::PP -e '$o=decode_json($ENV{P2T2C_JSON_INPUT}); print $o->{profile_config_digest}')"
    covered_commands_json="$(P2T2C_JSON_INPUT="$command_info" perl -MJSON::PP -e '$o=decode_json($ENV{P2T2C_JSON_INPUT}); print JSON::PP->new->canonical(1)->encode($o->{covered_commands} || [])')"
    ;;
  exploration|tdd_red|tdd_green|mutation)
    safe_id "$command_label" || die "$event_type requires a safe --command-label"
    [[ ${#command[@]} -gt 0 ]] || die "$event_type requires a command after --"
    argv_digest="$(perl -MDigest::SHA=sha256_hex -e 'print sha256_hex(join("\0",@ARGV)."\0")' -- "${command[@]}")"
    profile_config_digest=""
    covered_commands_json="[]"
    ;;
  tdd_exemption)
    [[ "$reason_digest" =~ ^[0-9a-f]{64}$ ]] || die "tdd_exemption requires --reason-digest SHA256"
    ;;
  route)
    [[ "$from_risk" =~ ^R[012]$ && "$to_risk" =~ ^R[012]$ ]] || die "route requires valid from/to risk"
    [[ "$from_shape" =~ ^(spike|bounded|architectural)$ && "$to_shape" =~ ^(spike|bounded|architectural)$ ]] || die "route requires valid from/to shape"
    [[ "$to_risk" == "$contract_risk" && "$to_shape" == "$contract_shape" ]] || die "route destination must match current contract"
    ;;
  isolation)
    [[ "$workspace_kind" =~ ^(worktree|branch|shared_owned)$ ]] || die "isolation requires --workspace-kind"
    [[ -n "$branch" && ! "$branch" =~ [[:cntrl:]] ]] || die "isolation requires a safe --branch"
    [[ "$baseline_sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || die "isolation requires --baseline-sha Git OID"
    [[ "$baseline_sha" == "$contract_baseline" ]] || die "isolation baseline_sha must equal frozen run baseline $contract_baseline"
    [[ "$clean" =~ ^(true|false)$ ]] || die "isolation requires --clean true or false"
    ;;
  repair)
    [[ "$repair_round" =~ ^[12]$ ]] || die "repair requires --repair-round 1 or 2"
    [[ "$hypothesis_digest" =~ ^[0-9a-f]{64}$ ]] || die "repair requires --hypothesis-digest SHA256"
    [[ "$implementer" == "$contract_implementer" ]] || die "repair implementer must match contract"
    [[ "$failure_digest" =~ ^[0-9a-f]{64}$ && "$fix_diff_digest" =~ ^[0-9a-f]{64}$ ]] || die "repair requires failure/fix SHA256 digests"
    [[ "$fix_base_sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ && "$fix_head_sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || die "repair requires fix base/head OIDs"
    git cat-file -e "$fix_base_sha^{commit}" 2>/dev/null && git cat-file -e "$fix_head_sha^{commit}" 2>/dev/null || die "repair fix base/head must be local commits"
    git merge-base --is-ancestor "$fix_base_sha" "$fix_head_sha" || die "repair fix base must be ancestor of fix head"
    actual_fix_digest="$(git diff --binary "$fix_base_sha" "$fix_head_sha" | shasum -a 256 | awk '{print $1}')"
    [[ "$actual_fix_digest" == "$fix_diff_digest" ]] || die "repair fix_diff_digest does not match commits"
    ;;
  gate_b)
    [[ -n "$gate_b_decision" && -n "$gate_b_ref" && ! "$gate_b_decision$gate_b_ref" =~ [[:cntrl:]] ]] || die "gate_b requires safe decision/ref"
    ;;
  review)
    safe_id "$implementer" || die "review requires safe --implementer"
    safe_id "$reviewer" || die "review requires safe --reviewer"
    safe_id "$reviewer_session" || die "review requires safe --reviewer-session"
    [[ "$implementer" == "$contract_implementer" ]] || die "review implementer must match contract"
    [[ "$reviewer" != "$implementer" ]] || die "reviewer must differ from implementer"
    [[ "$review_role" =~ ^(batch|global|specialist|re_review)$ ]] || die "review requires --review-role"
    if [[ "$review_role" == "batch" ]]; then
      [[ "$batch_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || die "batch review requires --batch-id"
    else
      [[ -z "$batch_id" ]] || die "--batch-id is only valid for batch review"
    fi
    [[ "$scope_digest" =~ ^[0-9a-f]{64}$ ]] || die "review requires --scope-digest SHA256"
    [[ "$base_sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] || die "review requires --base-sha Git OID"
    [[ "$verdict" =~ ^(pass|fail)$ ]] || die "review requires --verdict"
    [[ "$critical" =~ ^[0-9]+$ && "$important" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || die "review requires all finding counts"
    git cat-file -e "$base_sha^{commit}" 2>/dev/null || die "review base_sha is not a local commit"
    head_for_review="$(git rev-parse --verify HEAD)"
    git merge-base --is-ancestor "$base_sha" "$head_for_review" || die "review base_sha is not an ancestor of HEAD"
    ;;
  *)
    die "unsupported event type: $event_type"
    ;;
esac

owner_token="$(printf '%s:%s:%s' "$$" "$work_id" "$RANDOM" | shasum -a 256 | awk '{print substr($1,1,24)}')"
lifecycle_lock="$run_dir/.lifecycle-lock"
active_marker="$run_dir/.active-$owner_token"
closing_marker="$run_dir/.closing"
output_file="$(mktemp "${TMPDIR:-/tmp}/p2t2c-output.XXXXXX")"
output_log=""
output_log_name=""
outputs_identity=""
event_appended=0

held_remove_output() {
  [[ -n "${output_log_name:-}" && -n "${outputs_identity:-}" ]] || return 0
  P2T2C_RUN_DIR="$run_dir" P2T2C_RUN_IDENTITY="$run_dir_identity" P2T2C_OUTPUTS_IDENTITY="$outputs_identity" P2T2C_LOG_NAME="$output_log_name" perl -MFcntl=:DEFAULT -e '
    use strict; use warnings; use Fcntl qw(O_RDONLY O_NOFOLLOW);
    chdir($ENV{P2T2C_RUN_DIR}) or exit 1; my @run=stat(q(.)); exit 1 if "$run[0]:$run[1]" ne $ENV{P2T2C_RUN_IDENTITY};
    chdir(q(outputs)) or exit 1; my @dir=stat(q(.)); exit 1 if "$dir[0]:$dir[1]" ne $ENV{P2T2C_OUTPUTS_IDENTITY};
    sysopen(my $fh,$ENV{P2T2C_LOG_NAME},O_RDONLY|O_NOFOLLOW) or exit 1; my @st=stat($fh); exit 1 if !-f _ || $st[3]!=1; close $fh; unlink($ENV{P2T2C_LOG_NAME}) or exit 1;
  '
}

cleanup() {
  rm -f "$output_file"
  [[ "$event_appended" != "0" ]] || held_remove_output || true
  if [[ -f "$active_marker" && "$(sed -n '1p' "$active_marker" 2>/dev/null || true)" == "$owner_token" ]]; then
    if mkdir "$lifecycle_lock" 2>/dev/null; then
      chmod 700 "$lifecycle_lock"
      printf '%s\n' "$owner_token" > "$lifecycle_lock/owner"
      chmod 600 "$lifecycle_lock/owner"
      rm -f "$active_marker"
      release_lifecycle || true
    fi
  fi
}
trap cleanup EXIT INT TERM

acquire_lifecycle
[[ ! -e "$closing_marker" ]] || { release_lifecycle; die "run is closing"; }
printf '%s\n' "$owner_token" > "$active_marker"
chmod 600 "$active_marker"
release_lifecycle
run_dir_identity="$(perl -e '@s=lstat($ARGV[0]);@s&&-d _&&!-l _ or die "unsafe run dir\n";print "$s[0]:$s[1]"' "$run_dir")"

started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
started_ms="$(perl -MTime::HiRes=time -e 'printf "%.0f",time()*1000')"
started_tree_sha="$(perl "$helper" --action tree --target "$evidence_target")"
started_head_sha="$(perl "$helper" --action head)"
exit_code=0

case "$event_type" in
  verification)
    set +e
    bash -c "$run_command" > "$output_file" 2>&1
    exit_code=$?
    set -e
    ;;
  exploration|tdd_red|tdd_green|mutation)
    set +e
    "${command[@]}" > "$output_file" 2>&1
    exit_code=$?
    set -e
    ;;
  *)
    : > "$output_file"
    ;;
esac
if [[ "$show_output" == "true" ]]; then
  cat "$output_file"
fi

finished_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
finished_ms="$(perl -MTime::HiRes=time -e 'printf "%.0f",time()*1000')"
duration_ms=$((finished_ms - started_ms))
tree_sha="$(perl "$helper" --action tree --target "$evidence_target")"
head_sha="$(perl "$helper" --action head)"
if [[ "$event_type" == "exploration" && ( "$tree_sha" != "$started_tree_sha" || "$head_sha" != "$started_head_sha" ) ]]; then
  die "exploration changed the governed tree or HEAD; restore the change before continuing"
fi
output_digest="$(shasum -a 256 "$output_file" | awk '{print $1}')"
output_bytes="$(wc -c < "$output_file" | tr -d '[:space:]')"
output_lines="$(awk 'END {print NR+0}' "$output_file")"
output_summary="exit=$exit_code; bytes=$output_bytes; lines=$output_lines; sha256=$output_digest"
event_id="evt-${finished_ms}-$$"
recorded_at="$finished_at"
if [[ "$event_type" =~ ^(verification|exploration|tdd_red|tdd_green|mutation)$ && "$exit_code" -ne 0 ]]; then
  outputs_dir="$run_dir/outputs"
  output_log_name="$event_id.log"
  output_log="$outputs_dir/$output_log_name"
  outputs_identity="$(P2T2C_OUTPUT_SOURCE="$output_file" P2T2C_RUN_DIR="$run_dir" P2T2C_RUN_IDENTITY="$run_dir_identity" P2T2C_LOG_NAME="$output_log_name" perl -e '
    use strict; use warnings; use Fcntl qw(:mode O_WRONLY O_CREAT O_EXCL O_NOFOLLOW);
    chdir($ENV{P2T2C_RUN_DIR}) or die "cannot hold run directory: $!\n"; my @run=stat(q(.)); "$run[0]:$run[1]" eq $ENV{P2T2C_RUN_IDENTITY} or die "run directory identity changed\n";
    if (!mkdir(q(outputs),0700)) { $!{EEXIST} or die "cannot create outputs: $!\n" }
    my @dir=lstat(q(outputs)); @dir&&S_ISDIR($dir[2])&&!S_ISLNK($dir[2])&&($dir[2]&0777)==0700&&$dir[4]==$< or die "unsafe outputs directory\n";
    chdir(q(outputs)) or die "cannot hold outputs directory\n"; my @held=stat(q(.)); "$held[0]:$held[1]" eq "$dir[0]:$dir[1]" or die "outputs directory identity changed\n";
    sysopen(my $out,$ENV{P2T2C_LOG_NAME},O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600)
      or die "cannot create failure log: $!\n";
    open my $in,q(<:raw),$ENV{P2T2C_OUTPUT_SOURCE} or die "cannot read command output: $!\n";
    my $buffer; while (read($in,$buffer,65536)) { print {$out} $buffer or die "cannot write failure log: $!\n" }
    close $in; close $out or die "cannot close failure log: $!\n";
    print "$held[0]:$held[1]";
  ')" || die "cannot persist cold failure log"
fi

export P2T2C_EVENT_ID="$event_id" P2T2C_WORK_ID="$work_id" P2T2C_EVENT_TYPE="$event_type"
export P2T2C_CONTRACT_DIGEST="$contract_digest" P2T2C_TREE_SHA="$tree_sha" P2T2C_HEAD_SHA="$head_sha"
export P2T2C_RECORDED_AT="$recorded_at" P2T2C_EVIDENCE_TARGET="$evidence_target"
export P2T2C_STARTED_TREE_SHA="$started_tree_sha" P2T2C_STARTED_HEAD_SHA="$started_head_sha"
export P2T2C_COMMAND_LABEL="${command_label:-}" P2T2C_ARGV_DIGEST="${argv_digest:-}"
export P2T2C_EXIT_CODE="$exit_code" P2T2C_STARTED_AT="$started_at" P2T2C_FINISHED_AT="$finished_at"
export P2T2C_DURATION_MS="$duration_ms" P2T2C_OUTPUT_DIGEST="$output_digest" P2T2C_OUTPUT_BYTES="$output_bytes"
export P2T2C_OUTPUT_LINES="$output_lines" P2T2C_OUTPUT_SUMMARY="$output_summary"
export P2T2C_VERIFICATION_PROFILE="$verification_profile" P2T2C_PROFILE_CONFIG_DIGEST="${profile_config_digest:-}" P2T2C_COMMAND_ID="$command_id"
export P2T2C_COVERED_COMMANDS="${covered_commands_json:-[]}"
export P2T2C_REASON_DIGEST="$reason_digest" P2T2C_FROM_RISK="$from_risk" P2T2C_TO_RISK="$to_risk"
export P2T2C_FROM_SHAPE="$from_shape" P2T2C_TO_SHAPE="$to_shape" P2T2C_WORKSPACE_KIND="$workspace_kind"
export P2T2C_BRANCH="$branch" P2T2C_BASELINE_SHA="$baseline_sha" P2T2C_CLEAN="$clean"
export P2T2C_REPAIR_ROUND="$repair_round" P2T2C_HYPOTHESIS_DIGEST="$hypothesis_digest"
export P2T2C_FAILURE_DIGEST="$failure_digest" P2T2C_FIX_BASE_SHA="$fix_base_sha" P2T2C_FIX_HEAD_SHA="$fix_head_sha" P2T2C_FIX_DIFF_DIGEST="$fix_diff_digest"
export P2T2C_GATE_B_DECISION="$gate_b_decision" P2T2C_GATE_B_REF="$gate_b_ref"
export P2T2C_IMPLEMENTER="$implementer" P2T2C_REVIEWER="$reviewer" P2T2C_REVIEWER_SESSION="$reviewer_session"
export P2T2C_REVIEW_ROLE="$review_role" P2T2C_SCOPE_DIGEST="$scope_digest" P2T2C_BASE_SHA="$base_sha"
export P2T2C_BATCH_ID="$batch_id"
export P2T2C_VERDICT="$verdict" P2T2C_CRITICAL="$critical" P2T2C_IMPORTANT="$important" P2T2C_MINOR="$minor"

event_json="$(perl -MJSON::PP -e '
  $j=JSON::PP->new->canonical(1)->utf8(1);
  %e=(schema_version=>1,event_id=>$ENV{P2T2C_EVENT_ID},work_id=>$ENV{P2T2C_WORK_ID},event_type=>$ENV{P2T2C_EVENT_TYPE},
    contract_digest=>$ENV{P2T2C_CONTRACT_DIGEST},tree_sha=>$ENV{P2T2C_TREE_SHA},head_sha=>$ENV{P2T2C_HEAD_SHA},
    recorded_at=>$ENV{P2T2C_RECORDED_AT},evidence_target=>$ENV{P2T2C_EVIDENCE_TARGET},
    tree_excludes=>[q(.p2t2c/runs/**),$ENV{P2T2C_EVIDENCE_TARGET}]);
  $t=$e{event_type};
  if ($t=~/^(?:verification|exploration|tdd_red|tdd_green|mutation)$/) {
    @e{qw(started_tree_sha started_head_sha command_label argv_digest started_at finished_at output_digest output_summary)}=
      @ENV{qw(P2T2C_STARTED_TREE_SHA P2T2C_STARTED_HEAD_SHA P2T2C_COMMAND_LABEL P2T2C_ARGV_DIGEST P2T2C_STARTED_AT P2T2C_FINISHED_AT P2T2C_OUTPUT_DIGEST P2T2C_OUTPUT_SUMMARY)};
    $e{exit_code}=0+$ENV{P2T2C_EXIT_CODE}; $e{duration_ms}=0+$ENV{P2T2C_DURATION_MS};
    $e{output_bytes}=0+$ENV{P2T2C_OUTPUT_BYTES}; $e{output_lines}=0+$ENV{P2T2C_OUTPUT_LINES};
    if ($t eq q(verification)) {
      @e{qw(verification_profile profile_config_digest command_id)}=@ENV{qw(P2T2C_VERIFICATION_PROFILE P2T2C_PROFILE_CONFIG_DIGEST P2T2C_COMMAND_ID)};
      my $covered=$j->decode($ENV{P2T2C_COVERED_COMMANDS}); $e{covered_commands}=$covered if @$covered;
    }
  } elsif ($t eq q(tdd_exemption)) { $e{reason_digest}=$ENV{P2T2C_REASON_DIGEST} }
  elsif ($t eq q(route)) { @e{qw(from_risk to_risk from_shape to_shape)}=@ENV{qw(P2T2C_FROM_RISK P2T2C_TO_RISK P2T2C_FROM_SHAPE P2T2C_TO_SHAPE)} }
  elsif ($t eq q(isolation)) { @e{qw(workspace_kind branch baseline_sha)}=@ENV{qw(P2T2C_WORKSPACE_KIND P2T2C_BRANCH P2T2C_BASELINE_SHA)}; $e{clean}=$ENV{P2T2C_CLEAN} eq q(true)?$j->true:$j->false }
  elsif ($t eq q(repair)) { $e{repair_round}=0+$ENV{P2T2C_REPAIR_ROUND}; @e{qw(hypothesis_digest implementer failure_digest fix_base_sha fix_head_sha fix_diff_digest)}=@ENV{qw(P2T2C_HYPOTHESIS_DIGEST P2T2C_IMPLEMENTER P2T2C_FAILURE_DIGEST P2T2C_FIX_BASE_SHA P2T2C_FIX_HEAD_SHA P2T2C_FIX_DIFF_DIGEST)} }
  elsif ($t eq q(gate_b)) { @e{qw(gate_b_decision gate_b_ref)}=@ENV{qw(P2T2C_GATE_B_DECISION P2T2C_GATE_B_REF)} }
  elsif ($t eq q(review)) { @e{qw(implementer reviewer reviewer_session review_role scope_digest base_sha verdict)}=@ENV{qw(P2T2C_IMPLEMENTER P2T2C_REVIEWER P2T2C_REVIEWER_SESSION P2T2C_REVIEW_ROLE P2T2C_SCOPE_DIGEST P2T2C_BASE_SHA P2T2C_VERDICT)}; $e{batch_id}=$ENV{P2T2C_BATCH_ID} if $e{review_role} eq q(batch); $e{critical}=0+$ENV{P2T2C_CRITICAL}; $e{important}=0+$ENV{P2T2C_IMPORTANT}; $e{minor}=0+$ENV{P2T2C_MINOR} }
  print $j->encode(\%e);
')"

acquire_lifecycle
[[ -f "$active_marker" && "$(sed -n '1p' "$active_marker")" == "$owner_token" ]] || { release_lifecycle; die "active marker ownership lost"; }
[[ ! -e "$closing_marker" ]] || { release_lifecycle; die "run began closing before event append"; }
P2T2C_LEDGER="$ledger" P2T2C_LEDGER_IDENTITY="$ledger_identity" P2T2C_EVENT_JSON="$event_json" perl -e '
  use strict; use warnings; use Fcntl qw(O_WRONLY O_APPEND O_NOFOLLOW);
  my ($expected_dev,$expected_ino)=split /:/,$ENV{P2T2C_LEDGER_IDENTITY},2;
  my @before=lstat($ENV{P2T2C_LEDGER});
  @before && -f _ && !-l _ or die "ledger replaced by non-regular path\n";
  $before[3]==1 or die "ledger hard-link count is unsafe\n";
  "$before[0]:$before[1]" eq "$expected_dev:$expected_ino" or die "ledger inode changed during command\n";
  sysopen(my $fh,$ENV{P2T2C_LEDGER},O_WRONLY|O_APPEND|O_NOFOLLOW)
    or die "cannot safely append ledger: $!\n";
  my @open=stat($fh);
  "$open[0]:$open[1]" eq "$expected_dev:$expected_ino" or die "opened ledger inode mismatch\n";
  print {$fh} $ENV{P2T2C_EVENT_JSON},"\n" or die "cannot append ledger event: $!\n";
  close $fh or die "cannot close ledger append: $!\n";
' || { release_lifecycle; die "secure ledger append failed"; }
event_appended=1
rm -f "$active_marker"
release_lifecycle

echo "P2T2C evidence recorded: $event_id -> $ledger" >&2
if [[ -n "$output_log" ]]; then
  echo "P2T2C command failed; cold log: $output_log (sha256=$output_digest)" >&2
  P2T2C_RUN_DIR="$run_dir" P2T2C_RUN_IDENTITY="$run_dir_identity" P2T2C_OUTPUTS_IDENTITY="$outputs_identity" P2T2C_LOG_NAME="$output_log_name" perl -e '
    use strict; use warnings; use Fcntl qw(O_RDONLY O_NOFOLLOW);
    chdir($ENV{P2T2C_RUN_DIR}) or die $!; my @run=stat(q(.)); "$run[0]:$run[1]" eq $ENV{P2T2C_RUN_IDENTITY} or die "run identity changed\n";
    chdir(q(outputs)) or die $!; my @dir=stat(q(.)); "$dir[0]:$dir[1]" eq $ENV{P2T2C_OUTPUTS_IDENTITY} or die "outputs identity changed\n";
    sysopen(my $fh,$ENV{P2T2C_LOG_NAME},O_RDONLY|O_NOFOLLOW) or die $!;
    local $/; my $raw=<$fh>//q(); close $fh; $raw=substr($raw,-16384) if length($raw)>16384;
    my @lines=split /\n/,$raw,-1; @lines=@lines[-80..-1] if @lines>80;
    my $tail=join("\n",@lines); $tail=~s/([^\x09\x0a\x20-\x7e])/sprintf("\\x%02X",ord($1))/ge;
    $tail=substr($tail,-16384) if length($tail)>16384;
    print STDERR "--- sanitized failure tail ---\n$tail\n--- end failure tail ---\n";
  '
fi
exit "$exit_code"
