<#
migrate_folder.ps1
Move a directory to another drive and leave a Junction behind so the original
path keeps working for the application that created it.

Five-step method with verification and automatic rollback:
  1. copy        source -> target (target mirrors the source path structure)
  2. verify      compare file count AND total bytes
  3. remove      delete the original directory
  4. link        create a Junction at the original path pointing to the target
  5. verify      confirm the junction resolves and is readable

Any failure before step 4 rolls back the copied data and leaves the source intact.

Notes:
  * Creating a Junction does NOT require administrator rights.
  * The application using the folder MUST be closed first, otherwise files keep
    being written and the verification step will never pass.
  * This script is intentionally ASCII-only so it runs correctly under
    Windows PowerShell 5.1 regardless of file encoding.

Usage:
  .\migrate_folder.ps1 -Source "C:\Users\me\AppData\Local\App\Cache" -TargetRoot "D:\CBak"
  .\migrate_folder.ps1 -Source "<same path>" -TargetRoot "D:\CBak" -JunctionOnly
      (use -JunctionOnly after you manually deleted the source and the copy already exists)
  .\migrate_folder.ps1 -Source "<path>" -TargetRoot "D:\CBak" -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$TargetRoot,
    [switch]$JunctionOnly,
    [switch]$DryRun,
    [string]$LogFile = "$env:TEMP\migrate_folder.log"
)

$ErrorActionPreference = 'Stop'
"" | Out-File -LiteralPath $LogFile -Encoding UTF8

function Log([string]$msg) {
    Add-Content -LiteralPath $LogFile -Value $msg
}
function Fail([string]$msg) {
    Log ("RESULT| FAIL | " + $msg)
    Log "===== END ====="
    exit 1
}
function Get-Size([string]$Path) {
    $m = Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum
    [pscustomobject]@{ Bytes = [int64]$m.Sum; Files = [int]($m.Count) }
}

# ---------------------------------------------------------------- normalize
$srcOriginal = $Source
$resolved = Resolve-Path -LiteralPath $Source -ErrorAction SilentlyContinue
if (-not $resolved) { Fail ("source not found: " + $srcOriginal) }
$Source = $resolved.Path.TrimEnd('\')

$item = Get-Item -LiteralPath $Source -Force
if (-not $item.PSIsContainer) { Fail ("source is not a directory: " + $Source) }
if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
    Fail ("source is already a reparse point / junction: " + $Source)
}

# "C:\Users\me\Data" -> "Users\me\Data"
$rel = $Source.Substring(3)
$dest = Join-Path $TargetRoot $rel

Log ("SOURCE| " + $Source)
Log ("TARGET| " + $dest)

# ------------------------------------------------------------- destination
if (Test-Path -LiteralPath $dest) {
    if (-not $JunctionOnly) { Fail ("target already exists, refusing to merge: " + $dest) }
} else {
    if ($JunctionOnly) { Fail ("-JunctionOnly given but target does not exist: " + $dest) }
}

# -------------------------------------------------------------- junction only
if ($JunctionOnly) {
    if (Test-Path -LiteralPath $Source) { Fail ("-JunctionOnly given but source still exists: " + $Source) }
    if ($DryRun) { Log "DRYRUN| would create junction"; Log "===== END ====="; exit 0 }
    New-Item -ItemType Junction -Path $Source -Target $dest | Out-Null
    Log "RESULT| OK | junction created (junction-only mode)"
    Log "===== END ====="
    exit 0
}

# ------------------------------------------------------------------ 1. copy
Log "STEP 1| copying ..."
if (-not $DryRun) {
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $Source -Destination $dest -Recurse -Force -ErrorAction Stop
    } catch {
        Log ("COPY_FAILED| " + $_.Exception.Message)
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        Fail "copy failed - source left untouched"
    }
}

# ---------------------------------------------------------------- 2. verify
$srcSize = Get-Size $Source
$dstSize = Get-Size $dest
Log ("VERIFY| source bytes=" + $srcSize.Bytes + " files=" + $srcSize.Files)
Log ("VERIFY| target bytes=" + $dstSize.Bytes + " files=" + $dstSize.Files)
$matched = ($srcSize.Bytes -eq $dstSize.Bytes) -and ($srcSize.Files -eq $dstSize.Files)

if ($DryRun) {
    if ($matched) { Log "DRYRUN| verification would PASS" } else { Log "DRYRUN| verification would FAIL" }
    Log "===== END ====="
    exit 0
}

if (-not $matched) {
    Log "ROLLBACK| removing incomplete copy"
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    Fail "verification failed (source and target differ) - source left untouched"
}

# ---------------------------------------------------------------- 3. remove
Log "STEP 3| removing source ..."
try {
    Remove-Item -LiteralPath $Source -Recurse -Force -ErrorAction Stop
} catch {
    Log ("REMOVE_FAILED| " + $_.Exception.Message)
    Log "RESULT| FAIL | could not delete the source; data still present at target"
    Log "HINT| delete the source manually, then re-run with -JunctionOnly"
    Log "===== END ====="
    exit 1
}
if (Test-Path -LiteralPath $Source) {
    Log "RESULT| FAIL | source still present after delete; not creating junction"
    Log "HINT| the delete may have gone to the Recycle Bin; empty it, then re-run with -JunctionOnly"
    Log "===== END ====="
    exit 1
}

# ------------------------------------------------------------------ 4. link
Log "STEP 4| creating junction ..."
New-Item -ItemType Junction -Path $Source -Target $dest | Out-Null

# ---------------------------------------------------------------- 5. verify
$link = Get-Item -LiteralPath $Source -Force
$isLink = [bool]($link.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
$readable = Test-Path -LiteralPath (Join-Path $Source '.')
if ($isLink -and $readable) {
    Log "RESULT| OK | migrated and junction verified"
} else {
    Log "RESULT| WARN | junction created but verification looks odd"
}
Log "===== END ====="
