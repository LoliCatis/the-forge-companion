param([Parameter(Mandatory=$true)][string]$SnapshotRoot)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $SnapshotRoot).Path
foreach ($relative in @('data/verification','data/research')) { if (Test-Path -LiteralPath (Join-Path $root $relative)) { throw "Excluded data directory present: $relative" } }
$allowedPack = 'data/packs/2026.10.17-bootstrap.1'
$packs = Get-ChildItem -LiteralPath (Join-Path $root 'data/packs') -Directory
if ($packs.Count -ne 1 -or $packs[0].Name -ne '2026.10.17-bootstrap.1') { throw 'Unexpected data pack directory.' }
$manifest = Get-Content -Raw -LiteralPath (Join-Path $root "$allowedPack/manifest.json") | ConvertFrom-Json
foreach ($name in @('ores.json','weapons.json','traits.json','probabilities.json','sources.json','observations.json','evidence.json')) {
  $item = Get-Content -Raw -LiteralPath (Join-Path $root "$allowedPack/$name") | ConvertFrom-Json
  if ($name -eq 'weapons.json') { if ($item.classes.Count -or $item.variants.Count) { throw 'Bootstrap contains game weapon rows.' } } elseif ($item.Count) { throw "Bootstrap contains data rows in $name." }
}
$images = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $ext = $_.Extension.ToLowerInvariant(); $icon = $_.FullName -like '*\Assets.xcassets\AppIcon.appiconset\*' -or $_.FullName -like '*\windows\runner\resources\app_icon.ico'; ($ext -in @('.jpg','.jpeg')) -or (($ext -in @('.png','.ico')) -and -not $icon) }
if ($images) { throw "Unexpected image/evidence file: $($images[0].FullName)" }
$textFiles = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in @('.md','.txt','.csv','.json','.yaml','.yml','.dart','.py','.ps1','.xcconfig','.plist','.rc','.xml','.cpp','.h') }
foreach ($file in $textFiles) {
  if ($file.Name -eq 'audit_public_snapshot.ps1') { continue }
  $text = Get-Content -Raw -LiteralPath $file.FullName
  if ($env:USERPROFILE -and $text.Contains($env:USERPROFILE)) { throw "Current user path found: $($file.FullName)" }
  if ($text -match '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}') { throw "Email address found: $($file.FullName)" }
}
$license = Join-Path $root 'LICENSE'; if (-not (Test-Path -LiteralPath $license)) { throw 'LICENSE missing.' }
if (-not (Select-String -Path $license -Pattern 'Copyright \(c\) 2026 LoliCatis' -Quiet)) { throw 'MIT copyright line missing.' }
$notice = Join-Path $root 'NOTICE.md'; if (-not (Select-String -Path $notice -Pattern 'does not grant rights to Roblox, The Forge, third-party brands' -Quiet)) { throw 'NOTICE scope statement missing.' }
if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) { throw 'Gitleaks must be available in PATH before public snapshot approval.' }
gitleaks detect --no-git --source $root --redact --exit-code 1
if ($LASTEXITCODE -ne 0) { throw 'Gitleaks detected a secret.' }
Write-Host 'Public snapshot audit passed.'
