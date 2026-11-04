param(
  [Parameter(Mandatory=$true)][ValidateSet("Wordleaf","Nalia")][string]$App,
  [string]$KeepInstallDir = ""
)
$ErrorActionPreference = "SilentlyContinue"

$defs = @{
  Wordleaf = @{
    Processes = @("Wordleaf","wordleaf")
    Helpers = @()
    Tasks = @("Wordleaf","Wordleaf Always On","Wordleaf Background")
    RunValues = @("Wordleaf","WordLeaf","Wordleaf Always On")
    ExeNames = @("Wordleaf.exe","wordleaf.exe")
  }
  Nalia = @{
    Processes = @("Nalia","nalia")
    Helpers = @("nalia-windows-host")
    Tasks = @("Nalia Always On","Nalia","Nalia Background")
    RunValues = @("Nalia","Nalia Always On")
    ExeNames = @("Nalia.exe","nalia.exe")
  }
}
$d = $defs[$App]

foreach ($name in @($d.Processes + $d.Helpers)) {
  Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
foreach ($task in $d.Tasks) {
  schtasks.exe /End /TN $task 2>$null | Out-Null
  schtasks.exe /Delete /TN $task /F 2>$null | Out-Null
}
$run = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
foreach ($value in $d.RunValues) {
  Remove-ItemProperty -Path $run -Name $value -ErrorAction SilentlyContinue
}

# Remove only stale install directories proven by an exact uninstall entry and
# an app executable/uninstaller marker. Never inspect or delete user data roots.
$uninstallRoots = @(
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
  "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$keep = if ($KeepInstallDir) { [IO.Path]::GetFullPath($KeepInstallDir).TrimEnd('\') } else { "" }

Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -eq $App -or $_.DisplayName -like "$App *" } |
  ForEach-Object {
    $loc = [string]$_.InstallLocation
    if ([string]::IsNullOrWhiteSpace($loc)) { return }
    $loc = $loc.Trim('"').TrimEnd('\')
    try { $full = [IO.Path]::GetFullPath($loc).TrimEnd('\') } catch { return }
    if ($keep -and $full -ieq $keep) { return }

    $proven = Test-Path (Join-Path $full "uninstall.exe")
    foreach ($exe in $d.ExeNames) {
      if (Test-Path (Join-Path $full $exe)) { $proven = $true }
    }
    if (-not $proven) { return }

    # Never delete broad roots, profile roots, Documents, Desktop, Pictures, etc.
    $leaf = Split-Path $full -Leaf
    if ($leaf -notmatch ("(?i)^" + [regex]::Escape($App) + "$")) { return }
    if ($full -match '(?i)\\(Documents|Desktop|Pictures|Videos|Music|Downloads)$') { return }

    # An app registration proves the product location, not ownership of every
    # file in it. Old folders without an owned-file manifest are preserved.
    Write-Output "Preserved legacy $App installation: $full"
  }
