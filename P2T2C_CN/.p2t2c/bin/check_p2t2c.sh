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
  "docs/submit_proposals/SP_TEMPLATE.md"
  "docs/submit_proposals/README.md"
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
  ".p2t2c/migrations/0.1.0-to-0.2.0.md"
  ".p2t2c/migrations/0.2.0-to-0.3.0.md"
  ".p2t2c/migrations/0.3.0-to-0.4.0.md"
  ".p2t2c/migrations/0.4.0-to-0.5.0.md"
  ".p2t2c/migrations/0.5.0-to-0.6.0.md"
  ".p2t2c/migrations/0.6.0-to-0.7.0.md"
  ".p2t2c/migrations/0.7.0-to-0.8.0.md"
  ".p2t2c/migrations/0.8.0-to-0.8.1.md"
  ".p2t2c/migrations/0.8.1-to-0.9.0.md"
  ".p2t2c/migrations/0.9.0-to-0.10.0.md"
  ".p2t2c/migrations/0.10.0-to-0.10.1.md"
  ".p2t2c/prompts/01_bootstrap_repository_prompt.md"
  ".p2t2c/prompts/02_generate_change_pack_prompt.md"
  ".p2t2c/prompts/03_apply_change_pack_prompt.md"
  ".p2t2c/prompts/04_generate_execution_pack_prompt.md"
  ".p2t2c/prompts/05_execute_single_task_prompt.md"
  ".p2t2c/prompts/06_acceptance_and_closure_prompt.md"
  ".p2t2c/templates/adr/ADR_TEMPLATE.md"
  ".p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md"
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

for migration in ".p2t2c/migrations/0.2.0-to-0.3.0.md" ".p2t2c/migrations/0.5.0-to-0.6.0.md" ".p2t2c/migrations/0.6.0-to-0.7.0.md" ".p2t2c/migrations/0.8.0-to-0.8.1.md"; do
  while IFS= read -r obsolete; do
    [[ -z "$obsolete" ]] && continue
    locked_hash="$(managed_lock_hash "$obsolete" || true)"
    if [[ -n "$locked_hash" && -e "$obsolete" ]]; then
      echo "ERROR: obsolete file still exists: $obsolete"
      missing=1
    fi
    if [[ "$obsolete" == */* ]]; then
      matches="$(grep -rnF --exclude-dir=.git --exclude-dir=migrations --exclude-dir=reference -e "$obsolete" . || true)"
      matches="$(printf "%s\n" "$matches" | grep -v -- ".p2t2c/$obsolete" || true)"
      if [[ -n "$matches" ]]; then
        echo "ERROR: obsolete file is referenced outside migration notes: $obsolete"
        missing=1
      fi
    fi
  done < <(obsolete_list "$migration")
done

# SP and ADR instance files are project-owned artifacts. They are valid in
# installed projects, so the shared checker must not reject them.

language="unknown"
if [[ -f "docs/sot/manifest.yaml" ]]; then
  language="$(awk -F': *' '$1 == "language" {print $2; exit}' docs/sot/manifest.yaml)"
fi

check_phrase ".p2t2c/VERSION" "0.10.1"
check_phrase "docs/sot/manifest.yaml" "language_policy: monolingual_release_root"
check_phrase ".p2t2c/manifest.yaml" "version: \"0.10.1\""
check_phrase ".p2t2c/manifest.yaml" "language_policy: \"monolingual_release_root\""
check_phrase ".p2t2c/P2T2C_LICENSE.md" "MIT License"
check_phrase ".p2t2c/P2T2C_LICENSE.md" "Copyright (c) 2026 Caricent"
check_phrase ".p2t2c/P2T2C_LICENSE.md" "jasonbaoly"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-006"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-007"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-009"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-010"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-011"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "RULE-GOV-012"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE.md" "Phases:"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md" "Superseded by"
check_phrase "docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md" "RULE-GOV-005"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "--dry-run"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "--rollback"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "0.8.0-to-0.8.1.md"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "0.8.1-to-0.9.0.md"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "0.9.0-to-0.10.0.md"
check_phrase ".p2t2c/bin/p2t2c_upgrade.sh" "0.10.0-to-0.10.1.md"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "--target"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "0.8.0-to-0.8.1.md"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "0.8.1-to-0.9.0.md"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "0.9.0-to-0.10.0.md"
check_phrase ".p2t2c/bin/p2t2c_install.sh" "0.10.0-to-0.10.1.md"
check_phrase ".p2t2c/templates/change_packs/CHANGE_PACK_TEMPLATE.md" "Truth Patch Candidate: Not generated"
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
  "docs/submit_proposals/README.md"
  "docs/submit_proposals/SP_TEMPLATE.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/manifest.yaml"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/governance/P2T2C_GOVERNANCE_HISTORY.md"
  "specs/README.md"
  ".p2t2c/migrations"
  ".p2t2c/prompts"
  ".p2t2c/templates"
)

managed_docs_match_perl() {
  local regex="$1"
  perl -MFile::Find -CSD -e '
    my $regex = shift @ARGV;
    my $re = qr($regex);
    my $found = 0;
    find({ wanted => sub {
      return if $found || !-f $_;
      open my $fh, "<:encoding(UTF-8)", $_ or return;
      while (my $line = <$fh>) {
        if ($line =~ $re) { $found = 1; last; }
      }
    }, no_chdir => 1 }, @ARGV);
    exit($found ? 0 : 1);
  ' "$regex" "${managed_doc_globs[@]}" 2>/dev/null
}

if [[ "$language" == "en-US" ]]; then
  check_phrase "P2T2C_README.md" "Human workflow"
  check_phrase "P2T2C_README.md" "English-only"
  check_phrase "P2T2C_AGENTS.md" "This is the only AI entrypoint"
  if managed_docs_match_perl '\p{Han}'; then
    echo "ERROR: English release root contains CJK text in managed docs"
    missing=1
  fi
elif [[ "$language" == "zh-CN" ]]; then
  check_phrase "P2T2C_README.md" "人类工作流"
  check_phrase "P2T2C_README.md" "中文单语"
  check_phrase "P2T2C_AGENTS.md" "AI 操作入口"
  if managed_docs_match_perl ' / .*\p{Han}'; then
    echo "ERROR: Chinese release root contains same-line bilingual pairings"
    missing=1
  fi
else
  echo "ERROR: unknown docs/sot/manifest.yaml language: $language"
  missing=1
fi

# --- RULE-GOV-009: SoT rule identifier integrity ---------------------------
# Scans docs/sot/**/*.md (Active layer + *_HISTORY.md) for Rule Blocks.
# RULE-GOV-012 splits each rule across two files: the Active layer carries
# Status/Phases, the HISTORY layer carries lifecycle metadata. The same
# RULE-ID therefore legitimately appears once per layer; fields are MERGED
# per ID across files (last non-empty value wins). A genuine duplicate is
# two Rule Blocks sharing an ID *within the same file*, which is flagged.
# Validates:
#   - no duplicate RULE-ID within a single file
#   - bidirectional Supersedes / Superseded by links
#   - no dangling lifecycle references
#   - no superseded-yet-Active rule
sot_report="$(
  find docs/sot -type f -name '*.md' 2>/dev/null | sort | while IFS= read -r f; do
    [[ -n "$f" ]] && awk -v fn="$f" '{print fn "\t" $0}' "$f" && printf '\n'
  done | awk -F'\t' '
    function body(line,   s) { s = line; return s }
    function flush() {
      if (cur != "") {
        key = cur SUBSEP headfile
        if (key in seen_in_file) { print "ERROR: duplicate RULE-ID within " headfile ": " cur }
        seen_in_file[key] = 1
        seen[cur] = 1
        if (cur_status   != "") status[cur] = cur_status
        if (cur_sup      != "") sup[cur]    = cur_sup
        if (cur_supby    != "") supby[cur]  = cur_supby
      }
      cur = ""; cur_status = ""; cur_sup = ""; cur_supby = ""
    }
    { curfile = $1; line = $2 }
    line ~ /^###[[:space:]]+RULE-[A-Z]+-[0-9]+/ {
      flush()
      headfile = curfile
      match(line, /RULE-[A-Z]+-[0-9]+/); cur = substr(line, RSTART, RLENGTH)
      next
    }
    cur != "" && line ~ /^Status:/        { s = line; sub(/^Status:[[:space:]]*/, "", s); cur_status = s; next }
    cur != "" && line ~ /^Supersedes:/    { s = line; sub(/^Supersedes:[[:space:]]*/, "", s); gsub(/`/, "", s); cur_sup = s; next }
    cur != "" && line ~ /^Superseded by:/ { s = line; sub(/^Superseded by:[[:space:]]*/, "", s); gsub(/`/, "", s); cur_supby = s; next }
    END {
      flush()
      for (r in seen) {
        if (!(r in sup))   sup[r] = "None"
        if (!(r in supby)) supby[r] = "None"
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
  done < <(grep -rnE "Implements:[[:space:]]*RULE-[A-Z]+-[0-9]+" src 2>/dev/null \
            | grep -oE '^[^:]*:[0-9]*:.*RULE-[A-Z]+-[0-9]+' || true)
fi

# --- RULE-GOV-012: phase-scoped reading map (auto-generated) ---------------
# Parses the `Phases:` field of every Active rule, validates tokens against
# the known phase list, ensures every phase is covered by >=1 rule, and
# regenerates the phase->rule map that prompts read from. The map is derived,
# never hand-maintained: adding a rule with a Phases line updates it here.
known_phases="bootstrap change_pack apply_change_pack execution_pack single_task acceptance install_upgrade all"
gov_active="docs/sot/governance/P2T2C_GOVERNANCE.md"

if [[ -f "$gov_active" ]]; then
  phase_report="$(
    awk -v known="$known_phases" '
      BEGIN { n = split(known, k, /[[:space:]]+/); for (i=1;i<=n;i++) known_set[k[i]] = 1 }
      function finalize_rule() {
        # Called when the current rule block ends (next heading or EOF).
        # An Active rule MUST carry a Phases line; flag if it did not.
        if (cur != "" && cur_status ~ /Active/ && !saw_phases)
          print "ERR\tmissing Phases for Active rule: " cur
      }
      /^###[[:space:]]+RULE-[A-Z]+-[0-9]+/ {
        finalize_rule()
        match($0, /RULE-[A-Z]+-[0-9]+/); cur = substr($0, RSTART, RLENGTH)
        cur_status = ""; saw_phases = 0; next
      }
      cur != "" && /^Status:/ { s=$0; sub(/^Status:[[:space:]]*/,"",s); cur_status=s; next }
      cur != "" && /^Phases:/ { s=$0; sub(/^Phases:[[:space:]]*/,"",s); saw_phases=1
        if (cur_status ~ /Active/) {
          if (s == "") { print "ERR\tempty Phases for Active rule: " cur; next }
          m = split(s, p, /[,[:space:]]+/)
          for (j=1;j<=m;j++) {
            tok=p[j]; if (tok=="") continue
            if (!(tok in known_set)) { print "ERR\tunknown phase token \"" tok "\" in " cur }
            else { print "MAP\t" tok "\t" cur; covered[tok]=1; if (tok=="all") has_all=1 }
          }
        }
        next
      }
      END {
        finalize_rule()
        np = split(known, kk, /[[:space:]]+/)
        # A phase counts as covered if a specific rule names it OR an `all`
        # rule exists (an `all` rule applies to every phase by definition).
        for (i=1;i<=np;i++) if (kk[i] != "all" && !(kk[i] in covered) && !has_all)
          print "ERR\tphase has no rule coverage: " kk[i]
      }
    ' "$gov_active"
  )"

  phase_errs="$(printf "%s\n" "$phase_report" | awk -F'\t' '$1=="ERR"{print $2}')"
  if [[ -n "$phase_errs" ]]; then
    while IFS= read -r e; do [[ -n "$e" ]] && echo "ERROR: RULE-GOV-012: $e"; done <<< "$phase_errs"
    missing=1
  fi

  mkdir -p .p2t2c/generated
  generated_map=".p2t2c/generated/phase_rules.txt"
  all_ids="$(printf "%s\n" "$phase_report" | awk -F'\t' '$1=="MAP" && $2=="all" {print $3}' | sort -u)"
  {
    echo "# Auto-generated by check_p2t2c.sh (RULE-GOV-012). Do not edit by hand."
    echo "# Maps each workflow phase to the Active governance rules an AI must"
    echo "# read in that phase. Rules tagged 'all' are folded into every phase."
    for ph in $known_phases; do
      [[ "$ph" == "all" ]] && continue
      ids="$( { printf "%s\n" "$phase_report" | awk -F'\t' -v p="$ph" '$1=="MAP" && $2==p {print $3}'; printf "%s\n" "$all_ids"; } | sort -u | sed '/^$/d' | paste -sd, - )"
      echo "${ph}: ${ids}"
    done
  } > "$generated_map"
fi

if [[ $missing -eq 0 ]]; then
  echo "P2T2C checks passed."
else
  echo "P2T2C checks failed."
fi
exit $missing
