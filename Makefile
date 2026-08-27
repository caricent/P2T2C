.PHONY: check check-releases check-en check-cn check-parity checksums smoke smoke-all smoke-daily smoke-contract smoke-security smoke-transaction smoke-migration smoke-locale smoke-coverage refresh-release-metadata

SMOKE_WORK_ARG = $(if $(WORK_ID),--pre-close-work-id "$(WORK_ID)",)
BASE ?= HEAD
SMOKE_JOBS ?= 3

check: check-releases check-parity smoke-coverage

check-releases:
	$(MAKE) -j2 check-en check-cn

check-en:
	$(MAKE) -C P2T2C_EN check WORK_ID="$(WORK_ID)"

check-cn:
	$(MAKE) -C P2T2C_CN check WORK_ID="$(WORK_ID)"

check-parity:
	@set -eu; work_id="$(WORK_ID)"; \
	if printf '%s\n' "$$work_id" | grep -Eq '^CPK-[A-Za-z0-9._-]+$$'; then \
		bash scripts/check_release_parity.sh --pre-close-work-id "$$work_id"; \
	else \
		bash scripts/check_release_parity.sh; \
	fi

checksums:
	$(MAKE) -j2 checksums-en checksums-cn

.PHONY: checksums-en checksums-cn
checksums-en:
	$(MAKE) -C P2T2C_EN checksums

checksums-cn:
	$(MAKE) -C P2T2C_CN checksums

smoke: smoke-all

smoke-all:
	bash scripts/release_smoke_test.sh --suite all --jobs "$(SMOKE_JOBS)" $(SMOKE_WORK_ARG)

smoke-daily:
	bash scripts/release_smoke_test.sh --suite daily --jobs "$(SMOKE_JOBS)" --changed-from "$(BASE)" $(SMOKE_WORK_ARG)

smoke-contract:
	bash scripts/release_smoke_test.sh --suite contract $(SMOKE_WORK_ARG)

smoke-security:
	bash scripts/release_smoke_test.sh --suite security $(SMOKE_WORK_ARG)

smoke-transaction:
	bash scripts/release_smoke_test.sh --suite transaction $(SMOKE_WORK_ARG)

smoke-migration:
	bash scripts/release_smoke_test.sh --suite migration $(SMOKE_WORK_ARG)

smoke-locale:
	bash scripts/release_smoke_test.sh --suite locale $(SMOKE_WORK_ARG)

smoke-coverage:
	bash scripts/release_smoke_test.sh --coverage-only

refresh-release-metadata:
	@set -eu; \
	for release_root in P2T2C_EN P2T2C_CN; do \
		manifest="$$release_root/.p2t2c/managed-files.txt"; \
		checksum_tmp="$$release_root/.p2t2c/CHECKSUMS.sha256.tmp"; \
		lock_tmp="$$release_root/.p2t2c/lock.sha256.tmp"; \
		: > "$$checksum_tmp"; \
		chmod 0644 "$$checksum_tmp"; \
		while IFS= read -r line || test -n "$$line"; do \
			rel="$$(printf '%s' "$$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')"; \
			case "$$rel" in ''|'#'*) continue ;; esac; \
			test -f "$$release_root/$$rel" || { echo "ERROR: managed file missing: $$release_root/$$rel" >&2; exit 1; }; \
			if test "$$rel" != ".p2t2c/CHECKSUMS.sha256"; then (cd "$$release_root" && shasum -a 256 "$$rel") >> "$$checksum_tmp"; fi; \
		done < "$$manifest"; \
		chmod 0644 "$$checksum_tmp"; \
		mv "$$checksum_tmp" "$$release_root/.p2t2c/CHECKSUMS.sha256"; \
		: > "$$lock_tmp"; \
		chmod 0644 "$$lock_tmp"; \
		while IFS= read -r line || test -n "$$line"; do \
			rel="$$(printf '%s' "$$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$$//')"; \
			case "$$rel" in ''|'#'*) continue ;; esac; \
			(cd "$$release_root" && shasum -a 256 "$$rel") >> "$$lock_tmp"; \
		done < "$$manifest"; \
		chmod 0644 "$$lock_tmp"; \
		mv "$$lock_tmp" "$$release_root/.p2t2c/lock.sha256"; \
	done
