# Public snapshot workflow

The private repository remains the full development archive. Do not mirror its Git history.

Use tools/export_public_snapshot.ps1 with the private checkout as SourceRoot and a new external StagingRoot. The exporter copies tracked allowlisted paths only, refuses to overwrite a non-empty stage, applies a denylist, writes a SHA-256 based file diff and full file manifest, and does not initialize Git or push. Public-safe override files are seeded from the last reviewed public snapshot; changes to those files require a manual merge review.

Run tools/audit_public_snapshot.ps1 against staging, including Gitleaks. Review the complete staging diff manually before creating a normal commit in the public repository. Never grant the exporter a publish token. Add new paths to the allowlist only after reviewing their contents and license/provenance.

Private verification intake, raw screenshots, research candidate tables, and unlicensed community packs remain excluded. Data packs are imported only after separate license and provenance review.
