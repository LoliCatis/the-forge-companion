# Evidence format v1

Screenshot evidence is copied into the application's owned evidence directory. The database stores the generated local path and immutable metadata; it never depends on the original file remaining at its import location.

Supported screenshot extensions: PNG, JPG/JPEG, and WebP. Import decodes the image before accepting it, calculates SHA-256 over the original bytes, records the original filename, UTC `importedAt`, pixel dimensions, optional capture date, session ID, update label, and notes. Identical checksums are rejected as duplicate evidence.

An evidence row contains:

| Field | Meaning |
| --- | --- |
| `id` | Local immutable artifact ID |
| `type` | `SCREENSHOT`, `MANUAL_TRANSCRIPTION`, `WEB_SOURCE`, `DATASET_REFERENCE`, or `EXPERIMENT` |
| `reference` | App-owned local file path for screenshots |
| `checksum` | SHA-256 of the stored file bytes |
| `originalFilename`, `importedAt`, `width`, `height` | Import provenance |
| `sessionId` | Optional verification session association |
| `parentEvidenceId` | Original artifact ID when this is a crop |
| `capturedAt`, `notes` | Optional capture context and user label/update context |

Crop artifacts are PNGs with their own checksum and dimensions. A crop points to its parent screenshot; the parent is retained. Viewer zoom and pan do not alter the source. A file is considered integrity-valid only when it exists locally and the calculated SHA-256 equals the stored checksum.

Verification state is separate from evidence type. The manual workflow is `ENTERED` → `REVIEWED` → `USER_CONFIRMED_CAPTURE` → optional explicit `IN_GAME_VERIFIED`. A session-bound screenshot with a matching checksum, manual in-game source, matching game/update context, and explicit capture confirmation are required for the final transition. Missing files or mismatched hashes block promotion. A community observation is never upgraded in place.

No OCR, desktop capture API, game process integration, or automatic screenshot capture is part of this format/version.
