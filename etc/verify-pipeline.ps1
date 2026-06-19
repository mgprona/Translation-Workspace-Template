<#
.SYNOPSIS
    ตรวจ pipeline ทั้ง arc แบบรวมศูนย์

.DESCRIPTION
    ใช้เป็น preflight/ship audit ที่รวบรวม gate สำคัญ:
    - audit-workspace ตรวจ phantom/missing/text leak/QA evidence
    - verify-okf ตรวจ OKF metadata และ index coverage
    - check-arc-phase ตรวจ readiness ตาม phase ที่ต้องการ

.PARAMETER Arc
    เลข arc ที่ต้องตรวจ

.PARAMETER Target
    audit-only | phase-b-ready | phase-c-ready | ship

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/verify-pipeline.ps1 -Arc 1 -Target phase-b-ready
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Arc,

    [ValidateSet('audit-only', 'phase-b-ready', 'phase-c-ready', 'ship')]
    [string]$Target = 'audit-only',

    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

$SelfDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($SelfDir)) {
    $SelfDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([string]::IsNullOrEmpty($RepoRoot)) {
    $RepoRoot = Split-Path -Parent $SelfDir
}

function Invoke-Check {
    param([string]$Name, [string[]]$Arguments)
    Write-Host "[CHECK] $Name" -ForegroundColor Cyan
    $output = & powershell @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    foreach ($line in $output) {
        Write-Host $line
    }
    if ($exitCode -ne 0) {
        Write-Host "[FAIL] $Name failed (exit $exitCode)" -ForegroundColor Red
        return $false
    }
    return $true
}

function Get-ArcRange {
    param([int]$ArcNum)
    $planFile = Join-Path $RepoRoot 'reports/batch-plan.md'
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $planFile -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt 2 -or $cells[0] -notmatch '^\d+$') { continue }
        if ([int]$cells[0] -eq $ArcNum -and $cells[1] -match '(\d+)\s*[-–]\s*(\d+)') {
            return [PSCustomObject]@{ Start = [int]$Matches[1]; End = [int]$Matches[2] }
        }
    }
    Write-Host "[ERROR] ไม่พบช่วงตอนของ Arc $ArcNum" -ForegroundColor Red
    exit 2
}

$arcNum = [int]($Arc -replace '\D', '')
$range = Get-ArcRange $arcNum
$etcDir = $SelfDir
$auditScript = Join-Path $etcDir 'audit-workspace.ps1'
$okfScript = Join-Path $etcDir 'verify-okf.ps1'
$phaseScript = Join-Path $etcDir 'check-arc-phase.ps1'

$ok = $true

$ok = (Invoke-Check "audit workspace Arc $arcNum" @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $auditScript,
    '-RepoRoot', $RepoRoot,
    '-Start', $range.Start,
    '-End', $range.End,
    '-CheckText'
)) -and $ok

if ($Target -in @('phase-b-ready', 'ship')) {
    $ok = (Invoke-Check "verify OKF Arc $arcNum" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $okfScript,
        '-RepoRoot', $RepoRoot,
        '-Start', $range.Start,
        '-End', $range.End,
        '-CheckAllFiles',
        '-RequireRangeMetadata'
    )) -and $ok
}

if ($Target -eq 'phase-b-ready') {
    $ok = (Invoke-Check "check phase B Arc $arcNum" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $phaseScript,
        '-RepoRoot', $RepoRoot,
        '-Arc', $arcNum,
        '-Phase', 'B'
    )) -and $ok
} elseif ($Target -eq 'phase-c-ready') {
    $ok = (Invoke-Check "check phase C Arc $arcNum" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $phaseScript,
        '-RepoRoot', $RepoRoot,
        '-Arc', $arcNum,
        '-Phase', 'C'
    )) -and $ok
} elseif ($Target -eq 'ship') {
    $ok = (Invoke-Check "check ship Arc $arcNum" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $phaseScript,
        '-RepoRoot', $RepoRoot,
        '-Arc', $arcNum,
        '-Phase', 'ship'
    )) -and $ok
}

if ($ok) {
    Write-Host "[PASS] Pipeline verification passed for Arc $arcNum ($Target)" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] Pipeline verification failed for Arc $arcNum ($Target)" -ForegroundColor Red
exit 1
