# Implementation status

The project is a native Flutter desktop application with a SQLite-backed local data store, field-level observations and provenance, data resolution policies, manual data entry/import, verification workflows, calculation screens, and Windows release updater support. The architecture document describes intended extensions as well as current components; it is not a claim that every planned feature is complete.

## Public first-run behavior

The public build imports an empty first-party bootstrap pack when no active data version exists. It contains no game facts or third-party datasets. Empty catalog states are expected until users add or import licensed data. Private verification intake and captures are not bundled.

## Current boundaries

- Ore composition and inventory calculations are implemented; result coverage depends on installed data.
- Optimizer, comparison, weapon, trait, armor, and probability features have the limitations described in the UI and architecture documentation; unsupported values remain unknown.
- Verification supports local sessions, evidence attachment, and review. This public snapshot contains no sessions or captures.
- Windows application updater selects releases from LoliCatis/the-forge-companion, validates release metadata and portable assets, and keeps user data outside the installation tree. End-to-end update scenarios still require manual validation on Windows.
- macOS updater is not supported yet.
- Data-pack updating is not implemented; data import is user initiated.

The public CI workflow runs engine/data/widget tests and builds native desktop targets on GitHub-hosted Windows, macOS, and Linux runners. See the workflow file for the current job matrix.
