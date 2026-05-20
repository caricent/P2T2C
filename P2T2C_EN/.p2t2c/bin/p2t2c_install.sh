#!/usr/bin/env bash
set -eo pipefail

usage() {
  cat <<'EOF'
Usage:
  .p2t2c/bin/p2t2c_install.sh --dry-run --target PATH
  .p2t2c/bin/p2t2c_install.sh --apply --target PATH

Run from the P2T2C source repository.
EOF
}

mode=""
target_dir=""

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
    --target)
      target_dir="${2:-}"
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

if [[ "$mode" != "dry-run" && "$mode" != "apply" ]]; then
  echo "ERROR: choose --dry-run or --apply" >&2
  usage
  exit 2
fi

if [[ -z "$target_dir" ]]; then
  echo "ERROR: --target PATH is required" >&2
  usage
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
source_root="$(cd "$script_dir/../.." && pwd)"
mkdir -p "$target_dir"
target_root="$(cd "$target_dir" && pwd)"

INSTALL_FILES=(
  ".p2t2c/manifest.yaml"
  ".p2t2c/ownership.yaml"
  "P2T2C_AGENTS.md"
  ".p2t2c/CHECKSUMS.sha256"
  ".p2t2c/VERSION"
  "P2T2C_README.md"
  ".p2t2c/P2T2C_LICENSE.md"
  "docs/adr/README.md"
  "docs/change_proposals/CP_TEMPLATE.md"
  "docs/change_proposals/README.md"
  "docs/closure/README.md"
  "docs/reference/README.md"
  "docs/sot/governance/P2T2C_GOVERNANCE.md"
  "docs/sot/manifest.yaml"
  ".p2t2c/templates/project_config.example.yaml"
  "specs/README.md"
  ".p2t2c/bin/check_p2t2c.sh"
  ".p2t2c/bin/p2t2c_install.sh"
  ".p2t2c/bin/p2t2c_upgrade.sh"
  ".p2t2c/migrations/0.1.0-to-0.2.0.md"
  ".p2t2c/migrations/0.2.0-to-0.3.0.md"
  ".p2t2c/migrations/0.3.0-to-0.4.0.md"
  ".p2t2c/migrations/0.4.0-to-0.5.0.md"
  ".p2t2c/migrations/0.5.0-to-0.6.0.md"
  ".p2t2c/migrations/0.6.0-to-0.7.0.md"
  ".p2t2c/migrations/README.md"
  ".p2t2c/prompts/01_bootstrap_repository_prompt.md"
  ".p2t2c/prompts/02_generate_change_pack_prompt.md"
  ".p2t2c/prompts/03_apply_change_pack_prompt.md"
  ".p2t2c/prompts/04_generate_execution_pack_prompt.md"
  ".p2t2c/prompts/05_execute_single_task_prompt.md"
  ".p2t2c/prompts/06_acceptance_and_closure_prompt.md"
  ".p2t2c/templates/adr/ADR_TEMPLATE.md"
  ".p2t2c/templates/change_pack/CHANGE_PACK_TEMPLATE.md"
  ".p2t2c/templates/closure/CLOSURE_REPORT_TEMPLATE.md"
  ".p2t2c/templates/execution/plan.md"
  ".p2t2c/templates/execution/spec.md"
  ".p2t2c/templates/execution/tasks.md"
  ".p2t2c/templates/install/INSTALL_REPORT_TEMPLATE.md"
  ".p2t2c/templates/truth/RULE_BLOCK_TEMPLATE.md"
  ".p2t2c/templates/truth/SOT_DOCUMENT_TEMPLATE.md"
  ".p2t2c/templates/upgrade/TEMPLATE_UPGRADE_PACK_TEMPLATE.md"
)

MANAGED_LOCK_FILES=("${INSTALL_FILES[@]}")

is_denied() {
  case "$1" in
    src/*|tests/*|database/*|package.json|docs/adr/ADR-*.md|docs/change_proposals/CP-*.md|docs/closure/CR-*.md|specs/*/*)
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

write_lock() {
  local tmp="$target_root/.p2t2c/lock.sha256.tmp"
  mkdir -p "$target_root/.p2t2c"
  : > "$tmp"
  local rel
  for rel in "${MANAGED_LOCK_FILES[@]}"; do
    if [[ -f "$target_root/$rel" ]]; then
      printf "%s  %s\n" "$(sha256_file "$target_root/$rel")" "$rel" >> "$tmp"
    fi
  done
  mv "$tmp" "$target_root/.p2t2c/lock.sha256"
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

installed=()
unchanged=()
conflicts=()
skipped=()
missing_source=()

already_installed=0
if [[ -f "$target_root/.p2t2c/manifest.yaml" ]]; then
  already_installed=1
fi

if [[ "$already_installed" -eq 1 ]]; then
  echo "P2T2C install"
  echo "Mode: $mode"
  echo "Source: $source_root"
  echo "Target: $target_root"
  echo
  echo "Project already uses P2T2C; use upgrade instead."
  if [[ "$mode" == "dry-run" ]]; then
    exit 0
  fi
  echo
  echo "Install stopped. Use p2t2c-upgrade for this project."
  exit 1
fi

for rel in "${INSTALL_FILES[@]}"; do
  if is_denied "$rel"; then
    skipped+=("$rel (denylist)")
    continue
  fi

  if [[ ! -f "$source_root/$rel" ]]; then
    missing_source+=("$rel")
    continue
  fi

  if [[ ! -f "$target_root/$rel" ]]; then
    installed+=("$rel")
    continue
  fi

  if [[ "$(sha256_file "$source_root/$rel")" == "$(sha256_file "$target_root/$rel")" ]]; then
    unchanged+=("$rel")
  else
    conflicts+=("$rel")
  fi
done

echo "P2T2C install"
echo "Mode: $mode"
echo "Source: $source_root"
echo "Target: $target_root"

print_list "Installed" "${installed[@]}"
print_list "Unchanged" "${unchanged[@]}"
print_list "Conflicts" "${conflicts[@]}"
print_list "Skipped denied paths" "${skipped[@]}"
print_list "Missing from source" "${missing_source[@]}"

if [[ "$mode" == "dry-run" ]]; then
  exit 0
fi

install_id="$(date +%Y%m%d-%H%M%S)"
install_dir="$target_root/.p2t2c/install/$install_id"
mkdir -p "$install_dir"

for rel in "${installed[@]}"; do
  [[ -z "$rel" ]] && continue
  mkdir -p "$target_root/$(dirname "$rel")"
  cp "$source_root/$rel" "$target_root/$rel"
done

write_lock

validation="not run"
if [[ "${#conflicts[@]}" -gt 0 ]]; then
  validation="not run due unresolved install conflicts"
elif [[ -f "$target_root/.p2t2c/bin/check_p2t2c.sh" ]]; then
  if (cd "$target_root" && bash .p2t2c/bin/check_p2t2c.sh >/tmp/p2t2c-install-check.log 2>&1); then
    validation="bash .p2t2c/bin/check_p2t2c.sh: passed"
  else
    validation="bash .p2t2c/bin/check_p2t2c.sh: failed; see /tmp/p2t2c-install-check.log"
  fi
fi

{
  echo "# P2T2C Install Report — $install_id"
  echo
  echo "Status: APPLIED"
  echo "Source: \`$source_root\`"
  echo "Target: \`$target_root\`"
  echo
  echo "## Installed"
  if [[ "${#installed[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${installed[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Unchanged"
  if [[ "${#unchanged[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${unchanged[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Conflicts"
  if [[ "${#conflicts[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${conflicts[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Skipped denied paths"
  if [[ "${#skipped[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for rel in "${skipped[@]}"; do
      echo "- $rel"
    done
  fi
  echo
  echo "## Validation"
  echo "- $validation"
  echo
  echo "## Suggested manual integration"
  echo
  if [[ "${#conflicts[@]}" -eq 0 ]]; then
    echo "- None"
  else
    echo "- Existing files were not overwritten."
    echo "- If an AI tool only auto-loads root-level AGENTS.md, reference P2T2C_AGENTS.md from the project-owned AGENTS.md."
    echo "- Keep existing project README and Makefile unchanged."
    echo "- Link to P2T2C_README.md from project docs if needed."
  fi
} > "$install_dir/install-report.md"

echo
echo "Install applied."
echo "Report: $install_dir/install-report.md"
echo "$validation"
