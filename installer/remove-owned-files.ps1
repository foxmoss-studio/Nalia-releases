param([Parameter(Mandatory=$true)][string]$InstallDir, [Parameter(Mandatory=$true)][string]$ManifestPath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
if ($root.Length -lt 4 -or $root -eq [IO.Path]::GetPathRoot($root).TrimEnd('\')) { throw 'Refusing a drive root.' }
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.product -ne 'com.foxandmoss.nalia') { throw 'Owned-file manifest is invalid.' }
$owned = @()
$directories = @()
# Validate every entry and its ancestors before deleting anything.
foreach ($relative in $manifest.files) {
  if (-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.?([\\/]|$)' -or $relative.Contains(':')) { throw 'Unsafe manifest path.' }
  $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
  if (-not $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path escaped install directory.' }
  $ancestor = $full
  while ($ancestor -and $ancestor.Length -ge $root.Length) {
    if (Test-Path -LiteralPath $ancestor) {
      $item = Get-Item -LiteralPath $ancestor -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing a link or junction in an owned-file path.' }
    }
    $ancestor = Split-Path -Path $ancestor -Parent
  }
  $owned += $full
  $parent = Split-Path -Path $full -Parent
  while ($parent -and $parent.Length -gt $root.Length) {
    $directories += $parent
    $parent = Split-Path -Path $parent -Parent
  }
}
foreach ($full in $owned) {
  if (Test-Path -LiteralPath $full -PathType Leaf) { Remove-Item -LiteralPath $full -Force }
}
foreach ($directory in ($directories | Sort-Object -Unique | Sort-Object Length -Descending)) {
  try { [IO.Directory]::Delete($directory, $false) } catch { }
}
try { [IO.Directory]::Delete($root, $false) } catch { }
