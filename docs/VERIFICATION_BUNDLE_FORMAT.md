# Verification bundle format v1

A verification bundle is a portable ZIP for one verification session. Export includes session context, session observations, evidence metadata, and all locally available evidence files. Export fails if any referenced evidence file is missing or checksum-invalid.

## ZIP layout

```text
manifest.json
session.json
observations.json
evidence.json
evidence/<artifact-id>.<extension>
```

`manifest.json` contains:

```json
{
  "format": "the-forge-companion-verification-bundle",
  "schemaVersion": 1,
  "sessionId": "session-id",
  "createdAt": "UTC ISO-8601",
  "files": {
    "session.json": "sha256 hex",
    "observations.json": "sha256 hex",
    "evidence.json": "sha256 hex",
    "evidence/artifact-id.png": "sha256 hex"
  }
}
```

The checksum map covers every payload file except `manifest.json` itself. Evidence metadata includes its own original checksum, filename, imported/capture timestamps, dimensions, session association, parent crop ID, and relative bundle path. Observation entries preserve their status, review state, evidence association, source ID, value, game/update context, and notes. JSON uses UTF-8.

## Validation and import

The current import operation is a non-destructive integrity validator: it checks ZIP readability, path safety, format/schema version, required files, and every manifest SHA-256. It reports a valid bundle but does not merge or install any records. No candidate pack is installed by export, validation, or candidate preview.

Consumers must reject unsafe paths, absent payloads, unsupported schema versions, and checksum mismatches. Do not treat community or guide observations in a valid bundle as in-game verified. The ZIP manifest authenticates integrity against accidental damage; it is not a digital signature or proof of who created the bundle.
