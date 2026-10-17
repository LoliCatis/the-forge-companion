# The Forge Companion

A native Flutter desktop companion for local inventory tracking and calculations related to Roblox The Forge. The app does not automate Roblox or use OCR.

## Data on first launch

The public build starts with an empty, first-party bootstrap pack (`2026.10.17-bootstrap.1`). It contains schema-compatible empty collections only. No community catalog, copied game tables, screenshots, or private verification intake is bundled. Users can enter data manually or import a data pack they are authorized to use. Missing values remain unavailable; no placeholder game statistics are presented as facts.

The database is stored in the operating system application-support directory. The bootstrap pack is imported only when no active data version exists.

## Development

Flutter version is pinned in `.fvmrc`. Native builds require the respective Windows, macOS, or Linux desktop toolchain.

See `docs/ARCHITECTURE.md`, `docs/DATA_PACK_FORMAT.md`, `docs/VERIFICATION_WORKFLOW.md`, and `docs/IMPLEMENTATION_STATUS.md` for technical details.

This is an unofficial community project, not affiliated with Roblox or The Forge developers.
