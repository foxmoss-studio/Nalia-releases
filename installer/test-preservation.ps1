$ErrorActionPreference = 'Stop'
$sandbox = Join-Path $env:TEMP ('Nalia-preservation-' + [Guid]::NewGuid().ToString('N'))
$root = Join-Path $sandbox 'Nalia'
New-Item -ItemType Directory -Path $root | Out-Null
try {
  Set-Content (Join-Path $root 'nalia.exe') 'owned payload'
  Set-Content (Join-Path $root 'my-document.txt') 'user sentinel'
  $manifestPath = Join-Path $sandbox 'manifest.json'
  @{ schema = 1; product = 'com.foxandmoss.nalia'; files = @('nalia.exe') } | ConvertTo-Json | Set-Content $manifestPath
  & "$PSScriptRoot/remove-owned-files.ps1" -InstallDir $root -ManifestPath $manifestPath
  if (Test-Path (Join-Path $root 'nalia.exe')) { throw 'Owned payload was not removed.' }
  if ((Get-Content (Join-Path $root 'my-document.txt') -Raw).Trim() -ne 'user sentinel') { throw 'User sentinel was changed.' }
  @{ schema = 1; product = 'com.foxandmoss.nalia'; files = @('..\outside.txt') } | ConvertTo-Json | Set-Content $manifestPath
  $rejected = $false
  try { & "$PSScriptRoot/remove-owned-files.ps1" -InstallDir $root -ManifestPath $manifestPath } catch { $rejected = $true }
  if (-not $rejected) { throw 'Traversal was not rejected.' }
  Write-Output 'Owned-file removal preserved user data and rejected traversal.'
} finally {
  # Only this test's new, uniquely named fixture is removed recursively.
  Remove-Item -LiteralPath $sandbox -Recurse -Force
}
