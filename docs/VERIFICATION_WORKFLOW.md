# Manual verification workflow

Observations are append-only. Importing or entering a value does not overwrite earlier observations or make a value verified.

## Repository intake

1. Place a staged dataset under `data/verification/<location>/<date>/` with its manifest, session, entities, observations, sources, evidence metadata, `SHA256SUMS.csv`, and original screenshots.
2. In the Verification screen choose **Import staged intake** and select the dataset folder.
3. The importer validates the schema, exact manifest file set and hashes, screenshot SHA-256 values, relative paths, required files, IDs/references, and duplicate evidence/observation identifiers before writing. Any validation or database error rejects the whole intake. Re-importing an already imported dataset with the same manifest is a no-op.
4. Evidence is copied into app-owned storage. The imported session keeps `officialGameVersion` nullable and records `observedLiveAt` and location separately.

## Review and confirmation

1. Create a session manually if no repository intake exists. Session context includes observed date, location, optional official update label, check type, and notes.
2. For manual evidence, import PNG/JPG/WebP using the file picker or drag-and-drop. The app stores a local copy, SHA-256, dimensions, original filename, import time, and session context. Duplicate content is rejected.
3. Open a screenshot in the viewer. Zoom, pan, fit-to-window, and crop are available; crops are PNG child artifacts and retain their original evidence relation.
4. Enter or inspect the entity, field, value, note, and linked screenshot. New observations start `ENTERED`; OCR is not included.
5. Review all fields linked to a screenshot together. Correct individual fields as needed, then explicitly confirm the card. This moves linked eligible observations through review and `USER_CONFIRMED_CAPTURE`; a bulk card action avoids requiring one click per field.
6. The user may explicitly promote a confirmed card to `IN_GAME_VERIFIED` only when the evidence is an intact original screenshot with a matching checksum, the observations are linked to that evidence, the transcription was reviewed and confirmed, the session has an observed date and location, and the source is `IN_GAME_MANUAL`. `officialGameVersion` is useful context but optional. Import never performs this confirmation on the user's behalf.
7. Compare each observation with the current preferred value. Keep it unresolved, explicitly prefer a verified observation, or mark an older observation outdated/superseded. Preserve all prior values in history.

## Candidate overlay

The queue supports unreviewed, needs-confirmation, conflicts, confirmed, and rejected states. Candidate preview includes only policy-eligible `IN_GAME_VERIFIED` field observations and presents Added/Changed/Conflicts/Removed. The exported overlay is field-only and retains observation IDs, evidence references/checksums, observed date, context/location, and catalog version; it is not installed automatically and does not duplicate the community catalog.

Session ZIP bundles can be exported for transfer. Bundle and evidence formats are documented in [EVIDENCE_FORMAT.md](EVIDENCE_FORMAT.md) and [VERIFICATION_BUNDLE_FORMAT.md](VERIFICATION_BUNDLE_FORMAT.md). The app does not capture screenshots automatically.

Small craft experiments record run sample size and outcome counts. Samples below 100 are described as preliminary and are not treated as proof of probability.
