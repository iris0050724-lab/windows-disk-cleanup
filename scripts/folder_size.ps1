<#
folder_size.ps1
Measure the real size of one or more directories.

Why this exists:
  * `du` returns 0 under Git Bash on Windows.
  * Registry `EstimatedSize` and installer-reported sizes are frequently wrong
    (observed: an app reporting 1.14 GB actually occupied 4.95 GB).
Always trust the real byte count produced here.

Usage:
  .\folder_size.ps1 -Path "C:\Users\me\AppData\Local\SomeApp"
  .\folder_size.ps1 -Path "C:\A","C:\B" -OutFile "$env:TEMP\sizes.txt"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Path,
    [string]$OutFile = "$env:TEMP\folder_size.txt"
)

$ErrorActionPreference = 'SilentlyContinue'
"" | Out-File -LiteralPath $OutFile -Encoding UTF8

foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p)) {
        Add-Content -LiteralPath $OutFile ("MISSING| " + $p)
        continue
    }
    $m = Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum
    $bytes = [int64]$m.Sum
    $mb = [math]::Round($bytes / 1MB, 2)
    $gb = [math]::Round($bytes / 1GB, 3)
    Add-Content -LiteralPath $OutFile ("{0,10} GB  {1,12} MB  {2,9} files  {3}" -f $gb, $mb, $m.Count, $p)
}
