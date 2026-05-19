# Security Policy

P2T2C is a workflow template and shell-script harness. Security-sensitive reports should not include secrets or private project data.

## Reporting

Use GitHub private vulnerability reporting if it is enabled for the repository. If it is not enabled, open a GitHub issue with a minimal public description and mark it as security-sensitive so maintainers can move details to a private channel.

## Scope

Reports are in scope when they affect:

- Installation or upgrade scripts.
- Release-root integrity checks.
- Handling of project-owned files during install, upgrade, or rollback.
- Accidental inclusion of secrets or private project data in template files.
