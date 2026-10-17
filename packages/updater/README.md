# Portable app updater

The desktop app currently checks the public GitHub Releases feed for a Windows
portable alpha build. Each successful `main` CI run publishes a prerelease
tagged `alpha-<commit SHA>` with:

- `the-forge-companion-windows-alpha.zip` — the complete portable `Release`
  directory;
- `windows-alpha-manifest.json` — build metadata and the archive SHA-256.

The app reads GitHub's release asset digest, downloads and verifies the ZIP,
validates the packaged commit and `BUILD_INFO.txt`, then asks the user before
staging installation. A helper waits for the app to close, backs up files,
installs the new release, and logs the result under app data. On copy failure,
it restores the previous files. The updater does not update macOS builds yet.

Application updates and game-data packs remain separate: updating the desktop
app does not import repository verification intake or modify user observations.
