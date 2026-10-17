# Data pack format

Schema version 1 uses a directory of UTF-8 JSON files: manifest, sources, ores, weapons, traits, probabilities, observations, and evidence. The public repository bootstrap pack is stored under data/packs/2026.10.17-bootstrap.1 and contains valid empty collections only.

The manifest records schema version, data version, ruleset version, source IDs, and SHA-256 hashes for every content file. Missing game facts remain absent; an empty pack is valid and imports as an empty catalog. Production data packs must have documented provenance and licensing before distribution.
