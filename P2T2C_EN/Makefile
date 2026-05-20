.PHONY: check checksums p2t2c-install-dry-run p2t2c-install p2t2c-upgrade-dry-run p2t2c-upgrade p2t2c-rollback
check:
	bash .p2t2c/bin/check_p2t2c.sh

checksums:
	shasum -a 256 -c .p2t2c/CHECKSUMS.sha256

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
