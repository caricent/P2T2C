.PHONY: check check-en check-cn checksums

check: check-en check-cn

check-en:
	$(MAKE) -C P2T2C_EN check

check-cn:
	$(MAKE) -C P2T2C_CN check

checksums:
	cd P2T2C_EN && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
	cd P2T2C_CN && shasum -a 256 -c .p2t2c/CHECKSUMS.sha256
