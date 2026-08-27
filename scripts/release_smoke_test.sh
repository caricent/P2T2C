#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
pre_close_work_id=""
suite="all"
language="both"
coverage_only=0
keep_smoke="${KEEP_P2T2C_SMOKE:-0}"
jobs=2
changed_from="HEAD"
changed_from_set=0
changed_paths=()
coverage_manifest="$repo_root/scripts/release_smoke_coverage.json"
case_registry="$repo_root/scripts/release_smoke_registry.tsv"
daily_map="$repo_root/scripts/release_smoke_daily_map.tsv"
fixture_014_archive="$repo_root/scripts/fixtures/p2t2c-0.14.0-release-roots.tar.gz"
fixture_014_digest="72c785a2fa0e8835732abf76eb93012c9b68a36c2344e6674550a135d6eb0256"

usage() {
  cat <<'EOF'
Usage: release_smoke_test.sh [OPTIONS]

Options:
  --suite contract|security|transaction|migration|locale|daily|all
  --language en|cn|both       Only for migration or locale (default: both)
  --pre-close-work-id ID      Check an active release work without recursion
  --jobs 1..8                 Maximum suite/language workers (default: 2)
  --changed-from GIT_REF      Base for daily selection (default: HEAD)
  --changed-path PATH         Explicit daily-selection path; repeatable
  --coverage-only             Validate the smoke coverage manifest and fixture
  --keep                      Keep isolated work and logs even after success

Without options, this runs the complete `all` release proof. Language-neutral
behavior runs once after parity; locale and migration use isolated EN/CN workers.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suite)
      [[ $# -ge 2 ]] || { echo "ERROR: --suite requires a value" >&2; exit 2; }
      suite="$2"
      shift 2
      ;;
    --language)
      [[ $# -ge 2 ]] || { echo "ERROR: --language requires a value" >&2; exit 2; }
      language="$2"
      shift 2
      ;;
    --pre-close-work-id)
      [[ $# -ge 2 ]] || { echo "ERROR: --pre-close-work-id requires ID" >&2; exit 2; }
      pre_close_work_id="$2"
      shift 2
      ;;
    --jobs)
      [[ $# -ge 2 ]] || { echo "ERROR: --jobs requires a value" >&2; exit 2; }
      jobs="$2"
      shift 2
      ;;
    --changed-from)
      [[ $# -ge 2 ]] || { echo "ERROR: --changed-from requires a value" >&2; exit 2; }
      changed_from="$2"
      changed_from_set=1
      shift 2
      ;;
    --changed-path)
      [[ $# -ge 2 ]] || { echo "ERROR: --changed-path requires a value" >&2; exit 2; }
      changed_paths+=("$2")
      shift 2
      ;;
    --coverage-only)
      coverage_only=1
      shift
      ;;
    --keep)
      keep_smoke=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$pre_close_work_id" && ! "$pre_close_work_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "ERROR: unsafe --pre-close-work-id: $pre_close_work_id" >&2
  exit 2
fi

case "$suite" in contract|security|transaction|migration|locale|daily|all) ;; *) echo "ERROR: unknown suite: $suite" >&2; exit 2 ;; esac
case "$language" in en|cn|both) ;; *) echo "ERROR: unknown language: $language" >&2; exit 2 ;; esac
[[ "$jobs" =~ ^[1-8]$ ]] || { echo "ERROR: --jobs must be an integer from 1 to 8" >&2; exit 2; }
if [[ "$language" != "both" && "$suite" != "migration" && "$suite" != "locale" ]]; then
  echo "ERROR: --language is only valid with migration or locale" >&2
  exit 2
fi
if [[ "$suite" != "daily" && ( "$changed_from_set" -eq 1 || "${#changed_paths[@]}" -gt 0 ) ]]; then
  echo "ERROR: --changed-from/--changed-path require --suite daily" >&2
  exit 2
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/p2t2c-release-smoke.XXXXXX")"
negative_log="$tmp_root/expected-failure.log"

cleanup() {
  local status=$?
  if [[ "$keep_smoke" != "1" && "$status" -eq 0 ]]; then
    rm -rf "$tmp_root"
  else
    echo "Smoke work and logs: $tmp_root" >&2
  fi
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

safe_tail() {
  local path="$1"
  [[ -f "$path" && ! -L "$path" ]] || { echo "[safe_tail unavailable: $path]"; return 0; }
  perl -e '
    use strict; use warnings; my $path=shift;
    open my $fh,"<:raw",$path or die "cannot read log\n"; local $/; my $raw=<$fh>//""; close $fh;
    $raw=~s/\e\][^\a]*(?:\a|\e\\)//g;
    $raw=~s/\e\[[0-?]*[ -\/]*[@-~]//g;
    $raw=~s/\r\n?/\n/g;
    $raw=~s/[^\x09\x0a\x20-\x7e]/?/g;
    my @lines=split /\n/,$raw,-1; pop @lines if @lines&&$lines[-1] eq "";
    @lines=@lines[-80..-1] if @lines>80;
    my $out=join("\n",@lines); $out.="\n" if length($out);
    $out=substr($out,length($out)-16384) if length($out)>16384;
    $out=~s/\A[^\n]*\n// if length($out)==16384&&$out=~/\n/;
    print $out;
  ' "$path"
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

permission_mode() {
  perl -e '@s=stat($ARGV[0]); @s or die "cannot stat $ARGV[0]: $!\n"; printf "%04o\n", $s[2] & 07777' "$1"
}

managed_paths() {
  awk '{ line=$0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); if (line != "" && line !~ /^#/) print line }' "$1"
}

validate_registry_dispatcher_file() {
  local script_path="$1"
  perl -0777 -e '
    use strict; use warnings; my $path=shift;
    open my $fh,"<:raw",$path or exit 2; local $/; my $raw=<$fh>//""; close $fh;
    my ($body)=$raw=~/^run_registered_cases\(\) \{\r?\n(.*?)^\}\r?$/ms;
    exit 3 if !defined $body;
    my $handler_calls=()=$body=~/^[ \t]*"\$handler"[ \t]*$/mg;
    my $observed_records=()=$body=~/^[ \t]*printf[ \t]+\x27%s\\n\x27[ \t]+"\$id"[ \t]+>>[ \t]+"\$observed"[ \t]*$/mg;
    exit(($handler_calls==1&&$observed_records==1)?0:1);
  ' "$script_path"
}

check_smoke_coverage() {
  local manifest_tmp="$tmp_root/coverage.manifest" registry_tmp="$tmp_root/coverage.registry"
  local id registered_suite scope handler mutated_dispatcher tail_input="$tmp_root/safe-tail.input" tail_output="$tmp_root/safe-tail.output"
  [[ -f "$coverage_manifest" && -f "$case_registry" && -f "$daily_map" ]] || fail "missing smoke coverage, registry, or daily mapping"
  perl -MJSON::PP -0777 -e '
    my $p=shift; open my $fh,"<",$p or die "$p: $!\n"; my $d=decode_json(<$fh>);
    die "coverage schema_version must be 1\n" unless $d->{schema_version} == 1;
    my %suite=map { $_=>1 } qw(contract security transaction migration locale);
    my (%seen,%seen_suite);
    for my $c (@{$d->{cases}||[]}) {
      die "invalid coverage case\n" unless ref($c) eq "HASH" && $c->{id} && $suite{$c->{suite}||""};
      die "duplicate coverage case $c->{id}\n" if $seen{$c->{id}}++;
      die "invalid language_scope for $c->{id}\n" unless ($c->{language_scope}||"") =~ /^(?:repo_once|neutral_once|bilingual_parallel)$/;
      $seen_suite{$c->{suite}}=1; print join("\t",$c->{id},$c->{suite},$c->{language_scope}),"\n";
    }
    for my $s (keys %suite) { die "empty coverage suite $s\n" unless $seen_suite{$s}; }
  ' "$coverage_manifest" | LC_ALL=C sort > "$manifest_tmp"
  awk -F '\t' '
    BEGIN {ok=1}
    /^[[:space:]]*#/ || NF==0 {next}
    NF!=4 {print "invalid registry row: " $0 > "/dev/stderr"; ok=0; next}
    $1 !~ /^[a-z0-9][a-z0-9._-]+$/ {ok=0}
    $2 !~ /^(contract|security|transaction|migration|locale)$/ {ok=0}
    $3 !~ /^(repo_once|neutral_once|bilingual_parallel)$/ {ok=0}
    seen[$1]++ {print "duplicate registry case: " $1 > "/dev/stderr"; ok=0}
    {print $1 "\t" $2 "\t" $3}
    END {exit !ok}
  ' "$case_registry" | LC_ALL=C sort > "$registry_tmp" || fail "invalid smoke case registry"
  diff -u "$registry_tmp" "$manifest_tmp" || fail "smoke manifest differs from the executable registry"
  while IFS=$'\t' read -r id registered_suite scope handler; do
    [[ -z "$id" || "${id:0:1}" == "#" ]] && continue
    declare -F "$handler" >/dev/null || fail "registered smoke handler does not exist: $id -> $handler"
  done < "$case_registry"
  declare -F run_registered_cases >/dev/null || fail "registry dispatcher is missing"
  validate_registry_dispatcher_file "$repo_root/scripts/release_smoke_test.sh" \
    || fail "run_registered_cases body must invoke one registered handler and record one completed call"
  mutated_dispatcher="$tmp_root/release_smoke_without_handler.sh"
  perl -ne 'next if /^[ \t]*"\$handler"[ \t]*$/; print' "$repo_root/scripts/release_smoke_test.sh" > "$mutated_dispatcher"
  if validate_registry_dispatcher_file "$mutated_dispatcher"; then
    fail "dispatcher mutation deleting the real handler invocation was accepted"
  fi

  : > "$tail_input"
  for index in $(seq 1 100); do printf '\033[31mline-%03d\033[0m control=\001 %0200d\n' "$index" 0 >> "$tail_input"; done
  safe_tail "$tail_input" > "$tail_output"
  [[ "$(wc -l < "$tail_output" | tr -d ' ')" -le 80 ]] || fail "safe_tail exceeded 80 lines"
  [[ "$(wc -c < "$tail_output" | tr -d ' ')" -le 16384 ]] || fail "safe_tail exceeded 16 KiB"
  perl -0777 -e 'local$/;$_=<>;exit 1 if /\e|[^\x09\x0a\x20-\x7e]/' "$tail_output" || fail "safe_tail retained ANSI or control bytes"

  inventory_fixture="$tmp_root/inventory-selftest"; mkdir -p "$inventory_fixture/.p2t2c"
  printf 'mode-and-byte-sentinel\n' > "$inventory_fixture/.p2t2c/sentinel"
  chmod 0644 "$inventory_fixture/.p2t2c/sentinel"
  target_inventory "$inventory_fixture" > "$tmp_root/inventory.before"
  chmod 0600 "$inventory_fixture/.p2t2c/sentinel"
  target_inventory "$inventory_fixture" > "$tmp_root/inventory.after-mode"
  cmp -s "$tmp_root/inventory.before" "$tmp_root/inventory.after-mode" && fail "target inventory missed mode drift"
  chmod 0644 "$inventory_fixture/.p2t2c/sentinel"
  printf 'leaked schema\n' > "$inventory_fixture/.p2t2c/leaked-schema.json"
  target_inventory "$inventory_fixture" > "$tmp_root/inventory.after-path"
  cmp -s "$tmp_root/inventory.before" "$tmp_root/inventory.after-path" && fail "target inventory missed path/byte leakage"

  check_refresh_source_metadata_umask_contract

  validate_daily_map
  [[ "$(select_daily_suites_for_paths 'P2T2C_EN/.p2t2c/bin/check_p2t2c.sh')" == $'contract\nsecurity\ntransaction' ]] || fail "daily selector engine mapping mismatch"
  [[ "$(select_daily_suites_for_paths 'scripts/fixtures/p2t2c-0.14.0-release-roots.tar.gz')" == "migration" ]] || fail "daily selector migration mapping mismatch"
  [[ "$(select_daily_suites_for_paths 'docs/unrelated.md')" == "contract" ]] || fail "daily selector catch-all mismatch"
  check_preclose_routing_contract
  check_make_preclose_routing_contract
  [[ -f "$fixture_014_archive" ]] || fail "missing byte-exact 0.14.0 release fixture"
  [[ "$(sha256_file "$fixture_014_archive")" == "$fixture_014_digest" ]] || fail "0.14.0 release fixture digest mismatch"
  if tar -tzf "$fixture_014_archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail "0.14.0 release fixture contains an unsafe archive path"
  fi
  [[ "$(tar -xOzf "$fixture_014_archive" P2T2C_EN/.p2t2c/VERSION | tr -d '[:space:]')" == "0.14.0" ]] \
    || fail "frozen EN release fixture is not 0.14.0"
  [[ "$(tar -xOzf "$fixture_014_archive" P2T2C_CN/.p2t2c/VERSION | tr -d '[:space:]')" == "0.14.0" ]] \
    || fail "frozen CN release fixture is not 0.14.0"
}

refresh_source_metadata() {
  local root="$1" rel
  local checksum_tmp="$root/.p2t2c/CHECKSUMS.sha256.tmp"
  local lock_tmp="$root/.p2t2c/lock.sha256.tmp"
  : > "$checksum_tmp"
  chmod 0644 "$checksum_tmp"
  while IFS= read -r rel; do
    [[ "$rel" == ".p2t2c/CHECKSUMS.sha256" ]] || (cd "$root" && shasum -a 256 "$rel") >> "$checksum_tmp"
  done < <(managed_paths "$root/.p2t2c/managed-files.txt")
  chmod 0644 "$checksum_tmp"
  mv "$checksum_tmp" "$root/.p2t2c/CHECKSUMS.sha256"
  : > "$lock_tmp"
  chmod 0644 "$lock_tmp"
  while IFS= read -r rel; do
    (cd "$root" && shasum -a 256 "$rel") >> "$lock_tmp"
  done < <(managed_paths "$root/.p2t2c/managed-files.txt")
  chmod 0644 "$lock_tmp"
  mv "$lock_tmp" "$root/.p2t2c/lock.sha256"
}

check_refresh_source_metadata_umask_contract() {
  local fixture="$tmp_root/metadata-umask-selftest"
  local checksum_paths="$tmp_root/metadata-umask.checksum-paths"
  local checksum_expected="$tmp_root/metadata-umask.checksum-expected"
  local lock_paths="$tmp_root/metadata-umask.lock-paths"
  local lock_expected="$tmp_root/metadata-umask.lock-expected"
  mkdir -p "$fixture/.p2t2c"
  printf 'metadata fixture\n' > "$fixture/asset.txt"
  printf '%s\n' \
    '.p2t2c/CHECKSUMS.sha256' \
    '.p2t2c/managed-files.txt' \
    '.p2t2c/managed-modes.txt' \
    'asset.txt' > "$fixture/.p2t2c/managed-files.txt"
  printf '%s\n' '# Deterministic fixture mode policy.' 'default 0644' > "$fixture/.p2t2c/managed-modes.txt"
  : > "$fixture/.p2t2c/CHECKSUMS.sha256"

  (umask 077; refresh_source_metadata "$fixture")

  [[ "$(permission_mode "$fixture/.p2t2c/CHECKSUMS.sha256")" == "0644" ]] \
    || fail "refresh_source_metadata made CHECKSUMS mode depend on umask"
  [[ "$(permission_mode "$fixture/.p2t2c/lock.sha256")" == "0644" ]] \
    || fail "refresh_source_metadata made lock mode depend on umask"
  (cd "$fixture" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null) \
    || fail "refresh_source_metadata produced invalid checksums under umask 077"
  (cd "$fixture" && shasum -a 256 -c .p2t2c/lock.sha256 >/dev/null) \
    || fail "refresh_source_metadata produced an invalid lock under umask 077"

  awk '{print $2}' "$fixture/.p2t2c/CHECKSUMS.sha256" > "$checksum_paths"
  managed_paths "$fixture/.p2t2c/managed-files.txt" \
    | awk '$0 != ".p2t2c/CHECKSUMS.sha256"' > "$checksum_expected"
  diff -u "$checksum_expected" "$checksum_paths" \
    || fail "refresh_source_metadata checksum inventory is incomplete"
  awk '{print $2}' "$fixture/.p2t2c/lock.sha256" > "$lock_paths"
  managed_paths "$fixture/.p2t2c/managed-files.txt" > "$lock_expected"
  diff -u "$lock_expected" "$lock_paths" \
    || fail "refresh_source_metadata lock inventory is incomplete"
}

managed_state_digest() {
  local root="$1" rel
  {
    while IFS= read -r rel; do
      [[ -f "$root/$rel" ]] && printf '%s  %s  %s\n' "$(sha256_file "$root/$rel")" "$(permission_mode "$root/$rel")" "$rel"
    done < <(managed_paths "$root/.p2t2c/managed-files.txt")
    [[ -f "$root/.p2t2c/lock.sha256" ]] && printf '%s  %s  %s\n' "$(sha256_file "$root/.p2t2c/lock.sha256")" "$(permission_mode "$root/.p2t2c/lock.sha256")" ".p2t2c/lock.sha256"
    [[ -f "$root/.p2t2c/project_config.yaml" ]] && printf '%s  %s  %s\n' "$(sha256_file "$root/.p2t2c/project_config.yaml")" "$(permission_mode "$root/.p2t2c/project_config.yaml")" ".p2t2c/project_config.yaml"
  } | shasum -a 256 | awk '{print $1}'
}

target_inventory() {
  local root="$1"
  (cd "$root" && perl -Mstrict -Mwarnings -MFile::Find -MDigest::SHA=sha256_hex -MFcntl=:mode -e '
    my @rows;
    File::Find::find({no_chdir=>1,wanted=>sub {
      my $path=$File::Find::name; $path=~s{^\./}{}; return if $path eq ".";
      if ($path=~m{^\.p2t2c/(?:install|upgrade)(?:/|$)}) {$File::Find::prune=1 if -d $File::Find::name; return}
      my @st=lstat($File::Find::name); die "cannot lstat $path\n" if !@st;
      my $mode=sprintf("%04o",$st[2]&07777);
      if (S_ISDIR($st[2])) {push @rows,"D\t$mode\t$path"; return}
      if (S_ISREG($st[2])) {open my $fh,"<:raw",$File::Find::name or die "cannot read $path\n";local$/;my$raw=<$fh>//"";close$fh;push @rows,"F\t$mode\t".sha256_hex($raw)."\t$path";return}
      if (S_ISLNK($st[2])) {my$link=readlink($File::Find::name);push @rows,"L\t$mode\t".sha256_hex($link//"")."\t$path";return}
      push @rows,"O\t$mode\t$path";
    }},".");
    my $has_non_transaction_state=grep {/\t\.p2t2c\//} @rows;
    @rows=grep {$_!~/^D\t[0-7]{4}\t\.p2t2c$/} @rows if !$has_non_transaction_state;
    print join("\n",sort @rows),"\n";
  ')
}

assert_target_inventory_equal() {
  local before="$1" after="$2" label="$3"
  diff -u "$before" "$after" || fail "$label leaked target paths, bytes, or modes outside transaction reports"
}

run_transaction_safety_contracts() {
  local rel="$1" release_root="$2"
  local contract_scope="${3:-all}"
  local fixture_root="$tmp_root/$rel-transaction"
  local valid_source="$fixture_root/valid-source"
  local corrupt_source="$fixture_root/corrupt-source"
  local failing_source="$fixture_root/failing-source"
  local owned_source="$fixture_root/project-owned-source"
  local evidence_source="$fixture_root/evidence-owned-source"
  local runtime_source="$fixture_root/runtime-owned-source"
  local bad_mode_source="$fixture_root/bad-mode-source"
  local bad_policy_source="$fixture_root/bad-policy-source"
  local hardlink_source="$fixture_root/hardlink-source"
  local hardlink_upgrade_source="$fixture_root/hardlink-upgrade-source"
  local swap_source="$fixture_root/swap-source"
  local dest_swap_source="$fixture_root/dest-swap-source"
  local dest_swap_upgrade_source="$fixture_root/dest-swap-upgrade-source"
  local ancestor_swap_source="$fixture_root/ancestor-swap-source"
  local corrupt_target="$fixture_root/corrupt-target"
  local failed_install_target="$fixture_root/failed-install-target"
  local failed_upgrade_target="$fixture_root/failed-upgrade-target"
  local symlink_install_target="$fixture_root/symlink-install-target"
  local symlink_upgrade_target="$fixture_root/symlink-upgrade-target"
  local owned_install_target="$fixture_root/project-owned-install-target"
  local owned_upgrade_target="$fixture_root/project-owned-upgrade-target"
  local evidence_install_target="$fixture_root/evidence-owned-install-target"
  local mode_install_target="$fixture_root/mode-install-target"
  local mode_upgrade_target="$fixture_root/mode-upgrade-target"
  local hardlink_target="$fixture_root/hardlink-target"
  local source_hardlink_victim="$fixture_root/source-hardlink-victim"
  local target_hardlink_victim="$fixture_root/target-hardlink-victim"
  local upgrade_source_hardlink_victim="$fixture_root/upgrade-source-hardlink-victim"
  local upgrade_target_hardlink_victim="$fixture_root/upgrade-target-hardlink-victim"
  local hardlink_upgrade_target="$fixture_root/hardlink-upgrade-target"
  local swap_target="$fixture_root/source-swap-target"
  local dest_swap_target="$fixture_root/dest-swap-target"
  local dest_swap_victim="$fixture_root/dest-swap-victim"
  local dest_swap_parked="$fixture_root/dest-swap-parked"
  local dest_swap_upgrade_target="$fixture_root/dest-swap-upgrade-target"
  local dest_swap_upgrade_victim="$fixture_root/dest-swap-upgrade-victim"
  local dest_swap_upgrade_parked="$fixture_root/dest-swap-upgrade-parked"
  local ancestor_swap_target="$fixture_root/ancestor-swap-target"
  local ancestor_swap_victim="$fixture_root/ancestor-swap-victim"
  local ancestor_swap_parked="$fixture_root/ancestor-swap-parked"
  local after_rename_fail_target="$fixture_root/after-rename-fail-target"
  local after_rename_replace_target="$fixture_root/after-rename-replace-target"
  local install_victim="$fixture_root/install-broken-victim"
  local upgrade_sentinel="$fixture_root/upgrade-live-sentinel"
  local before_state after_state report sentinel_hash checker_mode_before mode_upgrade_dir victim_hash victim_mode runner_pid runner_status marker attempt
  local install_inventory_before="$fixture_root/failed-install.before" install_inventory_after="$fixture_root/failed-install.after"
  local upgrade_inventory_before="$fixture_root/failed-upgrade.before" upgrade_inventory_after="$fixture_root/failed-upgrade.after"
  local swap_inventory_before="$fixture_root/source-swap.before" swap_inventory_after="$fixture_root/source-swap.after"
  local victim_inventory_before="$fixture_root/dest-victim.before" victim_inventory_after="$fixture_root/dest-victim.after"
  local after_rename_inventory_before="$fixture_root/after-rename.before" after_rename_inventory_after="$fixture_root/after-rename.after"

  mkdir -p "$valid_source" "$corrupt_source" "$failing_source" "$owned_source" "$evidence_source" "$runtime_source" "$bad_mode_source" "$bad_policy_source" "$hardlink_source" "$hardlink_upgrade_source" "$swap_source" "$dest_swap_source" "$dest_swap_upgrade_source" "$ancestor_swap_source" \
    "$corrupt_target" "$failed_install_target" "$failed_upgrade_target" \
    "$symlink_install_target" "$symlink_upgrade_target" "$owned_install_target" "$owned_upgrade_target" "$evidence_install_target" \
    "$mode_install_target" "$mode_upgrade_target" "$hardlink_target" "$hardlink_upgrade_target" "$swap_target" "$dest_swap_target" "$dest_swap_victim" \
    "$dest_swap_upgrade_target" "$dest_swap_upgrade_victim"
  mkdir -p "$ancestor_swap_target" "$ancestor_swap_victim"
  mkdir -p "$after_rename_fail_target" "$after_rename_replace_target"
  cp -pR "$release_root/." "$valid_source/"
  refresh_source_metadata "$valid_source"

  if [[ "$contract_scope" != "security" ]]; then
  cp -pR "$valid_source/." "$hardlink_source/"
  cp "$hardlink_source/P2T2C_README.md" "$source_hardlink_victim"
  rm -f "$hardlink_source/P2T2C_README.md"
  ln "$source_hardlink_victim" "$hardlink_source/P2T2C_README.md"
  refresh_source_metadata "$hardlink_source"
  victim_hash="$(sha256_file "$source_hardlink_victim")"; victim_mode="$(permission_mode "$source_hardlink_victim")"
  if bash "$hardlink_source/.p2t2c/bin/p2t2c_install.sh" --dry-run --target "$fixture_root/source-hardlink-target" >"$negative_log" 2>&1; then
    fail "$rel checksum-valid hardlinked source leaf was accepted"
  fi
  [[ "$(sha256_file "$source_hardlink_victim")" == "$victim_hash" && "$(permission_mode "$source_hardlink_victim")" == "$victim_mode" ]] \
    || fail "$rel rejected source hardlink changed its victim"

  mkdir -p "$hardlink_target/.p2t2c/bin"
  cp "$valid_source/.p2t2c/bin/check_p2t2c.sh" "$target_hardlink_victim"
  ln "$target_hardlink_victim" "$hardlink_target/.p2t2c/bin/check_p2t2c.sh"
  victim_hash="$(sha256_file "$target_hardlink_victim")"; victim_mode="$(permission_mode "$target_hardlink_victim")"
  if bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --dry-run --target "$hardlink_target" >"$negative_log" 2>&1; then
    fail "$rel hardlinked existing target leaf was accepted"
  fi
  [[ "$(sha256_file "$target_hardlink_victim")" == "$victim_hash" && "$(permission_mode "$target_hardlink_victim")" == "$victim_mode" ]] \
    || fail "$rel rejected target hardlink changed its victim"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$hardlink_upgrade_target" >/dev/null
  cp -pR "$valid_source/." "$hardlink_upgrade_source/"
  cp "$hardlink_upgrade_source/P2T2C_README.md" "$upgrade_source_hardlink_victim"
  rm -f "$hardlink_upgrade_source/P2T2C_README.md"
  ln "$upgrade_source_hardlink_victim" "$hardlink_upgrade_source/P2T2C_README.md"
  refresh_source_metadata "$hardlink_upgrade_source"
  victim_hash="$(sha256_file "$upgrade_source_hardlink_victim")"; victim_mode="$(permission_mode "$upgrade_source_hardlink_victim")"
  if (cd "$hardlink_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --dry-run --source "$hardlink_upgrade_source") >"$negative_log" 2>&1; then
    fail "$rel upgrade accepted a checksum-valid hardlinked source leaf"
  fi
  [[ "$(sha256_file "$upgrade_source_hardlink_victim")" == "$victim_hash" && "$(permission_mode "$upgrade_source_hardlink_victim")" == "$victim_mode" ]] \
    || fail "$rel rejected upgrade source hardlink changed its victim"

  cp "$hardlink_upgrade_target/.p2t2c/bin/p2t2c_run.sh" "$upgrade_target_hardlink_victim"
  rm -f "$hardlink_upgrade_target/.p2t2c/bin/p2t2c_run.sh"
  ln "$upgrade_target_hardlink_victim" "$hardlink_upgrade_target/.p2t2c/bin/p2t2c_run.sh"
  victim_hash="$(sha256_file "$upgrade_target_hardlink_victim")"; victim_mode="$(permission_mode "$upgrade_target_hardlink_victim")"
  if (cd "$hardlink_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --dry-run --source "$valid_source") >"$negative_log" 2>&1; then
    fail "$rel upgrade accepted a hardlinked existing target leaf"
  fi
  [[ "$(sha256_file "$upgrade_target_hardlink_victim")" == "$victim_hash" && "$(permission_mode "$upgrade_target_hardlink_victim")" == "$victim_mode" ]] \
    || fail "$rel rejected upgrade target hardlink changed its victim"

  cp -pR "$valid_source/." "$swap_source/"
  refresh_source_metadata "$swap_source"
  printf 'source-swap-target-sentinel\n' > "$swap_target/sentinel.txt"
  target_inventory "$swap_target" > "$swap_inventory_before"
  set +e
  P2T2C_TEST_PAUSE_AFTER_SOURCE_SNAPSHOT_REL="specs/README.md" P2T2C_TEST_PAUSE_MS=1000 \
    bash "$swap_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$swap_target" >"$fixture_root/source-swap.log" 2>&1 &
  runner_pid=$!
  set -e
  marker=""
  for attempt in $(seq 1 5000); do
    if grep -q 'P2T2C_TEST_MARKER:after_source_snapshot' "$fixture_root/source-swap.log" 2>/dev/null; then marker=paused; break; fi
    sleep 0.01
  done
  [[ -n "$marker" ]] || { wait "$runner_pid" 2>/dev/null || true; fail "$rel source-swap fixture did not observe the transaction marker"; }
  mv "$swap_source/specs/README.md" "$swap_source/specs/README.before-swap.md"
  printf '# swapped after checksum freeze\n' > "$swap_source/specs/README.md"
  chmod 0644 "$swap_source/specs/README.md"
  set +e; wait "$runner_pid"; runner_status=$?; set -e
  [[ "$runner_status" -ne 0 ]] || fail "$rel checksum-frozen source swap unexpectedly installed"
  grep -Eqi 'frozen source|source.*changed|identity|snapshot' "$fixture_root/source-swap.log" \
    || fail "$rel source swap failed for an unrelated reason"
  target_inventory "$swap_target" > "$swap_inventory_after"
  assert_target_inventory_equal "$swap_inventory_before" "$swap_inventory_after" "$rel checksum-frozen source swap"

  printf 'after-rename-failure-sentinel\n' > "$after_rename_fail_target/sentinel.txt"
  target_inventory "$after_rename_fail_target" > "$after_rename_inventory_before"
  if P2T2C_TEST_FAIL_AFTER_RENAME_REL=".p2t2c/CHECKSUMS.sha256" \
    bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$after_rename_fail_target" >"$fixture_root/after-rename-fail.log" 2>&1; then
    fail "$rel controlled after-rename failure unexpectedly installed"
  fi
  target_inventory "$after_rename_fail_target" > "$after_rename_inventory_after"
  assert_target_inventory_equal "$after_rename_inventory_before" "$after_rename_inventory_after" "$rel controlled after-rename failure"

  printf 'after-rename-replacement-sentinel\n' > "$after_rename_replace_target/sentinel.txt"
  target_inventory "$after_rename_replace_target" > "$after_rename_inventory_before"
  set +e
  P2T2C_TEST_PAUSE_AFTER_RENAME_REL=".p2t2c/CHECKSUMS.sha256" P2T2C_TEST_PAUSE_MS=1000 \
    bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$after_rename_replace_target" >"$fixture_root/after-rename-replace.log" 2>&1 &
  runner_pid=$!
  set -e
  marker=""
  for attempt in $(seq 1 5000); do
    if grep -q 'P2T2C_TEST_MARKER:after_rename' "$fixture_root/after-rename-replace.log" 2>/dev/null; then marker=paused; break; fi
    sleep 0.01
  done
  [[ -n "$marker" ]] || { wait "$runner_pid" 2>/dev/null || true; fail "$rel after-rename replacement fixture missed marker"; }
  rm -f "$after_rename_replace_target/.p2t2c/CHECKSUMS.sha256"
  printf 'replacement after atomic rename\n' > "$after_rename_replace_target/.p2t2c/CHECKSUMS.sha256"
  chmod 0644 "$after_rename_replace_target/.p2t2c/CHECKSUMS.sha256"
  set +e; wait "$runner_pid"; runner_status=$?; set -e
  [[ "$runner_status" -ne 0 ]] || fail "$rel after-rename replacement unexpectedly installed"
  target_inventory "$after_rename_replace_target" > "$after_rename_inventory_after"
  assert_target_inventory_equal "$after_rename_inventory_before" "$after_rename_inventory_after" "$rel after-rename replacement"

  cp -pR "$valid_source/." "$dest_swap_source/"
  refresh_source_metadata "$dest_swap_source"
  printf 'destination-victim-sentinel\n' > "$dest_swap_victim/sentinel.txt"
  target_inventory "$dest_swap_victim" > "$victim_inventory_before"
  set +e
  P2T2C_TEST_PAUSE_BEFORE_DEST_IDENTITY_REL="specs/README.md" P2T2C_TEST_PAUSE_MS=1000 \
    bash "$dest_swap_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$dest_swap_target" >"$fixture_root/dest-swap.log" 2>&1 &
  runner_pid=$!
  set -e
  marker=""
  for attempt in $(seq 1 5000); do
    if grep -q 'P2T2C_TEST_MARKER:before_dest_identity' "$fixture_root/dest-swap.log" 2>/dev/null; then marker=paused; break; fi
    sleep 0.005
  done
  [[ -n "$marker" ]] || { wait "$runner_pid" 2>/dev/null || true; fail "$rel destination-parent fixture did not observe specs parent"; }
  mv "$dest_swap_target/specs" "$dest_swap_parked"
  ln -s "$dest_swap_victim" "$dest_swap_target/specs"
  set +e; wait "$runner_pid"; runner_status=$?; set -e
  [[ "$runner_status" -ne 0 ]] || fail "$rel swapped destination parent unexpectedly installed"
  target_inventory "$dest_swap_victim" > "$victim_inventory_after"
  assert_target_inventory_equal "$victim_inventory_before" "$victim_inventory_after" "$rel destination-parent swap victim"
  [[ ! -e "$dest_swap_victim/README.md" ]] || fail "$rel destination-parent swap wrote through to victim"

  cp -pR "$valid_source/." "$ancestor_swap_source/"
  refresh_source_metadata "$ancestor_swap_source"
  printf 'ancestor-victim-sentinel\n' > "$ancestor_swap_victim/sentinel.txt"
  chmod 0640 "$ancestor_swap_victim/sentinel.txt"
  target_inventory "$ancestor_swap_victim" > "$victim_inventory_before"
  set +e
  P2T2C_TEST_PAUSE_BEFORE_DEST_IDENTITY_REL="docs/reference/README.md" P2T2C_TEST_PAUSE_MS=1000 \
    bash "$ancestor_swap_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$ancestor_swap_target" >"$fixture_root/ancestor-swap.log" 2>&1 &
  runner_pid=$!
  set -e
  marker=""
  for attempt in $(seq 1 5000); do
    if grep -q 'P2T2C_TEST_MARKER:before_dest_identity' "$fixture_root/ancestor-swap.log" 2>/dev/null; then marker=paused; break; fi
    sleep 0.005
  done
  [[ -n "$marker" ]] || { wait "$runner_pid" 2>/dev/null || true; fail "$rel ancestor-swap fixture did not observe docs/reference"; }
  mv "$ancestor_swap_target/docs" "$ancestor_swap_parked"
  ln -s "$ancestor_swap_victim" "$ancestor_swap_target/docs"
  set +e; wait "$runner_pid"; runner_status=$?; set -e
  [[ "$runner_status" -ne 0 ]] || fail "$rel swapped destination ancestor unexpectedly installed"
  target_inventory "$ancestor_swap_victim" > "$victim_inventory_after"
  assert_target_inventory_equal "$victim_inventory_before" "$victim_inventory_after" "$rel destination ancestor-swap victim"
  [[ ! -e "$ancestor_swap_victim/reference/README.md" ]] || fail "$rel destination ancestor swap wrote through to victim"
  rm -f "$ancestor_swap_target/docs"
  mv "$ancestor_swap_parked" "$ancestor_swap_target/docs"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$dest_swap_upgrade_target" >/dev/null
  cp -pR "$valid_source/." "$dest_swap_upgrade_source/"
  printf '\n# upgrade destination swap fixture\n' >> "$dest_swap_upgrade_source/specs/README.md"
  refresh_source_metadata "$dest_swap_upgrade_source"
  printf 'upgrade-destination-victim-sentinel\n' > "$dest_swap_upgrade_victim/sentinel.txt"
  chmod 0640 "$dest_swap_upgrade_victim/sentinel.txt"
  target_inventory "$dest_swap_upgrade_victim" > "$victim_inventory_before"
  set +e
  (cd "$dest_swap_upgrade_target" && P2T2C_TEST_PAUSE_BEFORE_DEST_IDENTITY_REL="specs/README.md" P2T2C_TEST_PAUSE_MS=1000 \
    bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$dest_swap_upgrade_source") >"$fixture_root/dest-swap-upgrade.log" 2>&1 &
  runner_pid=$!
  set -e
  marker=""
  for attempt in $(seq 1 5000); do
    if grep -q 'P2T2C_TEST_MARKER:before_dest_identity' "$fixture_root/dest-swap-upgrade.log" 2>/dev/null; then marker=paused; break; fi
    sleep 0.005
  done
  [[ -n "$marker" ]] || { wait "$runner_pid" 2>/dev/null || true; fail "$rel upgrade destination-parent fixture did not observe specs backup"; }
  mv "$dest_swap_upgrade_target/specs" "$dest_swap_upgrade_parked"
  ln -s "$dest_swap_upgrade_victim" "$dest_swap_upgrade_target/specs"
  set +e; wait "$runner_pid"; runner_status=$?; set -e
  [[ "$runner_status" -ne 0 ]] || fail "$rel swapped upgrade destination parent unexpectedly applied"
  target_inventory "$dest_swap_upgrade_victim" > "$victim_inventory_after"
  assert_target_inventory_equal "$victim_inventory_before" "$victim_inventory_after" "$rel upgrade destination-parent swap victim"
  [[ ! -e "$dest_swap_upgrade_victim/README.md" ]] || fail "$rel upgrade destination-parent swap wrote through to victim"
  rm -f "$dest_swap_upgrade_target/specs"
  mv "$dest_swap_upgrade_parked" "$dest_swap_upgrade_target/specs"

  cp -pR "$valid_source/." "$corrupt_source/"
  printf '\ncorrupt source fixture\n' >> "$corrupt_source/P2T2C_README.md"
  printf 'sentinel\n' > "$corrupt_target/sentinel.txt"
  if bash "$corrupt_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$corrupt_target" >"$negative_log" 2>&1; then
    fail "$rel corrupt source unexpectedly installed"
  fi
  [[ ! -e "$corrupt_target/.p2t2c/manifest.yaml" ]] || fail "$rel corrupt source wrote managed target state"
  [[ "$(cat "$corrupt_target/sentinel.txt")" == "sentinel" ]] || fail "$rel corrupt source changed pre-existing target state"

  cp -pR "$valid_source/." "$failing_source/"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$failing_source/.p2t2c/bin/check_p2t2c.sh"
  chmod 0755 "$failing_source/.p2t2c/bin/check_p2t2c.sh"
  refresh_source_metadata "$failing_source"
  mkdir -p "$failed_install_target/.p2t2c/bin"
  cp "$failing_source/.p2t2c/bin/check_p2t2c.sh" "$failed_install_target/.p2t2c/bin/check_p2t2c.sh"
  chmod 0644 "$failed_install_target/.p2t2c/bin/check_p2t2c.sh"
  target_inventory "$failed_install_target" > "$install_inventory_before"
  if bash "$failing_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$failed_install_target" >"$negative_log" 2>&1; then
    fail "$rel permanently failing checker install unexpectedly succeeded"
  fi
  [[ ! -e "$failed_install_target/.p2t2c/manifest.yaml" ]] || fail "$rel failed install retained managed files"
  [[ ! -e "$failed_install_target/.p2t2c/project_config.yaml" ]] || fail "$rel failed install retained project configuration"
  [[ ! -e "$failed_install_target/.p2t2c/lock.sha256" ]] || fail "$rel failed install retained a generated lock"
  [[ -f "$failed_install_target/.p2t2c/bin/check_p2t2c.sh" && "$(permission_mode "$failed_install_target/.p2t2c/bin/check_p2t2c.sh")" == "0644" ]] \
    || fail "$rel failed install did not restore a pre-existing mode-only target"
  target_inventory "$failed_install_target" > "$install_inventory_after"
  assert_target_inventory_equal "$install_inventory_before" "$install_inventory_after" "$rel late install failure"
  report="$(find "$failed_install_target/.p2t2c/install" -type f -name install-report.md | head -n 1)"
  grep -q '^Status: FAILED_ROLLED_BACK$' "$report" || fail "$rel failed install report is not FAILED_ROLLED_BACK"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$failed_upgrade_target" >/dev/null
  before_state="$(managed_state_digest "$failed_upgrade_target")"
  checker_mode_before="$(permission_mode "$failed_upgrade_target/.p2t2c/bin/check_p2t2c.sh")"
  if (cd "$failed_upgrade_target" && bash "$corrupt_source/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$corrupt_source") >"$negative_log" 2>&1; then
    fail "$rel corrupt source upgrade unexpectedly succeeded"
  fi
  after_state="$(managed_state_digest "$failed_upgrade_target")"
  [[ "$before_state" == "$after_state" ]] || fail "$rel corrupt source upgrade changed target state before checksum rejection"
  target_inventory "$failed_upgrade_target" > "$upgrade_inventory_before"
  if (cd "$failed_upgrade_target" && bash "$failing_source/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$failing_source") >"$negative_log" 2>&1; then
    fail "$rel permanently failing checker upgrade unexpectedly succeeded"
  fi
  after_state="$(managed_state_digest "$failed_upgrade_target")"
  [[ "$before_state" == "$after_state" ]] || fail "$rel failed upgrade did not restore the pre-apply managed state"
  [[ "$(permission_mode "$failed_upgrade_target/.p2t2c/bin/check_p2t2c.sh")" == "$checker_mode_before" ]] \
    || fail "$rel failed upgrade did not restore checker permission bits"
  target_inventory "$failed_upgrade_target" > "$upgrade_inventory_after"
  assert_target_inventory_equal "$upgrade_inventory_before" "$upgrade_inventory_after" "$rel late upgrade failure"
  report="$(find "$failed_upgrade_target/.p2t2c/upgrade" -type f -name upgrade-report.md | LC_ALL=C sort | awk 'END {print}')"
  grep -q '^Status: FAILED_ROLLED_BACK$' "$report" || fail "$rel failed upgrade report is not FAILED_ROLLED_BACK"

  cp -pR "$valid_source/." "$bad_mode_source/"
  chmod 0644 "$bad_mode_source/.p2t2c/bin/check_p2t2c.sh"
  refresh_source_metadata "$bad_mode_source"
  if bash "$bad_mode_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$fixture_root/bad-mode-target" >"$negative_log" 2>&1; then
    fail "$rel install accepted a checksum-valid source with wrong managed mode"
  fi
  grep -Eqi 'mode|0755|0644' "$negative_log" || fail "$rel bad source mode failed for an unrelated reason"

  cp -pR "$valid_source/." "$bad_policy_source/"
  perl -0pi -e 's/^default 0644$/default 0777/m' "$bad_policy_source/.p2t2c/managed-modes.txt"
  refresh_source_metadata "$bad_policy_source"
  if bash "$bad_policy_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$fixture_root/bad-policy-target" >"$negative_log" 2>&1; then
    fail "$rel install accepted an unsafe checksum-valid managed-mode policy"
  fi
  grep -Eqi 'mode|0644|0755' "$negative_log" || fail "$rel bad mode policy failed for an unrelated reason"

  mkdir -p "$mode_install_target/.p2t2c/bin"
  cp "$valid_source/.p2t2c/bin/check_p2t2c.sh" "$mode_install_target/.p2t2c/bin/check_p2t2c.sh"
  chmod 0644 "$mode_install_target/.p2t2c/bin/check_p2t2c.sh"
  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$mode_install_target" >/dev/null
  [[ "$(permission_mode "$mode_install_target/.p2t2c/bin/check_p2t2c.sh")" == "0755" ]] \
    || fail "$rel fresh install did not repair identical-byte mode drift"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$mode_upgrade_target" >/dev/null
  chmod 0644 "$mode_upgrade_target/.p2t2c/bin/p2t2c_run.sh"
  (cd "$mode_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$valid_source") >/dev/null
  [[ "$(permission_mode "$mode_upgrade_target/.p2t2c/bin/p2t2c_run.sh")" == "0755" ]] \
    || fail "$rel upgrade did not repair identical-byte mode drift"
  mode_upgrade_dir="$(find "$mode_upgrade_target/.p2t2c/upgrade" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | awk 'END {print}')"
  (cd "$mode_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback "$mode_upgrade_dir") >/dev/null
  [[ "$(permission_mode "$mode_upgrade_target/.p2t2c/bin/p2t2c_run.sh")" == "0644" ]] \
    || fail "$rel mode-only upgrade rollback did not restore the original mode"
  fi

  if [[ "$contract_scope" != "transaction" ]]; then
  ln -s "$install_victim" "$symlink_install_target/P2T2C_README.md"
  if bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$symlink_install_target" >"$negative_log" 2>&1; then
    fail "$rel install accepted a broken managed-file symlink"
  fi
  [[ ! -e "$install_victim" && ! -L "$install_victim" ]] || fail "$rel broken install symlink created its outside victim"
  [[ ! -e "$symlink_install_target/.p2t2c/manifest.yaml" ]] || fail "$rel broken install symlink wrote managed target state"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$symlink_upgrade_target" >/dev/null
  cp "$symlink_upgrade_target/P2T2C_README.md" "$upgrade_sentinel"
  sentinel_hash="$(sha256_file "$upgrade_sentinel")"
  rm -f "$symlink_upgrade_target/P2T2C_README.md"
  ln -s "$upgrade_sentinel" "$symlink_upgrade_target/P2T2C_README.md"
  if (cd "$symlink_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$valid_source") >"$negative_log" 2>&1; then
    fail "$rel upgrade accepted a lock-matching live managed-file symlink"
  fi
  [[ "$(sha256_file "$upgrade_sentinel")" == "$sentinel_hash" ]] || fail "$rel rejected upgrade changed its outside symlink sentinel"

  cp -pR "$valid_source/." "$owned_source/"
  mkdir -p "$owned_source/docs/sot/product"
  printf '# Project-owned manifest injection fixture\n' > "$owned_source/docs/sot/product/INJECTED.md"
  printf '%s\n' 'docs/sot/product/INJECTED.md' >> "$owned_source/.p2t2c/managed-files.txt"
  refresh_source_metadata "$owned_source"
  printf 'sentinel\n' > "$owned_install_target/sentinel.txt"
  if bash "$owned_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$owned_install_target" >"$negative_log" 2>&1; then
    fail "$rel install accepted a checksum-valid project-owned managed path"
  fi
  [[ ! -e "$owned_install_target/.p2t2c/manifest.yaml" ]] || fail "$rel project-owned install injection wrote managed state"
  [[ "$(cat "$owned_install_target/sentinel.txt")" == "sentinel" ]] || fail "$rel project-owned install injection changed target state"

  bash "$valid_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$owned_upgrade_target" >/dev/null
  before_state="$(managed_state_digest "$owned_upgrade_target")"
  if (cd "$owned_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$owned_source") >"$negative_log" 2>&1; then
    fail "$rel upgrade accepted a checksum-valid project-owned managed path"
  fi
  after_state="$(managed_state_digest "$owned_upgrade_target")"
  [[ "$before_state" == "$after_state" ]] || fail "$rel project-owned upgrade injection changed target state"

  cp -pR "$valid_source/." "$evidence_source/"
  mkdir -p "$evidence_source/docs/closure/evidence"
  printf '{"injected":true}\n' > "$evidence_source/docs/closure/evidence/EV-injected-0000000000000000000000000000000000000000000000000000000000000000.jsonl"
  printf '%s\n' 'docs/closure/evidence/EV-injected-0000000000000000000000000000000000000000000000000000000000000000.jsonl' >> "$evidence_source/.p2t2c/managed-files.txt"
  refresh_source_metadata "$evidence_source"
  if bash "$evidence_source/.p2t2c/bin/p2t2c_install.sh" --apply --target "$evidence_install_target" >"$negative_log" 2>&1; then
    fail "$rel install accepted a project-owned evidence sidecar"
  fi
  [[ ! -e "$evidence_install_target/docs/closure/evidence/EV-injected-0000000000000000000000000000000000000000000000000000000000000000.jsonl" ]] \
    || fail "$rel evidence-sidecar injection wrote project-owned evidence"

  cp -pR "$valid_source/." "$runtime_source/"
  mkdir -p "$runtime_source/.p2t2c/cache"
  printf 'injected cache\n' > "$runtime_source/.p2t2c/cache/injected.json"
  printf '%s\n' '.p2t2c/cache/injected.json' >> "$runtime_source/.p2t2c/managed-files.txt"
  refresh_source_metadata "$runtime_source"
  before_state="$(managed_state_digest "$owned_upgrade_target")"
  if (cd "$owned_upgrade_target" && bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$runtime_source") >"$negative_log" 2>&1; then
    fail "$rel upgrade accepted a release-managed runtime cache path"
  fi
  after_state="$(managed_state_digest "$owned_upgrade_target")"
  [[ "$before_state" == "$after_state" ]] || fail "$rel runtime-cache injection changed target state"
  fi
}

expect_checker_failure() {
  local target="$1" label="$2"
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >"$negative_log" 2>&1); then
    fail "$label unexpectedly passed governance checks"
  fi
}

expect_close_failure() {
  local target="$1" work_id="$2" label="$3" profile="${4:-impacted}" remaining="${5:-none}" risk_ref="${6:-none}"
  if (cd "$target" && bash .p2t2c/bin/p2t2c_close.sh \
    --work-id "$work_id" --verification-profile "$profile" --remaining-risk-status "$remaining" \
    --remaining-risk-ref "$risk_ref" >"$negative_log" 2>&1)
  then
    fail "$label unexpectedly closed"
  fi
}

create_historical_v2_samples() {
  local target="$1"

  mkdir -p "$target/specs/900-historical-v2"
  cat > "$target/docs/change_packs/CPK-20260710-historical-v2.md" <<'EOF'
---
artifact: change_pack
schema_version: 2
id: CPK-20260710-historical-v2
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: applied
---
# Historical schema v2 CPK
EOF
  cat > "$target/specs/900-historical-v2/spec.md" <<'EOF'
---
artifact: execution_spec
change_pack: docs/change_packs/CPK-20260710-historical-v2.md
---
# Historical schema v2 spec
EOF
  printf '# Historical schema v2 plan\n' > "$target/specs/900-historical-v2/plan.md"
  printf '# Historical schema v2 tasks\n' > "$target/specs/900-historical-v2/tasks.md"
  cat > "$target/docs/closure/CR-20260710-historical-v2.md" <<'EOF'
---
artifact: closure_report
schema_version: 2
id: CR-20260710-historical-v2
risk: R1
change_pack: docs/change_packs/CPK-20260710-historical-v2.md
execution_pack: specs/900-historical-v2
truth_drift: none
decision: CLOSE
verification_policy: fresh_pass
---
# Historical schema v2 closure

## Verification Evidence

| Actual command or step | Result | Notes or reason not run |
|---|---|---|
| `bash .p2t2c/bin/check_p2t2c.sh` | Pass | Historical fixture retained without migration |

## Remaining Risks

- None
EOF
}

create_v3_routing_samples() {
  local target="$1"

  cat > "$target/docs/change_packs/CPK-20260826-spike-ready.md" <<'EOF'
---
artifact: change_pack
schema_version: 3
id: CPK-20260826-spike-ready
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: spike
production_code_change: false
multi_agent: false
work_pack: none
implementer: root-controller
tdd_policy: not_applicable
governance_change: false
specialist_review_required: false
truth_patch_ref: none
truth_patch_digest: none
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: none
legacy_startup_evidence: false
---
# Spike routing fixture

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->
EOF

  mkdir -p "$target/specs/901-architectural-ready"
  cat > "$target/docs/change_packs/CPK-20260826-architectural-ready.md" <<'EOF'
---
artifact: change_pack
schema_version: 3
id: CPK-20260826-architectural-ready
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: architectural
production_code_change: false
multi_agent: false
work_pack: specs/901-architectural-ready/work.md
implementer: root-controller
tdd_policy: not_applicable
governance_change: false
specialist_review_required: false
truth_patch_ref: none
truth_patch_digest: none
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: READY-A,READY-B
legacy_startup_evidence: false
---
# Architectural routing fixture

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->
EOF
  cat > "$target/specs/901-architectural-ready/work.md" <<'EOF'
---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/CPK-20260826-architectural-ready.md
---
# Architectural work fixture
EOF
}

check_invalid_v3_contract() {
  local target="$1" invalid
  invalid="$target/docs/change_packs/CPK-20260826-invalid-shape.md"

  cat > "$invalid" <<'EOF'
---
artifact: change_pack
schema_version: 3
id: CPK-20260826-invalid-shape
risk: R1
source: user_instruction
truth_change: false
gate_a: not_required
status: ready
methodology_profile: p2t2c-adaptive-v2
execution_shape: unbounded
production_code_change: false
multi_agent: false
work_pack: none
implementer: root-controller
tdd_policy: not_applicable
governance_change: false
specialist_review_required: false
truth_patch_ref: none
truth_patch_digest: none
gate_b_status: not_triggered
gate_b_decision: none
gate_b_ref: none
ownership_batches: none
legacy_startup_evidence: false
---
# Invalid v3 fixture

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->
EOF
  expect_checker_failure "$target" "invalid v3 execution_shape"
  rm -f "$invalid"

  write_cpk "$target" CPK-quoted-schema R1 bounded ready false false none not_applicable false false none not_triggered none none
  perl -0pi -e 's/schema_version: 3/schema_version: "3"/' "$target/docs/change_packs/CPK-quoted-schema.md"
  expect_checker_failure "$target" "quoted v3 schema_version"
  rm -f "$target/docs/change_packs/CPK-quoted-schema.md"
}

check_artifact_matrix_contracts() {
  local target="$1" id="CPK-bounded-legacy-forbidden" pack
  pack="$target/specs/903-bounded-forbidden"
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  mkdir -p "$pack"
  cat > "$pack/spec.md" <<EOF
---
artifact: execution_spec
change_pack: docs/change_packs/$id.md
---
# Forbidden bounded legacy spec
EOF
  printf '# forbidden plan\n' > "$pack/plan.md"
  printf '# forbidden tasks\n' > "$pack/tasks.md"
  expect_checker_failure "$target" "bounded v3 legacy execution trio"
  rm -f "$pack/spec.md" "$pack/plan.md" "$pack/tasks.md" "$target/docs/change_packs/$id.md"
  rmdir "$pack"

  id="CPK-architectural-legacy-allowed"
  write_work "$target" "$id" specs/904-architectural-legacy
  write_cpk "$target" "$id" R1 architectural ready false false specs/904-architectural-legacy/work.md \
    not_applicable false false none not_triggered none none LEGACY-A true
  cat > "$target/specs/904-architectural-legacy/spec.md" <<EOF
---
artifact: execution_spec
change_pack: docs/change_packs/$id.md
---
# Allowed architectural startup spec
EOF
  printf '# startup plan\n' > "$target/specs/904-architectural-legacy/plan.md"
  printf '# startup tasks\n' > "$target/specs/904-architectural-legacy/tasks.md"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
}

check_truth_hash_contract() {
  local target="$1" id="CPK-truth-hash" truth_ref="docs/sot/product/TRUTH_HASH_SMOKE.md" original
  mkdir -p "$target/docs/sot/product"
  printf '# Truth hash fixture\n' > "$target/$truth_ref"
  original="$(cat "$target/$truth_ref")"
  write_cpk "$target" "$id" R2 bounded ready false false none not_applicable true false \
    "$truth_ref" not_triggered none none
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
  printf '\nchanged after digest\n' >> "$target/$truth_ref"
  expect_checker_failure "$target" "stale R2 Truth Patch digest"
  printf '%s\n' "$original" > "$target/$truth_ref"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
  rm -f "$target/docs/change_packs/$id.md" "$target/$truth_ref"
}

initialize_fixture_git() {
  local target="$1"
  git -C "$target" init -q
  git -C "$target" config user.name "P2T2C Smoke"
  git -C "$target" config user.email "p2t2c-smoke@example.invalid"
  git -C "$target" add -A
  git -C "$target" commit -q -m "fixture baseline"
}

checkpoint_fixture_git() {
  local target="$1" label="$2"
  git -C "$target" add -A
  git -C "$target" commit -q --allow-empty -m "fixture checkpoint: $label"
}

digest_value() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

write_cpk() {
  local target="$1" id="$2" risk="$3" shape="$4" status="$5"
  local production="$6" multi="$7" work_pack="$8" tdd_policy="$9"
  local governance="${10}" specialist="${11}" truth_patch="${12}"
  local gate_b_status="${13}" gate_b_decision="${14}" gate_b_ref="${15}"
  local ownership="${16:-}" legacy_startup="${17:-false}" gate_override="${18:-}"
  local truth_change gate_a truth_patch_digest
  if [[ -z "$ownership" ]]; then
    if [[ "$shape" == "architectural" ]]; then ownership="BATCH-A,BATCH-B"; else ownership="none"; fi
  fi
  if [[ "$risk" == "R1" ]]; then
    truth_change="false"
    gate_a="not_required"
    truth_patch_digest="none"
  else
    truth_change="true"
    gate_a="${gate_override:-satisfied}"
    [[ -f "$target/$truth_patch" ]] || fail "$id R2 Truth Patch fixture is missing: $truth_patch"
    truth_patch_digest="$(sha256_file "$target/$truth_patch")"
  fi
  cat > "$target/docs/change_packs/$id.md" <<EOF
---
artifact: change_pack
schema_version: 3
id: $id
risk: $risk
source: user_instruction
truth_change: $truth_change
gate_a: $gate_a
status: $status
methodology_profile: p2t2c-adaptive-v2
execution_shape: $shape
production_code_change: $production
multi_agent: $multi
work_pack: $work_pack
implementer: root-controller
tdd_policy: $tdd_policy
governance_change: $governance
specialist_review_required: $specialist
truth_patch_ref: $truth_patch
truth_patch_digest: $truth_patch_digest
gate_b_status: $gate_b_status
gate_b_decision: $gate_b_decision
gate_b_ref: $gate_b_ref
ownership_batches: $ownership
legacy_startup_evidence: $legacy_startup
---
# $id smoke fixture

<!-- p2t2c:evidence:start -->
<!-- p2t2c:evidence:end -->
EOF
}

write_work() {
  local target="$1" id="$2" pack_dir="$3"
  mkdir -p "$target/$pack_dir"
  cat > "$target/$pack_dir/work.md" <<EOF
---
artifact: execution_work
schema_version: 1
change_pack: docs/change_packs/$id.md
---
# $id architectural work fixture
EOF
}

record_route() {
  local target="$1" id="$2" from_risk="$3" to_risk="$4" from_shape="$5" to_shape="$6"
  local contract_status contract_shape
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type route \
    --from-risk "$from_risk" --to-risk "$to_risk" --from-shape "$from_shape" --to-shape "$to_shape")
  if [[ -f "$target/docs/change_packs/$id.md" ]]; then
    contract_status="$(awk '/^status: / { print $2; exit }' "$target/docs/change_packs/$id.md")"
    contract_shape="$(awk '/^execution_shape: / { print $2; exit }' "$target/docs/change_packs/$id.md")"
    if [[ "$contract_status" != "blocked" && "$contract_shape" != "spike" ]]; then
      mkdir -p "$target/src"
      printf '%s governed work output\n' "$id" > "$target/src/$id.txt"
    fi
  fi
}

record_verification() {
  local target="$1" id="$2" profile="$3"
  record_isolation "$target" "$id"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type verification \
    --verification-profile "$profile" --command-id p2t2c-check)
}

record_tdd_exemption() {
  local target="$1" id="$2"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type tdd_exemption \
    --reason-digest "$(digest_value "$id-tdd-exemption")")
}

record_tdd_required() {
  local target="$1" id="$2"
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type tdd_red \
    --command-label smoke-red -- bash -c 'exit 1') >"$negative_log" 2>&1
  then
    fail "$id RED command unexpectedly passed"
  fi
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type tdd_green \
    --command-label smoke-green -- bash -c 'exit 0')
}

record_isolation() {
  local target="$1" id="$2" baseline
  baseline="$(git -C "$target" rev-parse HEAD)"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type isolation \
    --workspace-kind shared_owned --branch smoke-fixture --baseline-sha "$baseline" --clean true)
}

record_repair() {
  local target="$1" id="$2" round="$3" head fix_digest failure_digest
  head="$(git -C "$target" rev-parse HEAD)"
  fix_digest="$(git -C "$target" diff --binary "$head" "$head" | shasum -a 256 | awk '{print $1}')"
  failure_digest="$(digest_value "$id-failure-$round")"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type repair \
    --repair-round "$round" --hypothesis-digest "$(digest_value "$id-repair-$round")" \
    --implementer root-controller --failure-digest "$failure_digest" \
    --fix-base-sha "$head" --fix-head-sha "$head" --fix-diff-digest "$fix_digest")
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type review \
    --implementer root-controller --reviewer "repair-reviewer-$round" --reviewer-session "repair-session-$round" \
    --review-role re_review --scope-digest "$fix_digest" --base-sha "$head" \
    --verdict pass --critical 0 --important 0 --minor 0)
}

record_gate_b() {
  local target="$1" id="$2" decision="$3" ref="$4"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type gate_b \
    --gate-b-decision "$decision" --gate-b-ref "$ref")
}

record_review() {
  local target="$1" id="$2" role="$3" reviewer="$4" session="$5" minor="$6" batch_id="${7:-}"
  local baseline args
  baseline="$(git -C "$target" rev-parse HEAD)"
  args=(bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type review \
    --implementer root-controller --reviewer "$reviewer" --reviewer-session "$session" \
    --review-role "$role" --scope-digest "$(digest_value "$id-$role-scope")" \
    --base-sha "$baseline" --verdict pass --critical 0 --important 0 --minor "$minor")
  [[ -z "$batch_id" ]] || args+=(--batch-id "$batch_id")
  (cd "$target" && "${args[@]}")
}

close_work() {
  local target="$1" id="$2" profile="$3" remaining="${4:-none}" risk_ref="${5:-none}"
  (cd "$target" && bash .p2t2c/bin/p2t2c_close.sh --work-id "$id" \
    --verification-profile "$profile" --remaining-risk-status "$remaining" --remaining-risk-ref "$risk_ref")
}

assert_receipt_v2_pair() {
  local target="$1" artifact="$2" id="$3"
  (cd "$target" && perl -Mstrict -Mwarnings -MJSON::PP -MDigest::SHA=sha256_hex -e '
    my ($artifact,$work)=@ARGV;
    open my $af,"<:raw",$artifact or die "cannot read $artifact: $!\n"; local $/; my $raw=<$af>//""; close $af;
    die "artifact contains raw event records\n" if $raw=~/"event_type"/;
    my @blocks=$raw=~/<!-- p2t2c:evidence:start -->\s*```jsonl\s*(.*?)\s*```\s*<!-- p2t2c:evidence:end -->/sg;
    die "artifact must contain exactly one receipt marker block\n" if @blocks!=1;
    my @lines=grep {length} split /\r?\n/,$blocks[0];
    die "receipt marker must contain exactly one JSON value\n" if @lines!=1;
    my $payload=$lines[0]; my $bytes=length($payload);
    die "receipt payload must be below 3072 bytes\n" if $bytes>=3072;
    my $receipt=eval {JSON::PP->new->utf8(1)->decode($payload)};
    die "receipt payload is not one JSON object\n" if $@||ref($receipt) ne "HASH";
    die "receipt is not closure v2 sidecar proof\n" unless ($receipt->{schema_version}//0)==2&&($receipt->{receipt_type}//"") eq "closure"&&($receipt->{evidence_storage}//"") eq "sidecar_jsonl";
    my $ref=$receipt->{evidence_ref}//""; my $digest=$receipt->{source_digest}//"";
    die "unsafe or non-content-addressed evidence_ref\n" unless $digest=~/\A[0-9a-f]{64}\z/&&$ref eq "docs/closure/evidence/EV-$work-$digest.jsonl";
    my @st=lstat($ref); die "sidecar must be a single-link regular file\n" if !@st||-l _||!-f _||$st[3]!=1;
    open my $sf,"<:raw",$ref or die "cannot read $ref: $!\n"; local $/; my $side=<$sf>//""; close $sf;
    die "sidecar digest mismatch\n" if sha256_hex($side) ne $digest;
    my @events=grep {length} split /\r?\n/,$side;
    die "sidecar event_count mismatch\n" if @events!=($receipt->{event_count}//-1);
    for my $event (@events) {my $o=eval {JSON::PP->new->utf8(1)->decode($event)};die "sidecar contains malformed event JSON\n" if $@||ref($o) ne "HASH"}
    print "receipt_payload_bytes=$bytes event_count=",scalar(@events)," evidence_ref=$ref\n";
  ' "$artifact" "$id")
}

run_r0_contracts() {
  local target="$1" config="$1/.p2t2c/project_config.yaml"

  if ! grep -q '^p2t2c:' "$config"; then
    cat >> "$config" <<'EOF'

p2t2c:
  default_mode: "risk_routed"
  r0:
    audit_mode: false
    closure_on_residual_risk: true
  autonomous_repair:
    same_failure_fix_rounds: 2
    environment_retry_count: 1
EOF
    checkpoint_fixture_git "$target" r0-policy-overlay
  fi

  perl -0pi -e 's/audit_mode: false/audit_mode: true/' "$config"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id R0-audit --event-type route \
    --risk R0 --execution-shape bounded --implementer root-controller --tdd-policy not_applicable \
    --from-risk R0 --to-risk R0 --from-shape bounded --to-shape bounded)
  record_verification "$target" R0-audit fast
  record_verification "$target" R0-audit governance
  expect_close_failure "$target" R0-audit "R0 recorded risk without reference" fast recorded none
  close_work "$target" R0-audit fast none
  [[ -f "$target/docs/closure/CR-audit.md" ]] || fail "R0 audit did not create a minimal CR"

  perl -0pi -e 's/audit_mode: true/audit_mode: false/' "$config"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id R0-residual --event-type route \
    --risk R0 --execution-shape bounded --implementer root-controller --tdd-policy not_applicable \
    --from-risk R0 --to-risk R0 --from-shape bounded --to-shape bounded)
  record_verification "$target" R0-residual impacted
  expect_close_failure "$target" R0-residual "R0 recorded risk without reference" impacted recorded none
  close_work "$target" R0-residual impacted recorded RISK-R0-residual
  [[ -f "$target/docs/closure/CR-residual.md" ]] || fail "R0 residual risk did not create a minimal CR"
  grep -q '^remaining_risk_status: recorded$' "$target/docs/closure/CR-residual.md" || fail "R0 residual risk status was not projected"
  grep -q '^remaining_risk_ref: RISK-R0-residual$' "$target/docs/closure/CR-residual.md" || fail "R0 residual risk reference was not projected"

  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id R0-policy-noaudit --event-type route \
    --risk R0 --execution-shape bounded --implementer root-controller --tdd-policy not_applicable \
    --from-risk R0 --to-risk R0 --from-shape bounded --to-shape bounded)
  record_verification "$target" R0-policy-noaudit impacted
  expect_close_failure "$target" R0-policy-noaudit "R0 unaudited closure" impacted none none

  perl -0pi -e 's/closure_on_residual_risk: true/closure_on_residual_risk: false/' "$config"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id R0-policy-disabled --event-type route \
    --risk R0 --execution-shape bounded --implementer root-controller --tdd-policy not_applicable \
    --from-risk R0 --to-risk R0 --from-shape bounded --to-shape bounded)
  record_verification "$target" R0-policy-disabled impacted
  expect_close_failure "$target" R0-policy-disabled "R0 disabled residual-risk closure" impacted recorded RISK-disabled
  perl -0pi -e 's/closure_on_residual_risk: false/closure_on_residual_risk: true/' "$config"
  [[ ! -e "$target/docs/change_packs/R0-audit.md" && ! -e "$target/docs/change_packs/R0-residual.md" ]] || fail "R0 audit created a CPK"
}

run_gate_a_exploration_contract() {
  local target="$1" id="CPK-gate-a-pending" truth_ref="docs/sot/product/GATE_A_PENDING_SMOKE.md"
  mkdir -p "$target/docs/sot/product"
  printf '# Pending Gate A Truth reference\n' > "$target/$truth_ref"
  write_cpk "$target" "$id" R2 bounded blocked false false none not_applicable true false \
    "$truth_ref" not_triggered none none none false pending
  record_route "$target" "$id" R1 R2 bounded bounded
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type exploration \
    --command-label gate-a-readonly -- bash -c 'exit 0')
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type verification \
    --verification-profile impacted --command-id p2t2c-check) >"$negative_log" 2>&1
  then
    fail "Gate A pending accepted verification"
  fi
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type exploration \
    --command-label gate-a-write -- bash -c 'printf write > gate-a-write.txt') >"$negative_log" 2>&1
  then
    fail "Gate A exploration accepted a governed tree write"
  fi
  rm -f "$target/gate-a-write.txt"
  expect_close_failure "$target" "$id" "Gate A pending closure" full
  [[ ! -e "$target/docs/closure/CR-gate-a-pending.md" ]] || fail "Gate A pending created a CR"
  rm -f "$target/.p2t2c/runs/$id/events.jsonl" "$target/.p2t2c/runs/$id/contract.json"
  rmdir "$target/.p2t2c/runs/$id"
  rm -f "$target/docs/change_packs/$id.md" "$target/$truth_ref"
}

run_spike_and_route_contracts() {
  local target="$1"

  write_cpk "$target" CPK-spike-close R1 spike ready false false none not_applicable false false none not_triggered none none
  record_route "$target" CPK-spike-close R1 R1 spike spike
  record_verification "$target" CPK-spike-close fast
  expect_close_failure "$target" CPK-spike-close "spike delivery" fast

  write_cpk "$target" CPK-route-downgrade R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" CPK-route-downgrade R2 R1 architectural bounded
  expect_close_failure "$target" CPK-route-downgrade "risk/shape downgrade" fast

  write_cpk "$target" CPK-route-upgrade R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" CPK-route-upgrade R0 R1 spike bounded
  record_verification "$target" CPK-route-upgrade impacted
  close_work "$target" CPK-route-upgrade impacted

  write_cpk "$target" CPK-path-downgrade R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" CPK-path-downgrade R1 R1 bounded bounded
  mkdir -p "$target/src"
  printf 'path mapping downgrade fixture\n' > "$target/src/path-downgrade.txt"
  record_verification "$target" CPK-path-downgrade fast
  expect_close_failure "$target" CPK-path-downgrade "path-mapped profile downgrade" fast
}

run_tdd_and_contract_binding() {
  local target="$1" id backup ledger

  id="CPK-tdd-required"
  write_cpk "$target" "$id" R1 bounded ready false false none required false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_tdd_required "$target" "$id"
  record_verification "$target" "$id" impacted
  close_work "$target" "$id" impacted

  id="CPK-contract-binding"
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_verification "$target" "$id" impacted
  ledger="$target/.p2t2c/runs/$id/events.jsonl"
  printf '{malformed ledger fixture\n' >> "$ledger"
  expect_close_failure "$target" "$id" "malformed JSONL ledger" impacted
  sed '$d' "$ledger" > "$ledger.repaired"
  chmod 600 "$ledger.repaired"
  mv "$ledger.repaired" "$ledger"

  backup="$tmp_root/$id.backup"
  cp "$target/docs/change_packs/$id.md" "$backup"
  printf '\ncontract tamper\n' >> "$target/docs/change_packs/$id.md"
  expect_close_failure "$target" "$id" "post-verification CPK contract tamper" impacted
  cp "$backup" "$target/docs/change_packs/$id.md"

  mkdir -p "$target/src"
  printf 'stale tree fixture\n' > "$target/src/stale-tree.txt"
  expect_close_failure "$target" "$id" "stale final tree" impacted
  rm -f "$target/src/stale-tree.txt"
  rmdir "$target/src" 2>/dev/null || true
  close_work "$target" "$id" impacted
}

run_advisory_required_contracts() {
  local target="$1" id cpk

  id="CPK-advisory-incomplete"
  write_cpk "$target" "$id" R1 bounded ready false false none required false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_verification "$target" "$id" impacted
  close_work "$target" "$id" impacted
  cpk="$target/docs/change_packs/$id.md"
  grep -q '"methodology_enforcement":"advisory"' "$cpk" || fail "advisory enforcement was not projected"
  grep -q '"evidence_completeness":"advisory_incomplete"' "$cpk" || fail "advisory method gap was not marked incomplete"
  grep -q 'MISSING_TDD_RED_GREEN' "$cpk" || fail "advisory TDD warning was not projected"

  perl -0pi -e 's/enforcement: "advisory"/enforcement: "required"/' "$target/.p2t2c/project_config.yaml"
  id="CPK-required-incomplete"
  write_cpk "$target" "$id" R1 bounded ready false false none required false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_verification "$target" "$id" impacted
  record_verification "$target" "$id" governance
  expect_close_failure "$target" "$id" "required method incompleteness" impacted
  perl -0pi -e 's/enforcement: "required"/enforcement: "advisory"/' "$target/.p2t2c/project_config.yaml"
}

run_review_contracts() {
  local target="$1" id

  id="CPK-independent-review"
  write_cpk "$target" "$id" R1 bounded ready true false none exempt false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_tdd_exemption "$target" "$id"
  record_verification "$target" "$id" impacted
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type review \
    --implementer root-controller --reviewer root-controller --reviewer-session same-session \
    --review-role global --scope-digest "$(digest_value same-scope)" \
    --base-sha "$(git -C "$target" rev-parse HEAD)" --verdict pass --critical 0 --important 0 --minor 0) >"$negative_log" 2>&1
  then
    fail "same implementer/reviewer was accepted"
  fi
  record_review "$target" "$id" global independent-global global-session 0
  close_work "$target" "$id" impacted

  id="CPK-minor-finding"
  write_cpk "$target" "$id" R1 bounded ready true false none exempt false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_tdd_exemption "$target" "$id"
  record_verification "$target" "$id" impacted
  record_review "$target" "$id" global independent-minor minor-session 1
  expect_close_failure "$target" "$id" "unresolved Minor finding" impacted
}

run_architectural_r2_contract() {
  local target="$1" id="CPK-architectural-r2"
  local truth_ref="docs/sot/product/ARCHITECTURAL_R2_SMOKE.md"
  local gate_decision="accept_implementation_and_update_truth"
  local gate_ref="user_instruction"
  local cr sidecar

  mkdir -p "$target/docs/sot/product"
  printf '# Architectural R2 Truth Patch fixture\n' > "$target/$truth_ref"
  write_work "$target" "$id" specs/902-architectural-r2
  write_cpk "$target" "$id" R2 architectural applied true true specs/902-architectural-r2/work.md \
    exempt true true "$truth_ref" resolved "$gate_decision" "$gate_ref"
  record_route "$target" "$id" R1 R2 bounded architectural
  record_tdd_exemption "$target" "$id"
  record_isolation "$target" "$id"
  record_repair "$target" "$id" 1
  record_repair "$target" "$id" 2
  record_gate_b "$target" "$id" "$gate_decision" "$gate_ref"

  record_verification "$target" "$id" governance
  record_verification "$target" "$id" full
  record_review "$target" "$id" batch independent-batch-a batch-session-a 0 BATCH-A
  record_review "$target" "$id" batch independent-batch-b batch-session-b 0 BATCH-B
  record_review "$target" "$id" global independent-global arch-global-session 0
  record_review "$target" "$id" specialist independent-specialist specialist-session 0
  close_work "$target" "$id" full

  cr="$target/docs/closure/CR-architectural-r2.md"
  [[ -f "$cr" ]] || fail "architectural R2 did not create its automatic CR"
  grep -q '^truth_drift: resolved$' "$cr" || fail "resolved Gate B was not projected"
  grep -q '"review_roles":\["batch","global","re_review","specialist"\]' "$cr" || fail "architectural review roles were not projected"
  grep -q '"max_repair_round":2' "$cr" || fail "repair-round evidence was not projected"
  ! grep -q '"event_type"' "$cr" || fail "receipt v2 CR embedded raw event records"
  sidecar="$(find "$target/docs/closure/evidence" -maxdepth 1 -type f -name "EV-$id-*.jsonl" -print -quit)"
  [[ -n "$sidecar" ]] || fail "architectural R2 did not create its evidence sidecar"
  assert_receipt_v2_pair "$target" "$cr" "$id"
}

run_concurrent_close_contract() {
  local target="$1" id="CPK-concurrent-close" first_status second_status first_pid second_pid
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_verification "$target" "$id" impacted

  set +e
  (cd "$target" && bash .p2t2c/bin/p2t2c_close.sh --work-id "$id" --verification-profile impacted) >"$tmp_root/close-one.log" 2>&1 &
  first_pid=$!
  (cd "$target" && bash .p2t2c/bin/p2t2c_close.sh --work-id "$id" --verification-profile impacted) >"$tmp_root/close-two.log" 2>&1 &
  second_pid=$!
  wait "$first_pid"; first_status=$?
  wait "$second_pid"; second_status=$?
  set -e
  if ! { [[ "$first_status" -eq 0 && "$second_status" -ne 0 ]] || [[ "$first_status" -ne 0 && "$second_status" -eq 0 ]]; }; then
    fail "concurrent close must produce exactly one successful owner"
  fi
  [[ ! -e "$target/.p2t2c/runs/$id" ]] || fail "successful concurrent close did not clean its run"
}

run_unmapped_path_contract() {
  local target="$1" id="CPK-unmapped-path"
  local config="$target/.p2t2c/project_config.yaml"
  local backup="$tmp_root/$id-project-config.yaml"
  local run_dir="$target/.p2t2c/runs/$id"
  local verification_status=0 route_status=0

  cp "$config" "$backup"
  if grep -q '^verification:' "$config"; then
    perl -0pi -e 's/\n    - pattern: "\*\*"\n      profile: "impacted"\n/\n/' "$config"
  else
    cat >> "$config" <<'EOF'

verification:
  fast:
    commands:
      - id: "p2t2c-check"
        run: "bash .p2t2c/bin/check_p2t2c.sh --pre-close-work-id {work_id}"
        read_only: true
        parallel_group: "checker"
        covers: []
  impacted:
    commands:
      - id: "p2t2c-check"
        run: "bash .p2t2c/bin/check_p2t2c.sh --pre-close-work-id {work_id}"
        read_only: true
        parallel_group: "checker"
        covers: []
  full:
    commands:
      - id: "p2t2c-check"
        run: "bash .p2t2c/bin/check_p2t2c.sh --pre-close-work-id {work_id}"
        read_only: true
        parallel_group: "checker"
        covers:
          - "governance:p2t2c-check"
  governance:
    commands:
      - id: "p2t2c-check"
        run: "bash .p2t2c/bin/check_p2t2c.sh --pre-close-work-id {work_id}"
        read_only: true
        parallel_group: "checker"
        covers: []
  path_mapping:
    - pattern: ".p2t2c/**"
      profile: "governance"
    - pattern: "src/**"
      profile: "impacted"
EOF
  fi
  if grep -q 'pattern: "\*\*"' "$config"; then
    fail "unmapped-path fixture did not remove the final catch-all"
  fi
  checkpoint_fixture_git "$target" unmapped-config

  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  set +e
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type route \
    --from-risk R1 --to-risk R1 --from-shape bounded --to-shape bounded) >"$negative_log" 2>&1
  route_status=$?
  set -e
  if [[ "$route_status" -ne 0 ]]; then
    grep -Eqi 'path[_ -]?mapping|catch.?all|unmapped|matching profile' "$negative_log" \
      || fail "unmapped-path route failed for an unrelated reason"
    rm -f "$target/docs/change_packs/$id.md"
    cp "$backup" "$config"
    checkpoint_fixture_git "$target" unmapped-config-restored
    return 0
  fi
  mkdir -p "$target/unmapped-area"
  printf 'must not receive an implicit verification profile\n' > "$target/unmapped-area/work.txt"
  record_isolation "$target" "$id"

  set +e
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type verification \
    --verification-profile impacted --command-id p2t2c-check) >"$negative_log" 2>&1
  verification_status=$?
  set -e
  if [[ "$verification_status" -eq 0 ]]; then
    expect_close_failure "$target" "$id" "unmapped changed path" impacted
  elif ! grep -Eqi 'path[_ -]?mapping|catch.?all|unmapped|matching profile' "$negative_log"; then
    fail "unmapped-path verification failed for an unrelated reason"
  fi

  if [[ -L "$run_dir/events.jsonl" ]]; then
    fail "unmapped-path fixture unexpectedly replaced its ledger with a symlink"
  fi
  rm -f "$run_dir/events.jsonl" "$run_dir/contract.json" "$run_dir/.closing"
  rmdir "$run_dir" 2>/dev/null || true
  rm -f "$target/docs/change_packs/$id.md" "$target/src/$id.txt" "$target/unmapped-area/work.txt"
  rmdir "$target/unmapped-area"
  cp "$backup" "$config"
  checkpoint_fixture_git "$target" unmapped-config-restored
}

run_baseline_contracts() {
  local target="$1" id baseline committed_head parent_head

  id="CPK-baseline-freeze"
  baseline="$(git -C "$target" rev-parse HEAD)"
  write_cpk "$target" "$id" R1 bounded ready true false none not_applicable false false none not_triggered none none
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type route \
    --from-risk R1 --to-risk R1 --from-shape bounded --to-shape bounded)
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type isolation \
    --workspace-kind shared_owned --branch smoke-fixture --baseline-sha "$baseline" --clean true)
  mkdir -p "$target/src"
  printf 'baseline must remain frozen after this commit\n' > "$target/src/$id.txt"
  git -C "$target" add -A
  git -C "$target" commit -q -m "fixture baseline freeze implementation"
  committed_head="$(git -C "$target" rev-parse HEAD)"
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type isolation \
    --workspace-kind shared_owned --branch smoke-fixture --baseline-sha "$committed_head" --clean true) >"$negative_log" 2>&1
  then
    fail "isolation baseline changed after the first route"
  fi

  id="CPK-commit-before-run"
  write_cpk "$target" "$id" R1 bounded ready true false none not_applicable false false none not_triggered none none
  printf 'implementation committed before the first evidence event\n' > "$target/src/$id.txt"
  git -C "$target" add -A
  git -C "$target" commit -q -m "fixture implementation before evidence"
  committed_head="$(git -C "$target" rev-parse HEAD)"
  parent_head="$(git -C "$target" rev-parse HEAD^)"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type route \
    --from-risk R1 --to-risk R1 --from-shape bounded --to-shape bounded)
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type isolation \
    --workspace-kind shared_owned --branch smoke-fixture --baseline-sha "$parent_head" --clean true) >"$negative_log" 2>&1
  then
    fail "commit-before-run fixture accepted a backdated isolation baseline"
  fi
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type isolation \
    --workspace-kind shared_owned --branch smoke-fixture --baseline-sha "$committed_head" --clean true)
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type verification \
    --verification-profile impacted --command-id p2t2c-check)
  expect_close_failure "$target" "$id" "R1 no-diff/commit-before-run closure" impacted
}

run_ledger_symlink_swap_contract() {
  local target="$1" id="CPK-ledger-symlink-swap"
  local run_dir="$target/.p2t2c/runs/$id"
  local ledger="$run_dir/events.jsonl"
  local saved_ledger="$run_dir/events.before-swap.jsonl"
  local victim="$tmp_root/$id-victim"
  local release_signal="$tmp_root/$id-release"
  local command_log="$tmp_root/$id-command.log"
  local runner_pid runner_status marker attempt

  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  : > "$victim"
  rm -f "$release_signal"

  set +e
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type exploration \
    --command-label symlink-swap-wait -- bash -c \
    'while [[ ! -e "$1" ]]; do sleep 0.02; done' bash "$release_signal") >"$command_log" 2>&1 &
  runner_pid=$!
  set -e

  marker=""
  for attempt in $(seq 1 250); do
    marker="$(find "$run_dir" -maxdepth 1 -type f -name '.active-*' -print -quit 2>/dev/null || true)"
    [[ -z "$marker" ]] || break
    sleep 0.02
  done
  if [[ -z "$marker" ]]; then
    : > "$release_signal"
    wait "$runner_pid" 2>/dev/null || true
    fail "ledger symlink-swap fixture did not observe the active command marker"
  fi

  mv "$ledger" "$saved_ledger"
  ln -s "$victim" "$ledger"
  : > "$release_signal"
  set +e
  wait "$runner_pid"
  runner_status=$?
  set -e
  [[ "$runner_status" -ne 0 ]] || fail "ledger symlink swap during a command was accepted"
  [[ ! -s "$victim" ]] || fail "ledger symlink swap wrote an event outside the run root"

  [[ -L "$ledger" ]] || fail "ledger symlink-swap fixture lost its attack symlink unexpectedly"
  rm -f "$ledger"
  mv "$saved_ledger" "$ledger"
  rm -f "$release_signal"
  if find "$run_dir" -maxdepth 1 -name '.active-*' -print -quit | grep -q .; then
    fail "ledger symlink-swap failure retained an active command marker"
  fi
  rm -f "$run_dir/events.jsonl" "$run_dir/contract.json"
  rmdir "$run_dir"
  rm -f "$target/docs/change_packs/$id.md" "$target/src/$id.txt"
}

run_path_and_checker_guards() {
  local target="$1" id victim run_dir truth_ref outside

  id="CPK-ledger-symlink"
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  run_dir="$target/.p2t2c/runs/$id"
  victim="$tmp_root/$id-victim"
  mkdir -p "$run_dir"
  : > "$victim"
  ln -s "$victim" "$run_dir/events.jsonl"
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type route \
    --from-risk R1 --to-risk R1 --from-shape bounded --to-shape bounded) >"$negative_log" 2>&1
  then
    fail "symlinked ledger was accepted"
  fi
  [[ ! -s "$victim" ]] || fail "symlinked ledger wrote outside the run root"
  rm -f "$run_dir/events.jsonl"
  rmdir "$run_dir"

  id="CPK-blocked-r1"
  write_cpk "$target" "$id" R1 bounded blocked false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type mutation \
    --command-label blocked-mutation -- bash -c 'exit 0') >"$negative_log" 2>&1
  then
    fail "blocked R1 accepted a mutation event"
  fi
  if (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --work-id "$id" --event-type verification \
    --verification-profile impacted --command-id p2t2c-check) >"$negative_log" 2>&1
  then
    fail "blocked R1 accepted a verification event"
  fi
  expect_close_failure "$target" "$id" "blocked R1 closure" impacted

  id="CPK-broken-symlink-r2"
  truth_ref="docs/sot/product/BROKEN_SYMLINK_R2.md"
  printf '# Broken symlink R2 Truth\n' > "$target/$truth_ref"
  write_cpk "$target" "$id" R2 bounded applied false false none not_applicable true false \
    "$truth_ref" not_triggered none none
  record_route "$target" "$id" R1 R2 bounded bounded
  record_verification "$target" "$id" governance
  record_verification "$target" "$id" full
  record_review "$target" "$id" global independent-symlink symlink-session 0
  outside="$tmp_root/broken-symlink-outside.md"
  ln -s "$outside" "$target/docs/closure/CR-broken-symlink-r2.md"
  expect_close_failure "$target" "$id" "broken evidence-target symlink" full
  [[ ! -e "$outside" ]] || fail "broken evidence-target symlink wrote outside the project"
  rm -f "$target/docs/closure/CR-broken-symlink-r2.md"
  close_work "$target" "$id" full
  [[ -f "$target/docs/closure/CR-broken-symlink-r2.md" && ! -L "$target/docs/closure/CR-broken-symlink-r2.md" ]] || fail "clean retry did not create a regular CR"

  id="CPK-normal-checker-r2"
  truth_ref="docs/sot/product/NORMAL_CHECKER_SMOKE.md"
  mkdir -p "$target/docs/sot/product"
  printf '# Normal checker environment bypass fixture\n' > "$target/$truth_ref"
  write_cpk "$target" "$id" R2 bounded applied false false none not_applicable true false \
    "$truth_ref" not_triggered none none
  if (cd "$target" && P2T2C_ACTIVE_WORK_ID="$id" \
    P2T2C_ACTIVE_EVIDENCE_TARGET="docs/closure/CR-normal-checker-r2.md" \
    bash .p2t2c/bin/check_p2t2c.sh) >"$negative_log" 2>&1
  then
    fail "normal checker accepted environment-variable R2 closure bypass"
  fi
  rm -f "$target/docs/change_packs/$id.md" "$target/$truth_ref"

}

run_atomic_close_contract() {
  local target="$1" id="CPK-atomic-close" checker_backup before_hash after_hash
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  checker_backup="$tmp_root/$id-checker-backup"
  cp "$target/.p2t2c/bin/check_p2t2c.sh" "$checker_backup"
  cat > "$target/.p2t2c/bin/check_p2t2c.sh" <<'EOF'
#!/usr/bin/env bash
if grep -q '"receipt_type":"closure"' docs/change_packs/CPK-atomic-close.md; then exit 1; fi
exit 0
EOF
  chmod +x "$target/.p2t2c/bin/check_p2t2c.sh"
  record_verification "$target" "$id" impacted
  record_verification "$target" "$id" governance
  before_hash="$(sha256_file "$target/docs/change_packs/$id.md")"
  expect_close_failure "$target" "$id" "atomic close checker rollback" impacted
  after_hash="$(sha256_file "$target/docs/change_packs/$id.md")"
  [[ "$before_hash" == "$after_hash" ]] || fail "failed close did not restore the original artifact"
  grep -q '^status: ready$' "$target/docs/change_packs/$id.md" || fail "failed close retained applied status"
  [[ -f "$target/.p2t2c/runs/$id/events.jsonl" ]] || fail "failed close removed its ledger"
  if find "$target/docs/closure/evidence" -maxdepth 1 -type f -name "EV-$id-*.jsonl" | grep -q .; then
    fail "failed close retained an installed evidence sidecar"
  fi
  cp "$checker_backup" "$target/.p2t2c/bin/check_p2t2c.sh"
  chmod +x "$target/.p2t2c/bin/check_p2t2c.sh"
}

run_cli_examples() {
  local target="$1"
  (cd "$target" && bash .p2t2c/bin/p2t2c_run.sh --help) | grep -q -- '--remaining-risk-status\|--event-type exploration'
  (cd "$target" && bash .p2t2c/bin/p2t2c_close.sh --help) | grep -q -- '--remaining-risk-ref'
  (cd "$target" && perl .p2t2c/bin/p2t2c_evidence.pl --action verification-command \
    --verification-profile impacted --command-id p2t2c-check --work-id CLI-example) | grep -q 'pre-close-work-id CLI-example'
  (cd "$target" && ./.p2t2c/bin/p2t2c --help) | grep -q 'context\|status\|evidence\|verify'
  (cd "$target" && ./.p2t2c/bin/p2t2c context --help) | grep -q -- '--phase\|context'
  (cd "$target" && ./.p2t2c/bin/p2t2c status --help) | grep -q -- '--work-id\|status'
  (cd "$target" && ./.p2t2c/bin/p2t2c evidence summary --help) | grep -q -- '--work-id\|summary'
  (cd "$target" && ./.p2t2c/bin/p2t2c verify --help) | grep -q -- '--profile\|verify'
  if (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh --pre-close-work-id '../bad') >"$negative_log" 2>&1; then
    fail "checker CLI accepted an unsafe work id"
  fi
}

assert_installed_assets() {
  local release_root="$1" target="$2"
  local worker_key="$(basename "$target")"
  local expected="$tmp_root/$worker_key-managed.expected" actual="$tmp_root/$worker_key-managed.actual" rel

  while IFS= read -r rel; do
    [[ -f "$target/$rel" ]] || fail "installed target missing managed asset: $rel"
    [[ "$(permission_mode "$target/$rel")" == "$(permission_mode "$release_root/$rel")" ]] \
      || fail "installed target mode differs from release source: $rel"
  done < <(managed_paths "$release_root/.p2t2c/managed-files.txt")

  managed_paths "$release_root/.p2t2c/managed-files.txt" > "$expected"
  awk '{ print $2 }' "$target/.p2t2c/lock.sha256" > "$actual"
  diff -u "$expected" "$actual"

  [[ -f "$target/.p2t2c/project_config.yaml" ]] || fail "new install omitted project configuration"
  [[ "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" == "0.14.1" ]] || fail "new install did not install 0.14.1"
  grep -q 'enforcement: "required"' "$release_root/.p2t2c/project_config.yaml" || fail "release root project configuration is not required-mode"
  if managed_paths "$release_root/.p2t2c/managed-files.txt" | grep -qx '.p2t2c/project_config.yaml'; then
    fail "project-owned project_config.yaml entered the managed inventory"
  fi
  grep -q 'profile: "p2t2c-adaptive-v2"' "$target/.p2t2c/project_config.yaml" || fail "new install is not adaptive-v2"
  grep -q 'enforcement: "advisory"' "$target/.p2t2c/project_config.yaml" || fail "new install is not advisory-mode"
  [[ "$(wc -c < "$target/.p2t2c/project_config.yaml" | tr -d ' ')" -lt 1024 ]] || fail "new install project overlay is not compact"
  ! grep -q '^verification:' "$target/.p2t2c/project_config.yaml" || fail "new install copied inherited verification into the project overlay"
  grep -q 'pattern: "\*\*"' "$target/.p2t2c/defaults.yaml" || fail "managed defaults lack a final verification catch-all"
  grep -q 'read_only: true' "$target/.p2t2c/defaults.yaml" || fail "managed defaults omit read_only metadata"
  grep -q 'parallel_group:' "$target/.p2t2c/defaults.yaml" || fail "managed defaults omit their safe parallel group"
  grep -q 'governance:p2t2c-check' "$target/.p2t2c/defaults.yaml" || fail "managed defaults omit governance coverage"
  (cd "$target" && perl .p2t2c/bin/p2t2c_evidence.pl --action profile-requirement --verification-profile full) \
    | grep -q '"command_ids":\["p2t2c-check"\]' || fail "compact overlay did not resolve the effective full profile"
  [[ -f "$target/.p2t2c/templates/execution/work.md" ]] || fail "work.md template was not installed"
  [[ -f "$target/.p2t2c/evals/adaptive-v2-scenarios.md" ]] || fail "adaptive-v2 eval asset was not installed"
  grep -q '^Status: Scenario definition only$' "$target/.p2t2c/evals/adaptive-v2-scenarios.md" || fail "Agent eval asset incorrectly claims executed results"
  [[ ! -e "$target/.p2t2c/runs" ]] || fail "install created runtime evidence state before first run"
  [[ ! -e "$target/.p2t2c/cache" ]] || fail "install created checker cache state before first check"
  [[ -x "$target/.p2t2c/bin/p2t2c" ]] || fail "new install omitted the executable p2t2c dispatcher"
  [[ -f "$target/.p2t2c/bin/p2t2c_close.pl" ]] || fail "new install omitted the one-process close core"
  [[ -f "$target/.p2t2c/bin/p2t2c_context.pl" ]] || fail "new install omitted bounded context views"
  [[ -f "$target/.p2t2c/bin/p2t2c_verify.pl" ]] || fail "new install omitted batch verification"
  [[ -f "$target/.p2t2c/defaults.yaml" ]] || fail "new install omitted immutable defaults"
  [[ -f "$target/.p2t2c/schemas/closure-receipt-v2.schema.json" ]] || fail "new install omitted receipt v2 schema"
  [[ -f "$target/.p2t2c/schemas/context-capsule-v1.schema.json" ]] || fail "new install omitted context capsule schema"
  [[ -f "$target/.p2t2c/skills/admit-route/SKILL.md" && -f "$target/.p2t2c/skills/execute/SKILL.md" && -f "$target/.p2t2c/skills/verify-close/SKILL.md" ]] \
    || fail "new install omitted one or more phase skills"
  [[ -f "$target/docs/closure/evidence/README.md" ]] || fail "new install omitted the evidence-sidecar directory contract"
  if find "$target/docs/closure/evidence" -maxdepth 1 -type f -name 'EV-*.jsonl' | grep -q .; then
    fail "fresh install contains an evidence sidecar instance"
  fi
  (cd "$target" && ./.p2t2c/bin/check_p2t2c.sh >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c_install.sh --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c_upgrade.sh --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c_run.sh --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c_close.sh --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c context --help >/dev/null)
  (cd "$target" && ./.p2t2c/bin/p2t2c verify --help >/dev/null)
  if find "$target/docs/closure" -maxdepth 1 -type f -name 'CR-*.md' | grep -q .; then
    fail "fresh install contains an R0 or historical closure instance"
  fi
}

find_013_commit() {
  local rel="$1" commit version
  for commit in $(git -C "$repo_root" rev-list --all -- "$rel/.p2t2c/VERSION"); do
    version="$(git -C "$repo_root" show "$commit:$rel/.p2t2c/VERSION" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$version" == "0.13.0" ]]; then
      printf '%s\n' "$commit"
      return 0
    fi
  done
  return 1
}

run_upgrade_013_contract() {
  local rel="$1" release_root="$2"
  local legacy_source="$tmp_root/$rel-013-source"
  local target="$tmp_root/$rel-013-target"
  local legacy_commit project_config_before truth_before cpk_before spec_before cr_before upgrade_dir
  local inventory_before="$tmp_root/$rel-013-inventory.before" inventory_after="$tmp_root/$rel-013-inventory.after"

  legacy_commit="$(find_013_commit "$rel" || true)"
  [[ -n "$legacy_commit" ]] || fail "cannot locate a committed 0.13.0 $rel fixture"
  mkdir -p "$legacy_source" "$target"
  git -C "$repo_root" archive "$legacy_commit:$rel" | tar -x -C "$legacy_source"
  [[ "$(tr -d '[:space:]' < "$legacy_source/.p2t2c/VERSION")" == "0.13.0" ]] || fail "legacy archive is not 0.13.0"

  make -C "$legacy_source" p2t2c-install TARGET="$target"
  create_historical_v2_samples "$target"
  mkdir -p "$target/docs/sot/product"
  printf '# Project-owned historical Truth\n' > "$target/docs/sot/product/HISTORICAL.md"

  project_config_before="$(sha256_file "$target/.p2t2c/project_config.yaml")"
  truth_before="$(sha256_file "$target/docs/sot/product/HISTORICAL.md")"
  cpk_before="$(sha256_file "$target/docs/change_packs/CPK-20260710-historical-v2.md")"
  spec_before="$(sha256_file "$target/specs/900-historical-v2/spec.md")"
  cr_before="$(sha256_file "$target/docs/closure/CR-20260710-historical-v2.md")"
  target_inventory "$target" > "$inventory_before"

  echo "==> Upgrading a real $rel 0.13.0 installation"
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --dry-run --source "$release_root")
  if ! (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$release_root"); then
    while IFS= read -r validation_path; do echo "==> $validation_path" >&2; safe_tail "$validation_path" >&2; done \
      < <(find "$target/.p2t2c/upgrade" -maxdepth 3 -type f -name validation.log 2>/dev/null)
    fail "$rel 0.13.0 long-hop upgrade failed"
  fi

  [[ "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" == "0.14.1" ]] || fail "upgrade did not install 0.14.1"
  [[ -f "$target/.p2t2c/managed-files.txt" ]] || fail "upgrade omitted managed-files.txt"
  [[ -f "$target/.p2t2c/bin/p2t2c_run.sh" ]] || fail "upgrade omitted evidence runner"
  [[ -x "$target/.p2t2c/bin/p2t2c" ]] || fail "upgrade omitted the context/verify dispatcher"
  [[ -f "$target/.p2t2c/bin/p2t2c_verify.pl" ]] || fail "upgrade omitted batch verification"
  [[ -f "$target/.p2t2c/schemas/closure-receipt-v2.schema.json" ]] || fail "upgrade omitted receipt v2"
  [[ "$(sha256_file "$target/.p2t2c/project_config.yaml")" == "$project_config_before" ]] || fail "upgrade rewrote project configuration"
  [[ "$(sha256_file "$target/docs/sot/product/HISTORICAL.md")" == "$truth_before" ]] || fail "upgrade rewrote project Truth"
  [[ "$(sha256_file "$target/docs/change_packs/CPK-20260710-historical-v2.md")" == "$cpk_before" ]] || fail "upgrade rewrote historical CPK"
  [[ "$(sha256_file "$target/specs/900-historical-v2/spec.md")" == "$spec_before" ]] || fail "upgrade rewrote historical spec"
  [[ "$(sha256_file "$target/docs/closure/CR-20260710-historical-v2.md")" == "$cr_before" ]] || fail "upgrade rewrote historical CR"
  grep -q 'profile: "p2t2c-balanced-v1"' "$target/.p2t2c/project_config.yaml" || fail "legacy balanced profile was not preserved"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)

  echo "==> Rolling back $rel to 0.13.0"
  upgrade_dir="$(find "$target/.p2t2c/upgrade" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | awk 'END {print}')"
  (cd "$target" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback "$upgrade_dir")
  target_inventory "$target" > "$inventory_after"
  assert_target_inventory_equal "$inventory_before" "$inventory_after" "$rel 0.13 rollback"

  [[ "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" == "0.13.0" ]] || fail "rollback did not restore 0.13.0"
  [[ ! -e "$target/.p2t2c/managed-files.txt" ]] || fail "rollback retained a post-0.13 managed manifest"
  [[ ! -e "$target/.p2t2c/bin/p2t2c_run.sh" ]] || fail "rollback retained a post-0.13 evidence runner"
  [[ ! -e "$target/.p2t2c/bin/p2t2c" ]] || fail "rollback retained a 0.14.1-created dispatcher"
  [[ ! -e "$target/.p2t2c/bin/p2t2c_verify.pl" ]] || fail "rollback retained 0.14.1 batch verification"
  [[ "$(sha256_file "$target/.p2t2c/project_config.yaml")" == "$project_config_before" ]] || fail "rollback rewrote project configuration"
  [[ "$(sha256_file "$target/docs/sot/product/HISTORICAL.md")" == "$truth_before" ]] || fail "rollback rewrote project Truth"
  [[ "$(sha256_file "$target/docs/change_packs/CPK-20260710-historical-v2.md")" == "$cpk_before" ]] || fail "rollback rewrote historical CPK"
  [[ "$(sha256_file "$target/specs/900-historical-v2/spec.md")" == "$spec_before" ]] || fail "rollback rewrote historical spec"
  [[ "$(sha256_file "$target/docs/closure/CR-20260710-historical-v2.md")" == "$cr_before" ]] || fail "rollback rewrote historical CR"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
}

run_upgrade_014_contract() {
  local rel="$1" release_root="$2"
  local fixture_root="$tmp_root/$rel-014-fixture"
  local legacy_source="$fixture_root/$rel"
  local target="$tmp_root/$rel-014-target"
  local inline_id="CPK-upgrade-inline-v1" active_id="CPK-upgrade-active"
  local sidecar_rel="docs/closure/evidence/EV-CPK-upgrade-active-0000000000000000000000000000000000000000000000000000000000000000.jsonl"
  local project_config_before truth_before v2_before inline_before active_contract_before active_events_before sidecar_before cache_before upgrade_dir
  local legacy_full_before legacy_full_after
  local inventory_before="$tmp_root/$rel-014-inventory.before" inventory_after="$tmp_root/$rel-014-inventory.after"

  mkdir -p "$fixture_root" "$target"
  tar -xzf "$fixture_014_archive" -C "$fixture_root"
  [[ "$(tr -d '[:space:]' < "$legacy_source/.p2t2c/VERSION")" == "0.14.0" ]] || fail "$rel frozen fixture is not 0.14.0"
  (cd "$legacy_source" && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256 >/dev/null)
  make -C "$legacy_source" p2t2c-install TARGET="$target" >/dev/null

  create_historical_v2_samples "$target"
  mkdir -p "$target/docs/sot/product"
  printf '# Project-owned 0.14 Truth\n' > "$target/docs/sot/product/HISTORICAL_014.md"
  write_cpk "$target" "$inline_id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  initialize_fixture_git "$target"
  record_route "$target" "$inline_id" R1 R1 bounded bounded
  record_verification "$target" "$inline_id" impacted
  close_work "$target" "$inline_id" impacted

  write_cpk "$target" "$active_id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$active_id" R1 R1 bounded bounded
  mkdir -p "$target/docs/closure/evidence" "$target/.p2t2c/cache"
  cp "$target/.p2t2c/runs/$active_id/events.jsonl" "$target/$sidecar_rel"
  printf 'cache-preservation-sentinel\n' > "$target/.p2t2c/cache/.upgrade-preserve"

  project_config_before="$(sha256_file "$target/.p2t2c/project_config.yaml")"
  truth_before="$(sha256_file "$target/docs/sot/product/HISTORICAL_014.md")"
  v2_before="$(sha256_file "$target/docs/change_packs/CPK-20260710-historical-v2.md")"
  inline_before="$(sha256_file "$target/docs/change_packs/$inline_id.md")"
  active_contract_before="$(sha256_file "$target/.p2t2c/runs/$active_id/contract.json")"
  active_events_before="$(sha256_file "$target/.p2t2c/runs/$active_id/events.jsonl")"
  sidecar_before="$(sha256_file "$target/$sidecar_rel")"
  cache_before="$(sha256_file "$target/.p2t2c/cache/.upgrade-preserve")"
  legacy_full_before="$(cd "$target" && perl .p2t2c/bin/p2t2c_evidence.pl --action profile-requirement --verification-profile full)"
  target_inventory "$target" > "$inventory_before"

  echo "==> Upgrading a frozen $rel 0.14.0 installation"
  (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --dry-run --source "$release_root")
  if ! (cd "$target" && "$release_root/.p2t2c/bin/p2t2c_upgrade.sh" --apply --source "$release_root"); then
    while IFS= read -r validation_path; do echo "==> $validation_path" >&2; safe_tail "$validation_path" >&2; done \
      < <(find "$target/.p2t2c/upgrade" -maxdepth 3 -type f -name validation.log 2>/dev/null)
    fail "$rel frozen 0.14.0 direct upgrade failed"
  fi

  [[ "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" == "0.14.1" ]] || fail "$rel direct upgrade did not install 0.14.1"
  [[ "$(sha256_file "$target/.p2t2c/project_config.yaml")" == "$project_config_before" ]] || fail "$rel direct upgrade rewrote project configuration"
  [[ "$(sha256_file "$target/docs/sot/product/HISTORICAL_014.md")" == "$truth_before" ]] || fail "$rel direct upgrade rewrote project Truth"
  [[ "$(sha256_file "$target/docs/change_packs/CPK-20260710-historical-v2.md")" == "$v2_before" ]] || fail "$rel direct upgrade rewrote historical v2 CPK"
  [[ "$(sha256_file "$target/docs/change_packs/$inline_id.md")" == "$inline_before" ]] || fail "$rel direct upgrade rewrote inline receipt v1 proof"
  [[ "$(sha256_file "$target/.p2t2c/runs/$active_id/contract.json")" == "$active_contract_before" ]] || fail "$rel direct upgrade rewrote active contract"
  [[ "$(sha256_file "$target/.p2t2c/runs/$active_id/events.jsonl")" == "$active_events_before" ]] || fail "$rel direct upgrade rewrote active ledger"
  [[ "$(sha256_file "$target/$sidecar_rel")" == "$sidecar_before" ]] || fail "$rel direct upgrade rewrote evidence sidecar"
  [[ "$(sha256_file "$target/.p2t2c/cache/.upgrade-preserve")" == "$cache_before" ]] || fail "$rel direct upgrade rewrote cache state"
  [[ -x "$target/.p2t2c/bin/p2t2c" && -f "$target/.p2t2c/bin/p2t2c_verify.pl" && -f "$target/.p2t2c/bin/p2t2c_close.pl" ]] \
    || fail "$rel direct upgrade omitted 0.14.1 CLI assets"
  legacy_full_after="$(cd "$target" && perl .p2t2c/bin/p2t2c_evidence.pl --action profile-requirement --verification-profile full)"
  [[ "$legacy_full_after" == "$legacy_full_before" ]] || fail "$rel direct upgrade changed the legacy full-profile digest or semantics"

  upgrade_dir="$(find "$target/.p2t2c/upgrade" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | awk 'END {print}')"
  (cd "$target" && bash .p2t2c/bin/p2t2c_upgrade.sh --rollback "$upgrade_dir")
  target_inventory "$target" > "$inventory_after"
  assert_target_inventory_equal "$inventory_before" "$inventory_after" "$rel 0.14 rollback"

  [[ "$(tr -d '[:space:]' < "$target/.p2t2c/VERSION")" == "0.14.0" ]] || fail "$rel direct rollback did not restore 0.14.0"
  [[ ! -e "$target/.p2t2c/bin/p2t2c" ]] || fail "$rel direct rollback retained the 0.14.1 dispatcher"
  [[ ! -e "$target/.p2t2c/bin/p2t2c_verify.pl" ]] || fail "$rel direct rollback retained batch verification"
  [[ ! -e "$target/.p2t2c/bin/p2t2c_close.pl" ]] || fail "$rel direct rollback retained the 0.14.1 close core"
  [[ ! -e "$target/docs/closure/evidence/README.md" ]] || fail "$rel direct rollback retained the 0.14.1 evidence README"
  [[ "$(sha256_file "$target/.p2t2c/project_config.yaml")" == "$project_config_before" ]] || fail "$rel direct rollback rewrote project configuration"
  [[ "$(sha256_file "$target/docs/change_packs/$inline_id.md")" == "$inline_before" ]] || fail "$rel direct rollback rewrote inline receipt v1 proof"
  [[ "$(sha256_file "$target/.p2t2c/runs/$active_id/contract.json")" == "$active_contract_before" ]] || fail "$rel direct rollback rewrote active contract"
  [[ "$(sha256_file "$target/.p2t2c/runs/$active_id/events.jsonl")" == "$active_events_before" ]] || fail "$rel direct rollback rewrote active ledger"
  [[ "$(sha256_file "$target/$sidecar_rel")" == "$sidecar_before" ]] || fail "$rel direct rollback rewrote evidence sidecar"
  [[ "$(sha256_file "$target/.p2t2c/cache/.upgrade-preserve")" == "$cache_before" ]] || fail "$rel direct rollback rewrote cache state"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh)
}

run_parity_preflight() {
  if [[ -n "$pre_close_work_id" ]]; then
    bash "$repo_root/scripts/check_release_parity.sh" --pre-close-work-id "$pre_close_work_id"
  else
    bash "$repo_root/scripts/check_release_parity.sh"
  fi
}

validate_daily_map() {
  local pattern suites row_count=0 last_pattern="" suite_name seen_patterns=$'\n'
  local -a mapped=()
  while IFS=$'\t' read -r pattern suites; do
    [[ -z "$pattern" || "${pattern:0:1}" == "#" ]] && continue
    [[ -n "$suites" && "$suites" != *$'\t'* ]] || fail "invalid daily selector row"
    [[ "$seen_patterns" != *$'\n'"$pattern"$'\n'* ]] || fail "duplicate daily selector pattern: $pattern"
    seen_patterns+="$pattern"$'\n'; row_count=$((row_count+1)); last_pattern="$pattern"
    IFS=',' read -r -a mapped <<< "$suites"
    for suite_name in "${mapped[@]}"; do
      case "$suite_name" in contract|security|transaction|migration|locale) ;; *) fail "invalid daily selector suite: $suite_name" ;; esac
    done
  done < "$daily_map"
  [[ "$row_count" -gt 0 && "$last_pattern" == "*" ]] || fail "daily selector requires a final catch-all"
}

select_daily_suites_for_paths() {
  local path pattern suites suite_name matched
  local -a mapped=()
  local want_contract=0 want_security=0 want_transaction=0 want_migration=0 want_locale=0
  for path in "$@"; do
    [[ -n "$path" && "$path" != /* && "$path" != ../* && "$path" != */../* && "$path" != *$'\n'* ]] || fail "unsafe changed path: $path"
    matched=0
    while IFS=$'\t' read -r pattern suites; do
      [[ -z "$pattern" || "${pattern:0:1}" == "#" ]] && continue
      if [[ "$path" == $pattern ]]; then
        IFS=',' read -r -a mapped <<< "$suites"
        for suite_name in "${mapped[@]}"; do
          case "$suite_name" in
            contract) want_contract=1 ;; security) want_security=1 ;; transaction) want_transaction=1 ;;
            migration) want_migration=1 ;; locale) want_locale=1 ;;
          esac
        done
        matched=1; break
      fi
    done < "$daily_map"
    [[ "$matched" -eq 1 ]] || fail "changed path did not match daily selector: $path"
  done
  [[ "$want_contract" -eq 1 ]] && echo contract
  [[ "$want_security" -eq 1 ]] && echo security
  [[ "$want_transaction" -eq 1 ]] && echo transaction
  [[ "$want_migration" -eq 1 ]] && echo migration
  [[ "$want_locale" -eq 1 ]] && echo locale
}

collect_daily_paths() {
  local path
  if [[ "${#changed_paths[@]}" -gt 0 ]]; then return 0; fi
  git -C "$repo_root" rev-parse --verify "$changed_from^{commit}" >/dev/null 2>&1 || fail "invalid --changed-from ref: $changed_from"
  while IFS= read -r -d '' path; do changed_paths+=("$path"); done < <(git -C "$repo_root" diff --name-only -z "$changed_from" --)
  while IFS= read -r -d '' path; do changed_paths+=("$path"); done < <(git -C "$repo_root" ls-files --others --exclude-standard -z)
}

copy_release_source() {
  local rel="$1" label="$2" destination
  destination="$tmp_root/$label-$rel-source"
  mkdir -p "$destination"
  cp -pR "$repo_root/$rel/." "$destination/"
  refresh_source_metadata "$destination"
  printf '%s\n' "$destination"
}

install_suite_target() {
  local source_root="$1" target="$2"
  mkdir -p "$target"
  if ! bash "$source_root/.p2t2c/bin/p2t2c_install.sh" --apply --target "$target" >/dev/null; then
    while IFS= read -r install_log; do echo "==> $install_log" >&2; safe_tail "$install_log" >&2; done \
      < <(find "$target/.p2t2c/install" -maxdepth 3 -type f \( -name validation.log -o -name install-report.md \) 2>/dev/null)
    fail "fresh suite install failed"
  fi
}

suite_target=""
suite_source=""
suite_rel=""
suite_release_root=""

run_registered_cases() {
  local wanted_suite="$1" wanted_scope="$2" id registered_suite registered_scope handler
  local key="${suite_rel:-repo}" expected observed
  expected="$tmp_root/registry-$wanted_suite-$wanted_scope-$key-$$.expected"
  observed="$tmp_root/registry-$wanted_suite-$wanted_scope-$key-$$.observed"
  : > "$expected"; : > "$observed"
  while IFS=$'\t' read -r id registered_suite registered_scope handler; do
    [[ -z "$id" || "${id:0:1}" == "#" ]] && continue
    [[ "$registered_suite" == "$wanted_suite" && "$registered_scope" == "$wanted_scope" ]] || continue
    printf '%s\n' "$id" >> "$expected"
    "$handler"
    printf '%s\n' "$id" >> "$observed"
  done < "$case_registry"
  [[ -s "$expected" ]] || fail "registry has no cases for $wanted_suite/$wanted_scope"
  diff -u "$expected" "$observed" || fail "registered case dispatch was incomplete for $wanted_suite/$wanted_scope"
}

case_contract_historical_routing() { create_historical_v2_samples "$suite_target"; create_v3_routing_samples "$suite_target"; }
case_contract_v3_matrix() {
  check_invalid_v3_contract "$suite_target"; check_artifact_matrix_contracts "$suite_target"
  (cd "$suite_target" && bash .p2t2c/bin/check_p2t2c.sh)
  initialize_fixture_git "$suite_target"
}
case_contract_r0() { run_r0_contracts "$suite_target"; checkpoint_fixture_git "$suite_target" r0; }
case_contract_gate_a() { run_gate_a_exploration_contract "$suite_target"; }
case_contract_shape_route() { run_spike_and_route_contracts "$suite_target"; checkpoint_fixture_git "$suite_target" routing; }
case_contract_tdd_binding() { run_tdd_and_contract_binding "$suite_target"; checkpoint_fixture_git "$suite_target" tdd-contract; }
case_contract_advisory_required() { run_advisory_required_contracts "$suite_target"; checkpoint_fixture_git "$suite_target" advisory-required; }
case_contract_review() { run_review_contracts "$suite_target"; checkpoint_fixture_git "$suite_target" review; }
case_contract_architectural_r2() { run_architectural_r2_contract "$suite_target"; }
case_contract_cli() { run_cli_examples "$suite_target"; (cd "$suite_target" && bash .p2t2c/bin/check_p2t2c.sh); }

run_contract_suite() {
  suite_rel="P2T2C_EN"
  suite_source="$(copy_release_source "$suite_rel" contract)"
  suite_target="$tmp_root/contract-target"
  install_suite_target "$suite_source" "$suite_target"
  run_registered_cases contract neutral_once
}

run_v0141_security_contracts() {
  local target="$1" id="CPK-v0141-sidecar" sidecar backup victim config config_backup cache_file invalid
  [[ -x "$target/.p2t2c/bin/p2t2c" ]] || fail "0.14.1 dispatcher is not executable"
  [[ -f "$target/.p2t2c/bin/p2t2c_verify.pl" ]] || fail "0.14.1 batch verifier is missing"

  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_verification "$target" "$id" impacted
  close_work "$target" "$id" impacted
  sidecar="$(find "$target/docs/closure/evidence" -maxdepth 1 -type f -name "EV-$id-*.jsonl" -print -quit)"
  [[ -n "$sidecar" ]] || fail "receipt v2 close did not create a content-addressed sidecar"
  assert_receipt_v2_pair "$target" "$target/docs/change_packs/$id.md" "$id"
  backup="$tmp_root/$(basename "$sidecar").backup"
  cp "$sidecar" "$backup"
  printf '{"tampered":true}\n' >> "$sidecar"
  expect_checker_failure "$target" "tampered evidence sidecar"
  cp "$backup" "$sidecar"
  victim="$tmp_root/sidecar-symlink-victim"
  cp "$backup" "$victim"
  rm -f "$sidecar"
  ln -s "$victim" "$sidecar"
  expect_checker_failure "$target" "symlinked evidence sidecar"
  rm -f "$sidecar"
  cp "$backup" "$sidecar"

  checkpoint_fixture_git "$target" v0141-sidecar
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null)
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null)
  cache_file="$(find "$target/.p2t2c/cache/checker-v1" -maxdepth 1 -type f -name '*.json' -print -quit 2>/dev/null || true)"
  [[ -n "$cache_file" ]] || fail "closed HEAD-clean checker proof was not cached"
  printf '{broken cache envelope\n' > "$cache_file"
  (cd "$target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null) || fail "corrupt cache was trusted instead of recomputed"
  invalid="$target/docs/change_packs/CPK-v0141-cache-poison.md"
  write_cpk "$target" CPK-v0141-cache-poison R1 bounded ready false false none not_applicable false false none not_triggered none none
  perl -0pi -e 's/schema_version: 3/schema_version: "3"/' "$invalid"
  expect_checker_failure "$target" "stale cache after artifact mutation"
  rm -f "$invalid"

  id="CPK-v0141-verify"
  write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
  record_route "$target" "$id" R1 R1 bounded bounded
  record_isolation "$target" "$id"
  (cd "$target" && ./.p2t2c/bin/p2t2c verify --work-id "$id" --profile impacted --jobs 2 >/dev/null)
  config="$target/.p2t2c/project_config.yaml"
  grep -q 'governance:p2t2c-check' "$config" || config="$target/.p2t2c/defaults.yaml"
  config_backup="$tmp_root/v0141-verify-config.backup"
  cp "$config" "$config_backup"
  perl -0pi -e 's/governance:p2t2c-check/governance:not-a-command/' "$config"
  if (cd "$target" && ./.p2t2c/bin/p2t2c verify --work-id "$id" --profile full --jobs 2) >"$negative_log" 2>&1; then
    fail "batch verify accepted forged coverage"
  fi
  grep -Eqi 'cover|unknown|command' "$negative_log" || fail "coverage forgery failed for an unrelated reason"
  cp "$config_backup" "$config"
}

run_close_target_parent_swap_contract() {
  local target="$1" phase id parent="$1/docs/change_packs" parked victim sentinel log marker attempt runner_pid runner_status
  local victim_before victim_after
  checkpoint_fixture_git "$target" close-target-parent-swap-baseline
  for phase in before-install after-check; do
    id="CPK-target-parent-$phase"
    parked="$tmp_root/$id-original-parent"
    victim="$tmp_root/$id-victim"
    sentinel="$victim/sentinel.txt"
    log="$tmp_root/$id-close.log"
    victim_before="$tmp_root/$id-victim.before"
    victim_after="$tmp_root/$id-victim.after"
    mkdir -p "$victim"
    printf 'target-parent-victim-%s\n' "$phase" > "$sentinel"
    if [[ "$phase" == "before-install" ]]; then chmod 0640 "$sentinel"; else chmod 0604 "$sentinel"; fi
    target_inventory "$victim" > "$victim_before"

    write_cpk "$target" "$id" R1 bounded ready false false none not_applicable false false none not_triggered none none
    record_route "$target" "$id" R1 R1 bounded bounded
    record_verification "$target" "$id" impacted
    set +e
    if [[ "$phase" == "before-install" ]]; then
      (cd "$target" && P2T2C_TEST_TARGET_PAUSE_BEFORE_INSTALL_MS=1000 bash .p2t2c/bin/p2t2c_close.sh --work-id "$id" --verification-profile impacted) >"$log" 2>&1 &
    else
      (cd "$target" && P2T2C_TEST_TARGET_PAUSE_AFTER_CHECK_MS=1000 bash .p2t2c/bin/p2t2c_close.sh --work-id "$id" --verification-profile impacted) >"$log" 2>&1 &
    fi
    runner_pid=$!
    set -e
    marker=""
    for attempt in $(seq 1 300); do
      if [[ "$phase" == "before-install" ]]; then
        marker="$(find "$parent" -maxdepth 1 -type f -name '.p2t2c-candidate-*' -print -quit 2>/dev/null || true)"
      elif grep -q '^status: applied$' "$parent/$id.md" 2>/dev/null; then
        marker="$parent/$id.md"
      fi
      [[ -n "$marker" ]] && break
      sleep 0.01
    done
    if [[ -z "$marker" ]]; then wait "$runner_pid" 2>/dev/null || true; fail "$phase close fixture did not observe its pause marker"; fi
    mv "$parent" "$parked"
    ln -s "$victim" "$parent"
    set +e; wait "$runner_pid"; runner_status=$?; set -e
    [[ "$runner_status" -ne 0 ]] || fail "$phase target-parent swap unexpectedly closed"
    target_inventory "$victim" > "$victim_after"
    assert_target_inventory_equal "$victim_before" "$victim_after" "$phase close target-parent victim"
    [[ ! -e "$victim/$id.md" ]] || fail "$phase close target-parent swap wrote a CPK into victim"
    rm -f "$parent"
    mv "$parked" "$parent"
    grep -q '^status: ready$' "$parent/$id.md" || fail "$phase close did not restore the original CPK"
    [[ -f "$target/.p2t2c/runs/$id/contract.json" && -f "$target/.p2t2c/runs/$id/events.jsonl" ]] \
      || fail "$phase close removed run state after parent swap"
    close_work "$target" "$id" impacted
    checkpoint_fixture_git "$target" "$phase-target-parent-retry"
  done
}

case_security_truth_digest() { check_truth_hash_contract "$suite_target"; }
case_security_mapping_baseline() { run_unmapped_path_contract "$suite_target"; run_baseline_contracts "$suite_target"; }
case_security_ledger_swap() { run_ledger_symlink_swap_contract "$suite_target"; }
case_security_path_guards() { run_path_and_checker_guards "$suite_target"; checkpoint_fixture_git "$suite_target" security-prerequisites; }
case_security_sidecar_cache_verify() { run_v0141_security_contracts "$suite_target"; }
case_security_close_target_parent_swap() { run_close_target_parent_swap_contract "$suite_target"; }
case_security_install_paths() { run_transaction_safety_contracts "$suite_rel" "$suite_source" security; }

run_security_suite() {
  suite_rel="P2T2C_EN"
  suite_source="$(copy_release_source "$suite_rel" security)"
  suite_target="$tmp_root/security-target"
  install_suite_target "$suite_source" "$suite_target"
  initialize_fixture_git "$suite_target"
  run_registered_cases security neutral_once
}

case_transaction_install_upgrade() { run_transaction_safety_contracts "$suite_rel" "$suite_source" transaction; }
case_transaction_concurrent_close() {
  suite_target="$tmp_root/transaction-close-target"
  install_suite_target "$suite_source" "$suite_target"
  initialize_fixture_git "$suite_target"
  run_concurrent_close_contract "$suite_target"
  checkpoint_fixture_git "$suite_target" concurrent-close
}
case_transaction_atomic_close() { run_atomic_close_contract "$suite_target"; }

run_transaction_suite() {
  suite_rel="P2T2C_EN"
  suite_source="$(copy_release_source "$suite_rel" transaction)"
  suite_target=""
  run_registered_cases transaction neutral_once
}

case_locale_release_parity() { run_parity_preflight; }

release_root_has_safe_active_run() {
  local release_root="$1" work_id="$2" run_dir="$1/.p2t2c/runs/$2"
  [[ -f "$release_root/docs/change_packs/$work_id.md" && ! -L "$release_root/docs/change_packs/$work_id.md" ]] || return 1
  [[ -d "$run_dir" && ! -L "$run_dir" ]] || return 1
  [[ -f "$run_dir/contract.json" && ! -L "$run_dir/contract.json" ]] || return 1
  [[ -f "$run_dir/events.jsonl" && ! -L "$run_dir/events.jsonl" ]] || return 1
}

release_checker_mode() {
  local release_root="$1"
  if [[ -n "$pre_close_work_id" ]] && release_root_has_safe_active_run "$release_root" "$pre_close_work_id"; then
    echo preclose
  else
    echo normal
  fi
}

release_checker_arguments() {
  local release_root="$1"
  [[ "$(release_checker_mode "$release_root")" == "preclose" ]] && printf '%s\n' "--pre-close-work-id" "$pre_close_work_id"
}

check_preclose_routing_contract() {
  local fixture="$tmp_root/preclose-routing" en="$tmp_root/preclose-routing/EN" cn="$tmp_root/preclose-routing/CN"
  local work_id="CPK-preclose-routing" saved="$pre_close_work_id" stub="$tmp_root/preclose-routing/checker-stub.sh"
  local record="$tmp_root/preclose-routing/calls.log" arg
  local -a checker_args=()
  mkdir -p "$en/docs/change_packs" "$en/.p2t2c/runs" "$cn/docs/change_packs" "$cn/.p2t2c/runs/$work_id"
  printf '%s\n' '# CPK routing fixture' > "$en/docs/change_packs/$work_id.md"
  printf '%s\n' '# CPK routing fixture' > "$cn/docs/change_packs/$work_id.md"
  printf '%s\n' '{}' > "$cn/.p2t2c/runs/$work_id/contract.json"
  printf '%s\n' '{}' > "$cn/.p2t2c/runs/$work_id/events.jsonl"
  pre_close_work_id="$work_id"
  [[ "$(release_checker_mode "$en")" == "normal" ]] || fail "CPK-only release root incorrectly selected pre-close mode"
  [[ "$(release_checker_mode "$cn")" == "preclose" ]] || fail "safe active-run release root did not select pre-close mode"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s:%s\n" "$P2T2C_STUB_LABEL" "$*" >> "$P2T2C_STUB_RECORD"' > "$stub"
  chmod 0755 "$stub"
  checker_args=(); while IFS= read -r arg; do [[ -n "$arg" ]] && checker_args+=("$arg"); done < <(release_checker_arguments "$en")
  P2T2C_STUB_LABEL=EN P2T2C_STUB_RECORD="$record" bash "$stub" ${checker_args[@]+"${checker_args[@]}"}
  checker_args=(); while IFS= read -r arg; do [[ -n "$arg" ]] && checker_args+=("$arg"); done < <(release_checker_arguments "$cn")
  P2T2C_STUB_LABEL=CN P2T2C_STUB_RECORD="$record" bash "$stub" ${checker_args[@]+"${checker_args[@]}"}
  grep -qx 'EN:' "$record" || fail "CPK-only root did not invoke ordinary checker arguments"
  grep -qx "CN:--pre-close-work-id $work_id" "$record" || fail "active-run root did not invoke pre-close checker arguments"
  ln -s "$cn/.p2t2c/runs/$work_id" "$en/.p2t2c/runs/$work_id"
  [[ "$(release_checker_mode "$en")" == "normal" ]] || fail "symlinked active run incorrectly selected pre-close mode"
  pre_close_work_id="$saved"
}

check_make_preclose_routing_contract() {
  local fixture="$tmp_root/make-preclose-routing" en="$tmp_root/make-preclose-routing/EN" cn="$tmp_root/make-preclose-routing/CN"
  local work_id="CPK-make-preclose" record="$tmp_root/make-preclose-routing/calls.log" stub
  for root in "$en" "$cn"; do
    mkdir -p "$root/.p2t2c/bin" "$root/.p2t2c/runs" "$root/docs/change_packs"
    printf '%s\n' '# CPK make routing fixture' > "$root/docs/change_packs/$work_id.md"
    stub="$root/.p2t2c/bin/check_p2t2c.sh"
    cat > "$stub" <<'EOF'
#!/usr/bin/env bash
printf '%s:%s\n' "$P2T2C_STUB_LABEL" "$*" >> "$P2T2C_STUB_RECORD"
EOF
    chmod 0755 "$stub"
  done
  mkdir -p "$cn/.p2t2c/runs/$work_id"
  printf '%s\n' '{}' > "$cn/.p2t2c/runs/$work_id/contract.json"
  printf '%s\n' '{}' > "$cn/.p2t2c/runs/$work_id/events.jsonl"
  (cd "$en" && P2T2C_STUB_LABEL=EN P2T2C_STUB_RECORD="$record" bash "$repo_root/scripts/release_make_check.sh" "$work_id") >/dev/null
  (cd "$cn" && P2T2C_STUB_LABEL=CN P2T2C_STUB_RECORD="$record" bash "$repo_root/scripts/release_make_check.sh" "$work_id") >/dev/null
  (cd "$cn" && P2T2C_STUB_LABEL=UNSAFE P2T2C_STUB_RECORD="$record" bash "$repo_root/scripts/release_make_check.sh" '../bad') >/dev/null
  ln -s "$cn/.p2t2c/runs/$work_id" "$en/.p2t2c/runs/$work_id"
  (cd "$en" && P2T2C_STUB_LABEL=SYMLINK P2T2C_STUB_RECORD="$record" bash "$repo_root/scripts/release_make_check.sh" "$work_id") >/dev/null
  grep -qx 'EN:' "$record" || fail "EN CPK-only make route did not use ordinary checker"
  grep -qx "CN:--pre-close-work-id $work_id" "$record" || fail "CN active-run make route did not use pre-close checker"
  grep -qx 'UNSAFE:' "$record" || fail "unsafe make WORK_ID received an exemption"
  grep -qx 'SYMLINK:' "$record" || fail "symlinked make run received an exemption"
  grep -Fq 'check WORK_ID="$(WORK_ID)"' "$repo_root/Makefile" || fail "root Makefile does not propagate WORK_ID"
  grep -Fq 'release_make_check.sh "$(WORK_ID)"' "$repo_root/P2T2C_EN/Makefile" || fail "EN Makefile does not use release check routing"
  grep -Fq 'release_make_check.sh "$(WORK_ID)"' "$repo_root/P2T2C_CN/Makefile" || fail "CN Makefile does not use release check routing"
}

case_locale_release_metadata() {
  if [[ "$(release_checker_mode "$suite_release_root")" == "preclose" ]]; then
    local arg
    local -a checker_args=()
    while IFS= read -r arg; do [[ -n "$arg" ]] && checker_args+=("$arg"); done < <(release_checker_arguments "$suite_release_root")
    make -C "$suite_release_root" managed-files >/dev/null
    (cd "$suite_release_root" && bash .p2t2c/bin/check_p2t2c.sh ${checker_args[@]+"${checker_args[@]}"} >/dev/null)
  else
    make -C "$suite_release_root" check >/dev/null
  fi
  make -C "$suite_release_root" checksums >/dev/null
}
case_locale_fresh_install() {
  mkdir -p "$suite_target"
  make -C "$suite_release_root" p2t2c-install-dry-run TARGET="$suite_target" >/dev/null
  make -C "$suite_release_root" p2t2c-install TARGET="$suite_target" >/dev/null
  assert_installed_assets "$suite_release_root" "$suite_target"
}
case_locale_compact_config() {
  local config_backup="$tmp_root/locale-$suite_rel-project-config.backup" negative_log="$tmp_root/locale-$suite_rel-expected-failure.log"
  cp "$suite_target/.p2t2c/project_config.yaml" "$config_backup"
  cat >> "$suite_target/.p2t2c/project_config.yaml" <<'EOF'

verification:
  full:
    commands:
      - id: "partial-override-must-fail"
        run: "true"
EOF
  expect_checker_failure "$suite_target" "$suite_rel explicit incomplete verification override"
  grep -Eqi 'override|verification|profile|path_mapping|complete' "$negative_log" \
    || fail "$suite_rel incomplete override failed for an unrelated reason"
  cp "$config_backup" "$suite_target/.p2t2c/project_config.yaml"
  (cd "$suite_target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null)
  mv "$suite_target/.p2t2c/project_config.yaml" "$suite_target/.p2t2c/project_config.saved.yaml"
  (cd "$suite_target" && bash .p2t2c/bin/check_p2t2c.sh >/dev/null)
  mv "$suite_target/.p2t2c/project_config.saved.yaml" "$suite_target/.p2t2c/project_config.yaml"
}

run_locale_worker() {
  suite_rel="$1"
  suite_release_root="$repo_root/$suite_rel"
  suite_target="$tmp_root/locale-$suite_rel-target"
  run_registered_cases locale bilingual_parallel
}

case_migration_013() { run_upgrade_013_contract "$suite_rel" "$suite_source"; }
case_migration_014() { run_upgrade_014_contract "$suite_rel" "$suite_source"; }
run_migration_worker() {
  suite_rel="$1"
  suite_source="$(copy_release_source "$suite_rel" migration)"
  run_registered_cases migration bilingual_parallel
}

run_language_suite() {
  local worker="$1" label="$2" rel status=0 pid log
  local -a rels=() pids=() labels=()
  case "$language" in en) rels=(P2T2C_EN) ;; cn) rels=(P2T2C_CN) ;; both) rels=(P2T2C_EN P2T2C_CN) ;; esac
  mkdir -p "$tmp_root/logs/$label"
  if [[ "$jobs" -eq 1 || "${#rels[@]}" -eq 1 ]]; then
    for rel in "${rels[@]}"; do
      log="$tmp_root/logs/$label/$rel.log"
      (trap - EXIT; "$worker" "$rel") >"$log" 2>&1 &
      pid=$!
      if wait "$pid"; then
        echo "PASS $label $rel"
      else
        status=1
        echo "FAIL $label $rel; log: $log" >&2
        safe_tail "$log" >&2
      fi
    done
  else
    for rel in "${rels[@]}"; do
      log="$tmp_root/logs/$label/$rel.log"
      (trap - EXIT; "$worker" "$rel") >"$log" 2>&1 &
      pids+=("$!")
      labels+=("$rel")
    done
    for ((i=0; i<${#pids[@]}; i++)); do
      log="$tmp_root/logs/$label/${labels[$i]}.log"
      if wait "${pids[$i]}"; then
        echo "PASS $label ${labels[$i]}"
      else
        status=1
        echo "FAIL $label ${labels[$i]}; log: $log" >&2
        safe_tail "$log" >&2
      fi
    done
  fi
  return "$status"
}

run_locale_suite() {
  suite_rel="repo"
  run_registered_cases locale repo_once
  run_language_suite run_locale_worker locale
}

run_migration_suite() {
  run_language_suite run_migration_worker migration
}

wait_current_pool() {
  local i child_log
  for ((i=0; i<${#pids[@]}; i++)); do
    child_log="$tmp_root/logs/$orchestration_label/${labels[$i]}.log"
    if wait "${pids[$i]}"; then
      echo "PASS ${labels[$i]}"
    else
      status=1
      echo "FAIL ${labels[$i]}; log: $child_log" >&2
      safe_tail "$child_log" >&2
    fi
  done
  pids=(); labels=(); count=0
}

selected_contains() {
  local wanted="$1" item
  shift
  for item in "$@"; do [[ "$item" == "$wanted" ]] && return 0; done
  return 1
}

start_child_suite() {
  local child_suite="$1" child_log="$tmp_root/logs/$orchestration_label/$1.log"
  local -a child_args=(--suite "$child_suite" --jobs "$jobs")
  [[ "$child_suite" == "migration" || "$child_suite" == "locale" ]] && child_args+=(--language both)
  [[ -n "$pre_close_work_id" ]] && child_args+=(--pre-close-work-id "$pre_close_work_id")
  [[ "$keep_smoke" == "1" ]] && child_args+=(--keep)
  bash "$repo_root/scripts/release_smoke_test.sh" "${child_args[@]}" >"$child_log" 2>&1 &
  pids+=("$!"); labels+=("$child_suite"); count=$((count+1))
}

run_selected_suites() {
  local orchestration_label="$1" child_suite status=0 count=0
  shift
  local -a selected=("$@") pids=() labels=()
  mkdir -p "$tmp_root/logs/$orchestration_label"

  for child_suite in contract security transaction; do
    selected_contains "$child_suite" "${selected[@]}" || continue
    start_child_suite "$child_suite"
    [[ "$count" -lt "$jobs" ]] || wait_current_pool
  done
  [[ "${#pids[@]}" -eq 0 ]] || wait_current_pool

  for child_suite in migration locale; do
    selected_contains "$child_suite" "${selected[@]}" || continue
    start_child_suite "$child_suite"
    wait_current_pool
  done
  return "$status"
}

run_all_suite() {
  if [[ "$jobs" -ge 3 ]]; then run_all_lanes; else run_selected_suites all contract security transaction migration locale; fi
}

run_lane() {
  local lane="$1" child_suite child_log="$tmp_root/logs/all/$1.log"
  shift
  : > "$child_log"
  for child_suite in "$@"; do
    local -a lane_args=(--suite "$child_suite" --jobs 1)
    [[ "$child_suite" == "migration" || "$child_suite" == "locale" ]] && lane_args+=(--language both)
    [[ -n "$pre_close_work_id" ]] && lane_args+=(--pre-close-work-id "$pre_close_work_id")
    [[ "$keep_smoke" == "1" ]] && lane_args+=(--keep)
    bash "$repo_root/scripts/release_smoke_test.sh" "${lane_args[@]}" >> "$child_log" 2>&1
  done
}

run_all_lanes() {
  local status=0 index log
  local -a lane_pids=() lane_names=(transaction contract-migration security-locale)
  mkdir -p "$tmp_root/logs/all"
  (trap - EXIT; run_lane transaction transaction) & lane_pids+=("$!")
  (trap - EXIT; run_lane contract-migration contract migration) & lane_pids+=("$!")
  (trap - EXIT; run_lane security-locale security locale) & lane_pids+=("$!")
  for ((index=0; index<${#lane_pids[@]}; index++)); do
    log="$tmp_root/logs/all/${lane_names[$index]}.log"
    if wait "${lane_pids[$index]}"; then echo "PASS lane ${lane_names[$index]}"; else status=1;echo "FAIL lane ${lane_names[$index]}; log: $log" >&2;safe_tail "$log" >&2;fi
  done
  return "$status"
}

run_daily_suite() {
  local selected_text path
  local -a selected=()
  collect_daily_paths
  if [[ "${#changed_paths[@]}" -eq 0 ]]; then
    echo "P2T2C daily selector: no changed paths."
    return 0
  fi
  selected_text="$(select_daily_suites_for_paths "${changed_paths[@]}")"
  while IFS= read -r path; do [[ -n "$path" ]] && selected+=("$path"); done <<< "$selected_text"
  echo "P2T2C daily selector: ${selected[*]}"
  run_selected_suites daily "${selected[@]}"
}

check_smoke_coverage
if [[ "$coverage_only" -eq 1 ]]; then
  echo "P2T2C smoke coverage preflight passed."
  exit 0
fi

run_parity_preflight

if [[ "$suite" == "all" ]]; then
  run_all_suite
elif [[ "$suite" == "daily" ]]; then
  run_daily_suite
else
  mkdir -p "$tmp_root/logs"
  suite_log="$tmp_root/logs/$suite.log"
  case "$suite" in
    contract) suite_runner=run_contract_suite ;;
    security) suite_runner=run_security_suite ;;
    transaction) suite_runner=run_transaction_suite ;;
    migration) suite_runner=run_migration_suite ;;
    locale) suite_runner=run_locale_suite ;;
  esac
  (trap - EXIT; "$suite_runner") >"$suite_log" 2>&1 &
  suite_pid=$!
  if wait "$suite_pid"; then
    :
  else
    echo "FAIL $suite; log: $suite_log" >&2
    safe_tail "$suite_log" >&2
    exit 1
  fi
fi

echo "P2T2C release smoke suite '$suite' passed."
