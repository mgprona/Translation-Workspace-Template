<#
.SYNOPSIS
    ตั้งสถานะรายตอนแบบช่วง ด้วย gate เดิมของ set-status.ps1 ทุกตอน

.DESCRIPTION
    ลดงานมือจากการเรียก set-status ทีละตอน แต่ยังคง hard gate ทุกตัว:
    เรียก complete-stage.ps1 ทีละตอน จึงได้ gate ครบชุดเหมือน workflow ปกติ

.PARAMETER Start
    ตอนเริ่ม เช่น 1

.PARAMETER End
    ตอนจบ เช่น 33

.PARAMETER Stage
    draft | qa | edited | final

.PARAMETER Arc
    ใช้กับ Stage draft เพื่อเติมคอลัมน์ Arc

.PARAMETER Verdict
    ใช้กับ Stage qa: Pass | Pass-minor | Needs-revision | Re-translate

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/status-arc.ps1 -Start 1 -End 10 -Stage draft -Arc 1
.EXAMPLE
    powershell -File etc/status-arc.ps1 -Start 1 -End 10 -Stage qa -Verdict Pass
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$Start,

    [Parameter(Mandatory = $true)]
    [int]$End,

    [Parameter(Mandatory = $true)]
    [ValidateSet('draft', 'qa', 'edited', 'final')]
    [string]$Stage,

    [string]$Arc,

    [ValidateSet('Pass', 'Pass-minor', 'Needs-revision', 'Re-translate')]
    [string]$Verdict,

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

if ($End -lt $Start) {
    Write-Host "[ERROR] -End ต้องมากกว่าหรือเท่ากับ -Start" -ForegroundColor Red
    exit 2
}

if ($Stage -eq 'qa' -and [string]::IsNullOrEmpty($Verdict)) {
    Write-Host "[ERROR] Stage qa ต้องระบุ -Verdict" -ForegroundColor Red
    exit 2
}

$completeScript = Join-Path $SelfDir 'complete-stage.ps1'
if (-not (Test-Path -LiteralPath $completeScript -PathType Leaf)) {
    Write-Host "[ERROR] ไม่พบ etc/complete-stage.ps1" -ForegroundColor Red
    exit 2
}

$done = 0
for ($ch = $Start; $ch -le $End; $ch++) {
    $nnn = '{0:D3}' -f $ch
    Write-Host "[STATUS-ARC] ch$nnn -> $Stage" -ForegroundColor Cyan

    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $completeScript,
        '-RepoRoot', $RepoRoot,
        '-Chapter', $ch,
        '-Stage', $Stage
    )
    if ($Stage -eq 'qa') {
        $args += @('-Verdict', $Verdict)
    }
    if (-not [string]::IsNullOrEmpty($Arc)) {
        $args += @('-Arc', $Arc)
    }

    & powershell @args
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    if ($exitCode -ne 0) {
        Write-Host "[FAIL] หยุดที่ ch$nnn — complete-stage gate ไม่ผ่าน (exit $exitCode)" -ForegroundColor Red
        Write-Host "       แก้ตอนนี้ก่อนแล้วค่อยรันช่วงที่เหลือต่อ" -ForegroundColor Yellow
        exit 1
    }
    $done++
}

Write-Host "[PASS] ตั้งสถานะ $Stage สำเร็จ $done ตอน (ch$('{0:D3}' -f $Start)-ch$('{0:D3}' -f $End))" -ForegroundColor Green
exit 0
