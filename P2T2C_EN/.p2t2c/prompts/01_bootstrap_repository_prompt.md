# Prompt 01 — Initialize Repository

Goal: connect the current project to P2T2C. Do not implement business features in this stage.

First read `P2T2C_AGENTS.md`, then complete the Required Reading listed there.

Additional reads for this stage:

- `P2T2C_README.md`
- Project-owned `README.md`, if present
- `.p2t2c/project_config.yaml` or `.p2t2c/templates/project_config.example.yaml`
- `docs/sot/manifest.yaml`

Allowed in this stage:

- Create the project directory skeleton.
- Add P2T2C document directories.
- Add the check script.
- Create a minimal runnable shell.
- Write project-owned README / Makefile / TODO files only when the project needs them; do not create them as P2T2C-managed entries.

Forbidden in this stage:

- Implement business features.
- Add business rules not defined by SoT.
- Infer current rules from historical reference documents.
- Modify ADRs or accept key decisions.

When done, report:

- Which directories were created.
- The responsibility of each directory.
- Which parts are placeholders only.
- The recommended next CP / spec.
- Whether `bash .p2t2c/bin/check_p2t2c.sh` passed.
