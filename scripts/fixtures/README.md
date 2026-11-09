# Frozen release fixtures

These archives are non-authoritative compatibility inputs, not current workflow rules.

The 0.15.0 archive was exported from commit `d8cae3b5abbcee72fbfdb99d1641a84e350ab2d6`, limited to P2T2C_EN and P2T2C_CN, using `git -c tar.umask=0022 archive --format=tar` and `gzip -n`. File content is the historical commit; export modes match the release mode policy. Its SHA-256 is `258735e9f92a321e148a3a83af4503194f5709f815ecbb8c971572cac480e52f`.

Existing 0.14.0 and 0.14.1 archives retain their original pinned bytes. Release parity and smoke preflight verify the pinned archive digests before use.
