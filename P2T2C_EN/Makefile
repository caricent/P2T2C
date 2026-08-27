.PHONY: check managed-files checksums p2t2c-verify p2t2c-install-dry-run p2t2c-install p2t2c-upgrade-dry-run p2t2c-upgrade p2t2c-rollback
check: managed-files
	bash ../scripts/release_make_check.sh "$(WORK_ID)"

managed-files:
	@set -eu; \
	manifest=".p2t2c/managed-files.txt"; \
	managed_tmp="$$(mktemp "$${TMPDIR:-/tmp}/p2t2c-managed.XXXXXX")"; \
	checksum_tmp="$$(mktemp "$${TMPDIR:-/tmp}/p2t2c-checksum.XXXXXX")"; \
	lock_tmp="$$(mktemp "$${TMPDIR:-/tmp}/p2t2c-lock.XXXXXX")"; \
	trap 'rm -f "$$managed_tmp" "$$checksum_tmp" "$$lock_tmp"' EXIT; \
	awk '{ line=$$0; gsub(/^[[:space:]]+|[[:space:]]+$$/, "", line); if (line != "" && line !~ /^#/) print line }' "$$manifest" > "$$managed_tmp"; \
	test "$$(wc -l < "$$managed_tmp" | tr -d ' ')" = "$$(LC_ALL=C sort -u "$$managed_tmp" | wc -l | tr -d ' ')"; \
	while IFS= read -r rel; do test -f "$$rel" || { echo "ERROR: managed file missing: $$rel" >&2; exit 1; }; done < "$$managed_tmp"; \
	default_mode="$$(awk '$$1 == "default" { print $$2 }' .p2t2c/managed-modes.txt)"; \
	test -n "$$default_mode"; \
	while IFS= read -r rel; do \
		expected="$$(awk -v path="$$rel" -v fallback="$$default_mode" '$$1 ~ /^0[0-7][0-7][0-7]$$/ && $$2 == path { chosen=$$1 } END { if (length(chosen)>0) print chosen; else print fallback }' .p2t2c/managed-modes.txt)"; \
		actual="$$(perl -e '@s=stat($$ARGV[0]); printf "%04o\n", $$s[2] & 07777' "$$rel")"; \
		test "$$actual" = "$$expected" || { echo "ERROR: managed mode mismatch: $$rel expected=$$expected actual=$$actual" >&2; exit 1; }; \
	done < "$$managed_tmp"; \
	awk '$$0 != ".p2t2c/CHECKSUMS.sha256" { print $$0 }' "$$managed_tmp" > "$$checksum_tmp"; \
	awk '{ print $$2 }' .p2t2c/CHECKSUMS.sha256 > "$$lock_tmp"; \
	diff -u "$$checksum_tmp" "$$lock_tmp"; \
	awk '{ print $$2 }' .p2t2c/lock.sha256 > "$$lock_tmp"; \
	diff -u "$$managed_tmp" "$$lock_tmp"

checksums: managed-files
	shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
	shasum -a 256 -c .p2t2c/lock.sha256

p2t2c-verify:
	@if [ -z "$(WORK_ID)" ]; then echo "ERROR: set WORK_ID=CPK-..."; exit 2; fi
	@if [ -z "$(PROFILE)" ]; then echo "ERROR: set PROFILE=fast|impacted|full|governance"; exit 2; fi
	./.p2t2c/bin/p2t2c verify --work-id "$(WORK_ID)" --profile "$(PROFILE)" $(if $(JOBS),--jobs "$(JOBS)",)

p2t2c-install-dry-run:
	@if [ -z "$(TARGET)" ]; then echo "ERROR: set TARGET=/path/to/project"; exit 2; fi
	bash .p2t2c/bin/p2t2c_install.sh --dry-run --target "$(TARGET)"

p2t2c-install:
	@if [ -z "$(TARGET)" ]; then echo "ERROR: set TARGET=/path/to/project"; exit 2; fi
	bash .p2t2c/bin/p2t2c_install.sh --apply --target "$(TARGET)"

p2t2c-upgrade-dry-run:
	@if [ -z "$(SOURCE)" ]; then echo "ERROR: set SOURCE=/path/to/p2t2c-release"; exit 2; fi
	bash .p2t2c/bin/p2t2c_upgrade.sh --dry-run --source "$(SOURCE)"

p2t2c-upgrade:
	@if [ -z "$(SOURCE)" ]; then echo "ERROR: set SOURCE=/path/to/p2t2c-release"; exit 2; fi
	bash .p2t2c/bin/p2t2c_upgrade.sh --apply --source "$(SOURCE)"

p2t2c-rollback:
	@if [ -z "$(UPGRADE)" ]; then echo "ERROR: set UPGRADE=.p2t2c/upgrade/{id}"; exit 2; fi
	bash .p2t2c/bin/p2t2c_upgrade.sh --rollback "$(UPGRADE)"
