#!/usr/bin/env bash
set -eo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/p2t2c_upgrade.sh --dry-run --source PATH
  scripts/p2t2c_upgrade.sh --apply --source PATH
  scripts/p2t2c_upgrade.sh --rollback UPGRADE_DIR

Run from the target project root.
EOF
}

mode=""
source_dir=""
rollback_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --apply)
      mode="apply"
      shift
      ;;
    --source)
      source_dir="${2:-}"
      shift 2
      ;;
    --rollback)
      mode="rollback"
      rollback_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

target_root="$(pwd)"

CORE_MANAGED=(
  "prompts/01_bootstrap_repository_prompt.md"
  "prompts/02_generate_change_pack_prompt.md"
  "prompts/03_apply_change_pack_prompt.md"
  "prompts/04_generate_execution_pack_prompt.md"
  "prompts/05_execute_single_task_prompt.md"
  "prompts/06_acceptance_and_closure_prompt.md"
  "templates/change_pack/CHANGE_PACK_TEMPLATE.md"
  "templates/closure/CLOSURE_REPORT_TEMPLATE.md"
  "templates/adr/ADR_TEMPLATE.md"
  "templates/install/INSTALL_REPORT_TEMPLATE.md"
  "templates/truth/SOT_DOCUMENT_TEMPLATE.md"
  "templates/truth/RULE_BLOCK_TEMPLATE.md"
  "templates/upgrade/TEMPLATE_UPGRADE_PACK_TEMPLATE.md"
  "sdd/templates/spec.md"
  "sdd/templates/plan.md"
  "sdd/templates/tasks.md"
  "scripts/check_p2t2c.sh"
  "scripts/p2t2c_install.sh"
  "scripts/p2t2c_upgrade.sh"
  "docs/change_proposals/CP_TEMPLATE.md"
)

GOVERNANCE_MANAGED=(
  "AGENTS.md"
  "CHECKSUMS.sha256"
  "P2T2C_TEMPLATE_VERSION"
  "README.md"
  "P2T2C_LICENSE.md"
  "Makefile"
  "project_config.example.yaml"
  "docs/adr/README.md"
  "docs/change_proposals/README.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/manifest.yaml"
  "specs/README.md"
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  "migrations/p2t2c/README.md"
  "migrations/p2t2c/0.1.0-to-0.2.0.md"
  "migrations/p2t2c/0.2.0-to-0.3.0.md"
  "migrations/p2t2c/0.3.0-to-0.4.0.md"
  "migrations/p2t2c/0.4.0-to-0.5.0.md"
)

ALL_MANAGED=(
  "${CORE_MANAGED[@]}"
  "${GOVERNANCE_MANAGED[@]}"
)

is_project_owned() {
  case "$1" in
    docs/sot/product/*|docs/sot/data/*|docs/sot/api/*|docs/sot/client/*|docs/sot/server/*|docs/sot/ai/*|docs/sot/testing/*)
      return 0
      ;;
    docs/adr/ADR-*.md|docs/change_proposals/CP-*.md|docs/closure/CR-*.md|specs/*/*|src/*|tests/*|database/*|package.json)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

lock_hash_for() {
  local rel="$1"
  local lock_file="$target_root/.p2t2c/lock.sha256"
  if [[ ! -f "$lock_file" ]]; then
    return 1
  fi
  awk -v path="$rel" '$2 == path {print $1}' "$lock_file" | tail -n 1
}

version_from() {
  local root="$1"
  if [[ -f "$root/P2T2C_TEMPLATE_VERSION" ]]; then
    tr -d '[:space:]' < "$root/P2T2C_TEMPLATE_VERSION"
  else
    echo "unknown"
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

print_list() {
  local title="$1"
  shift
  echo
  echo "$title"
  if [[ $# -eq 0 ]]; then
    echo "- None"
    return
  fi
  local item
  for item in "$@"; do
    echo "- $item"
  done
}

write_lock() {
  local tmp="$target_root/.p2t2c/lock.sha256.tmp"
  mkdir -p "$target_root/.p2t2c"
  : > "$tmp"
  local rel
  for rel in "${ALL_MANAGED[@]}"; do
    if [[ -f "$target_root/$rel" ]]; then
      printf "%s  %s\n" "$(sha256_file "$target_root/$rel")" "$rel" >> "$tmp"
    fi
  done
  mv "$tmp" "$target_root/.p2t2c/lock.sha256"
}

rollback() {
  local dir="$1"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "ERROR: rollback directory not found: $dir" >&2
    exit 2
  fi

  if [[ -d "$dir/backup" ]]; then
    (cd "$dir/backup" && find . -type f | while read -r file; do
      local rel="${file#./}"
      mkdir -p "$target_root/$(dirname "$rel")"
      cp "$dir/backup/$rel" "$target_root/$rel"
      echo "restored: $rel"
    done)
  fi

  if [[ -f "$dir/created-files.txt" ]]; then
    while read -r rel; do
      [[ -z "$rel" ]] && continue
      if [[ -f "$target_root/$rel" ]]; then
        chmod u+w "$target_root/$rel" 2>/dev/null || true
        if command -v xattr >/dev/null 2>&1; then
          xattr -d com.apple.provenance "$target_root/$rel" 2>/dev/null || true
        fi
        rm -f "$target_root/$rel"
        echo "removed created file: $rel"
      fi
    done < "$dir/created-files.txt"
  fi

  if [[ -f "$target_root/.p2t2c/manifest.yaml" ]]; then
    write_lock
  fi
}

if [[ "$mode" == "rollback" ]]; then
  rollback "$rollback_dir"
  exit 0
fi

if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
  echo "ERROR: choose --dry-run, --apply, or --rollback" >&2
  usage
  exit 2
fi

if [[ -z "$source_dir" ]]; then
  echo "ERROR: --source PATH is required" >&2
  usage
  exit 2
fi

if [[ ! -d "$source_dir" ]]; then
  echo "ERROR: source directory not found: $source_dir" >&2
  exit 2
fi

source_root="$(cd "$source_dir" && pwd)"
target_version="$(version_from "$target_root")"
source_version="$(version_from "$source_root")"
legacy=0

if [[ ! -f "$target_root/.p2t2c/manifest.yaml" || ! -f "$target_root/.p2t2c/lock.sha256" ]]; then
  legacy=1
fi

updates=()
creates=()
removes=()
unchanged=()
skipped=()
conflicts=()
missing_source=()

for rel in "${ALL_MANAGED[@]}"; do
  if is_project_owned "$rel"; then
    skipped+=("$rel (project-owned denylist)")
    continue
  fi

  if [[ ! -f "$source_root/$rel" ]]; then
    missing_source+=("$rel")
    continue
  fi

  if [[ ! -f "$target_root/$rel" ]]; then
    creates+=("$rel")
    continue
  fi

  source_hash="$(sha256_file "$source_root/$rel")"
  target_hash="$(sha256_file "$target_root/$rel")"
  if [[ "$source_hash" == "$target_hash" ]]; then
    unchanged+=("$rel")
    continue
  fi

  locked_hash="$(lock_hash_for "$rel" || true)"
  if [[ -n "$locked_hash" && "$target_hash" == "$locked_hash" ]]; then
    updates+=("$rel")
  elif [[ "$rel" == "CHECKSUMS.sha256" && -z "$locked_hash" ]]; then
    updates+=("$rel")
  else
    conflicts+=("$rel")
  fi
done

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  if [[ ! -f "$target_root/$rel" ]]; then
    continue
  fi
  target_hash="$(sha256_file "$target_root/$rel")"
  locked_hash="$(lock_hash_for "$rel" || true)"
  if [[ -n "$locked_hash" && "$target_hash" == "$locked_hash" ]]; then
    removes+=("$rel")
  else
    conflicts+=("$rel (obsolete modified)")
  fi
done < <(obsolete_list "$source_root/migrations/p2t2c/0.2.0-to-0.3.0.md")

echo "P2T2C upgrade $target_version -> $source_version"
echo "Mode: $mode"
echo "Target: $target_root"
echo "Source: $source_root"

if [[ "$legacy" -eq 1 ]]; then
  echo
  echo "Legacy review: missing .p2t2c/manifest.yaml or .p2t2c/lock.sha256."
  echo "This script will not directly overwrite a legacy project. Add P2T2C upgrade metadata first or migrate manually with human review."
fi

print_list "Updated automatically" "${updates[@]}" "${creates[@]}"
print_list "Removed obsolete" "${removes[@]}"
print_list "Skipped project-owned" "${skipped[@]}"
print_list "Conflicts" "${conflicts[@]}"
print_list "Missing from source" "${missing_source[@]}"
print_list "Unchanged" "${unchanged[@]}"

if [[ "$mode" == "dry-run" ]]; then
  exit 0
fi

upgrade_id="$(date +%Y%m%d-%H%M%S)"
upgrade_dir="$target_root/.p2t2c/upgrade/$upgrade_id"
mkdir -p "$upgrade_dir/backup" "$upgrade_dir/conflicts"

if [[ "$legacy" -eq 1 ]]; then
  {
    echo "# P2T2C Upgrade Report — $upgrade_id"
    echo
    echo "Status: LEGACY_REVIEW_REQUIRED"
    echo "From: $target_version"
    echo "To: $source_version"
    echo
    echo "The target project is missing P2T2C upgrade metadata. No workflow files were overwritten."
  } > "$upgrade_dir/upgrade-report.md"
  echo
  echo "Apply stopped. Legacy review report: $upgrade_dir/upgrade-report.md"
  exit 1
fi

if [[ "${#conflicts[@]}" -gt 0 ]]; then
  for item in "${conflicts[@]}"; do
    rel="${item%% (*}"
    if [[ -f "$target_root/$rel" ]]; then
      mkdir -p "$upgrade_dir/conflicts/local/$(dirname "$rel")"
      cp "$target_root/$rel" "$upgrade_dir/conflicts/local/$rel"
    fi
    if [[ -f "$source_root/$rel" ]]; then
      mkdir -p "$upgrade_dir/conflicts/source/$(dirname "$rel")"
      cp "$source_root/$rel" "$upgrade_dir/conflicts/source/$rel"
    fi
  done
  {
    echo "# P2T2C Upgrade Report — $upgrade_id"
    echo
    echo "Status: MANUAL_CONFLICT_RESOLUTION_REQUIRED"
    echo "From: $target_version"
    echo "To: $source_version"
    echo
    echo "## Conflicts"
    for rel in "${conflicts[@]}"; do
      echo "- $rel"
    done
    echo
    echo "No workflow files were updated or removed."
  } > "$upgrade_dir/upgrade-report.md"
  echo
  echo "Apply stopped. Conflict report: $upgrade_dir/upgrade-report.md"
  exit 1
fi

: > "$upgrade_dir/updated-files.txt"
: > "$upgrade_dir/created-files.txt"
: > "$upgrade_dir/removed-files.txt"

for rel in "${updates[@]}" "${creates[@]}"; do
  [[ -z "$rel" ]] && continue
  if [[ -f "$target_root/$rel" ]]; then
    mkdir -p "$upgrade_dir/backup/$(dirname "$rel")"
    cp "$target_root/$rel" "$upgrade_dir/backup/$rel"
    echo "$rel" >> "$upgrade_dir/updated-files.txt"
  else
    echo "$rel" >> "$upgrade_dir/created-files.txt"
  fi
  mkdir -p "$target_root/$(dirname "$rel")"
  cp "$source_root/$rel" "$target_root/$rel"
done

for rel in "${removes[@]}"; do
  [[ -z "$rel" ]] && continue
  if [[ -f "$target_root/$rel" ]]; then
    mkdir -p "$upgrade_dir/backup/$(dirname "$rel")"
    cp "$target_root/$rel" "$upgrade_dir/backup/$rel"
    chmod u+w "$target_root/$rel" 2>/dev/null || true
    if command -v xattr >/dev/null 2>&1; then
      xattr -d com.apple.provenance "$target_root/$rel" 2>/dev/null || true
    fi
    rm -f "$target_root/$rel"
    echo "$rel" >> "$upgrade_dir/removed-files.txt"
  fi
done

write_lock

validation="not run"
if [[ -f "$target_root/Makefile" ]]; then
  if (cd "$target_root" && make check >/tmp/p2t2c-upgrade-check.log 2>&1); then
    validation="make check: passed"
  else
    validation="make check: failed; see /tmp/p2t2c-upgrade-check.log"
  fi
fi

{
  echo "# P2T2C Upgrade Report — $upgrade_id"
  echo
  echo "Status: APPLIED"
  echo "From: $target_version"
  echo "To: $source_version"
  echo
  echo "## Updated automatically"
  if [[ "${#updates[@]}" -eq 0 && "${#creates[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${updates[@]}" "${creates[@]}"; do
      [[ -n "$rel" ]] && echo "- $rel"
    done
  fi
  echo
  echo "## Removed obsolete"
  if [[ "${#removes[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${removes[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Skipped project-owned"
  if [[ "${#skipped[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${skipped[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Conflicts"
  echo "- None"
  echo
  echo "## Validation"
  echo "- $validation"
  echo
  echo "## Rollback"
  echo
  echo '```bash'
  echo "make p2t2c-rollback UPGRADE=$upgrade_dir"
  echo '```'
} > "$upgrade_dir/upgrade-report.md"

echo
echo "Upgrade applied."
echo "Report: $upgrade_dir/upgrade-report.md"
echo "$validation"
