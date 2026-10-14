<#
disk_survey.ps1
Read-only disk space survey for Windows 10 / 11.

IMPORTANT:
  * This script performs NO deletion and NO modification.
  * It writes a structured report to -OutFile so the caller can read it back
    (PowerShell stdout is frequently swallowed by host applications).
  * Scripts in this skill are intentionally ASCII-only so they run correctly
    under Windows PowerShell 5.1 regardless of file encoding.
#>
[CmdletBinding()]
param(
    [int]$TopN = 15,
    [int]$MinSizeMB = 500,
    [string]$UserRoot = $env:USERPROFILE,
    [string]$OutFile = "$env:TEMP\disk_survey.txt"
)

$ErrorActionPreference = 'SilentlyContinue'
"" | Out-File -LiteralPath $OutFile -Encoding UTF8

function Add-Section([string]$Title) {
    Add-Content -LiteralPath $OutFile -Value ""
    Add-Content -LiteralPath $OutFile -Value ("===== " + $Title + " =====")
}

function Get-DirSize([string]$Path) {
    $m = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum
    [pscustomobject]@{ Bytes = [int64]$m.Sum; Files = [int]($m.Count) }
}

function Format-GB([int64]$Bytes) { [math]::Round($Bytes / 1GB, 2) }

# ---------------------------------------------------------------- 1. Drives
Add-Section "DRIVES"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $total = $_.Size; $free = $_.FreeSpace
    $pct = 0; if ($total -gt 0) { $pct = [math]::Round(100 * $free / $total, 1) }
    Add-Content -LiteralPath $OutFile ("{0}  total={1} GB  free={2} GB  free%={3}" -f `
        $_.DeviceID, (Format-GB $total), (Format-GB $free), $pct)
}

# --------------------------------------------- 2. Top-level of system drive
$sys = $env:SystemDrive
Add-Section ("TOP-LEVEL DIRS OF " + $sys)
Get-ChildItem -LiteralPath ($sys + "\") -Force -Directory | ForEach-Object {
    $s = Get-DirSize $_.FullName
    [pscustomobject]@{ Path = $_.FullName; GB = (Format-GB $s.Bytes); Files = $s.Files }
} | Sort-Object GB -Descending | Select-Object -First $TopN | ForEach-Object {
    Add-Content -LiteralPath $OutFile ("{0,10} GB  {1,9} files  {2}" -f $_.GB, $_.Files, $_.Path)
}

# ---------------------------------------- 3. Biggest folders under user root
Add-Section ("BIGGEST FOLDERS UNDER " + $UserRoot)
Get-ChildItem -LiteralPath $UserRoot -Force -Directory | ForEach-Object {
    $top = $_
    $s = Get-DirSize $top.FullName
    [pscustomobject]@{ Path = $top.FullName; GB = (Format-GB $s.Bytes); Files = $s.Files }
} | Sort-Object GB -Descending | Select-Object -First $TopN | ForEach-Object {
    Add-Content -LiteralPath $OutFile ("{0,10} GB  {1,9} files  {2}" -f $_.GB, $_.Files, $_.Path)
}

# ------------------------------------------------- 4. Large individual files
Add-Section ("FILES >= " + $MinSizeMB + " MB UNDER " + $UserRoot)
Get-ChildItem -LiteralPath $UserRoot -Recurse -Force -File |
    Where-Object { $_.Length -ge ($MinSizeMB * 1MB) } |
    Sort-Object Length -Descending | Select-Object -First $TopN | ForEach-Object {
        Add-Content -LiteralPath $OutFile ("{0,10} GB  {1}" -f (Format-GB $_.Length), $_.FullName)
    }

# ----------------------------------------------- 5. Safe-to-clean candidates
Add-Section "SAFE-TO-CLEAN CANDIDATES"
$candidates = @(
    $env:TEMP,
    "$env:SystemRoot\Temp",
    "$env:SystemRoot\SoftwareDistribution\Download",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\CrashDumps",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
    'C:\$WinREAgent',
    'C:\$Windows.~BT',
    'C:\$Windows.~WS'
)
foreach ($c in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $c) {
        $s = Get-DirSize $c
        Add-Content -LiteralPath $OutFile ("{0,10} GB  {1,9} files  {2}" -f (Format-GB $s.Bytes), $s.Files, $c)
    }
}

Add-Content -LiteralPath $OutFile ""
Add-Content -LiteralPath $OutFile "===== END ====="
