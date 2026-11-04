param([Parameter(Mandatory=$true)][string]$StageDir, [Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($StageDir).TrimEnd('\')
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1) })
$files += @('.foxmoss\cleanup-legacy.ps1', '.foxmoss\owned-files.json', 'uninstall.exe')
@{ schema = 1; product = 'com.foxandmoss.nalia'; files = @($files | Sort-Object -Unique) } |
  ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
