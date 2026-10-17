param(
  [Parameter(Mandatory=$true)][string]$SourceRoot,
  [Parameter(Mandatory=$true)][string]$StagingRoot
)
$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$stageFull = [System.IO.Path]::GetFullPath($StagingRoot)
if ($stageFull.StartsWith($source, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Staging must be outside the source repository.'
}
if (Test-Path -LiteralPath $stageFull) {
  if (Get-ChildItem -LiteralPath $stageFull -Force | Select-Object -First 1) {
    throw 'Staging directory must be absent or empty; exporter never deletes existing content.'
  }
} else { New-Item -ItemType Directory -Path $stageFull | Out-Null }
$allowlist = Join-Path $PSScriptRoot 'public-snapshot.allowlist.txt'
$rules = Get-Content -LiteralPath $allowlist | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
$tracked = git -C $source ls-files
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked source files.' }
$deny = @('data/verification/','data/research/','evidence/','screenshots/','intake/','repository_intake_test.dart','.env','credentials/','secrets/','apps/desktop/assets/packs/','data/packs/2026.10.15-community.1/','data/packs/2026.10.17-community.2/')
$copied = [System.Collections.Generic.List[string]]::new()
$seedRoot = Split-Path -Parent $PSScriptRoot
$preferSeed = @('README.md','.gitignore','LICENSE','NOTICE.md','.github/workflows/desktop-ci.yml','apps/desktop/pubspec.yaml','apps/desktop/lib/startup/startup_bootstrap.dart','apps/desktop/lib/screens/forge/forge_screen.dart','apps/desktop/lib/screens/optimizer/optimizer_screen.dart','apps/desktop/test/startup_bootstrap_test.dart','apps/desktop/test/widget_test.dart','packages/game_data/lib/src/game_database.dart','packages/game_data/test/game_database_test.dart','packages/game_data/test/data_pack_database_test.dart','packages/game_data/test/data_pack_test.dart','packages/game_data/test/data_pack_test_utils.dart','packages/game_data/test/data_resolver_test.dart','packages/calculation_engine/lib/src/models.dart','packages/calculation_engine/lib/src/forge_calculator.dart','packages/calculation_engine/test/calculation_engine_test.dart','tools/sync_desktop_pack.py')
foreach ($file in $tracked) {
  $isAllowed = $false
  foreach ($rule in $rules) { if ($rule.EndsWith('/') -and $file.StartsWith($rule)) { $isAllowed = $true }; if ($file -eq $rule) { $isAllowed = $true } }
  if (-not $isAllowed) { continue }
  $normalized = $file.Replace('\','/')
  if ($deny | Where-Object { $normalized.Contains($_) }) { continue }
  $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
  if ($extension -in @('.db','.sqlite','.sqlite3','.jpg','.jpeg')) { continue }
  if ($extension -in @('.png','.ico')) {
    $isAppIcon = $normalized.StartsWith('apps/desktop/macos/Runner/Assets.xcassets/AppIcon.appiconset/') -or $normalized -eq 'apps/desktop/windows/runner/resources/app_icon.ico'
    if (-not $isAppIcon) { continue }
  }
  $from = Join-Path $source $file
  $preferSanitized = ($preferSeed -contains $file) -or $file.StartsWith('docs/') -or $file.StartsWith('data/packs/') -or $file.StartsWith('apps/desktop/assets/packs/')
  if ($preferSanitized) { $from = Join-Path $seedRoot $file }
  if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { continue }
  $to = Join-Path $stageFull $file
  New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force | Out-Null
  Copy-Item -LiteralPath $from -Destination $to
  $copied.Add($file)
}
# Seed new or public-only allowlisted files from the sanitized checkout.
$seedFiles = Get-ChildItem -LiteralPath $seedRoot -Recurse -File
foreach ($item in $seedFiles) {
  $file = [System.IO.Path]::GetRelativePath($seedRoot, $item.FullName).Replace('\','/')
  $isAllowed = $false
  foreach ($rule in $rules) { if ($rule.EndsWith('/') -and $file.StartsWith($rule)) { $isAllowed = $true }; if ($file -eq $rule) { $isAllowed = $true } }
  if (-not $isAllowed -or $copied.Contains($file)) { continue }
  $isBootstrapAsset = $file.StartsWith('apps/desktop/assets/packs/2026.10.17-bootstrap.1/')
  if (($deny | Where-Object { $file.Contains($_) }) -and -not $isBootstrapAsset) { continue }
  $to = Join-Path $stageFull $file
  New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force | Out-Null
  Copy-Item -LiteralPath $item.FullName -Destination $to
  $copied.Add($file)
}
$diff = foreach ($relative in $copied | Sort-Object -Unique) {
  $baseline = Join-Path $seedRoot $relative
  $current = Join-Path $stageFull $relative
  $state = if (-not (Test-Path -LiteralPath $baseline -PathType Leaf)) { 'ADDED' } elseif ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $current -Algorithm SHA256).Hash) { 'UNCHANGED' } else { 'CHANGED' }
  [pscustomobject]@{ status=$state; file=$relative }
}
$diff | Export-Csv -LiteralPath (Join-Path $stageFull 'PUBLIC_SNAPSHOT_DIFF.csv') -NoTypeInformation -Encoding utf8
$relativeFiles = Get-ChildItem -LiteralPath $stageFull -Recurse -File | ForEach-Object { [System.IO.Path]::GetRelativePath($stageFull, $_.FullName).Replace('\','/') }
$relativeFiles | Sort-Object | Set-Content -LiteralPath (Join-Path $stageFull 'PUBLIC_SNAPSHOT_FILES.txt') -Encoding utf8
$audit = Join-Path $PSScriptRoot 'audit_public_snapshot.ps1'
& $audit -SnapshotRoot $stageFull
if ($LASTEXITCODE -ne 0) { throw 'Snapshot audit failed.' }
Write-Host "Copied and audited $($relativeFiles.Count) allowlisted files to $stageFull"
Write-Host 'Review PUBLIC_SNAPSHOT_DIFF.csv and the complete file manifest before commit.'
