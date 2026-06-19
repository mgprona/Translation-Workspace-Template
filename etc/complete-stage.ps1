<#
.SYNOPSIS
    Entry point กลางหลังโมเดลสร้าง artifact — complete stage แบบ fail-closed

.DESCRIPTION
    โมเดลไม่ควรต้องจำเองว่าหลังเขียน draft/QA/edited/final ต้องรัน gate อะไรบ้าง
    ให้เรียกสคริปต์นี้คำสั่งเดียว สคริปต์จะเรียกเครื่องมือย่อยตาม state machine:

    chapter stages:
    - draft  : set-status(draft) + update-title-registry
    - qa     : set-status(qa) + audit ตอนนั้น
    - edited : set-status(edited)
    - final  : set-status(final) + audit ตอนนั้น

    arc stages:
    - phase-b-ready : verify-okf + audit arc + check-arc-phase B
    - phase-c-ready : check-arc-phase C
    - ship          : check-arc-phase ship

.PARAMETER Stage
    draft | qa | edited | final | phase-b-ready | phase-c-ready | ship

.PARAMETER Chapter
    เลขตอนสำหรับ stage รายตอน

.PARAMETER Arc
    เลข arc สำหรับ draft หรือ stage ระดับ arc

.PARAMETER Verdict
    สำหรับ Stage qa: Pass | Pass-minor | Needs-revision | Re-translate

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/complete-stage.ps1 -Chapter 21 -Stage draft -Arc 1
.EXAMPLE
    powershell -File etc/complete-stage.ps1 -Chapter 21 -Stage qa -Verdict Pass
.EXAMPLE
    powershell -File etc/complete-stage.ps1 -Arc 1 -Stage phase-b-ready
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('draft', 'qa', 'edited', 'final', 'phase-b-ready', 'phase-c-ready', 'ship')]
    [string]$Stage,

    [string]$Chapter,

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

function Invoke-Required {
    param(
        [string]$Name,
        [string[]]$Arguments
    )
    Write-Host "[STEP] $Name" -ForegroundColor Cyan
    & powershell @Arguments
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    if ($exitCode -ne 0) {
        Write-Host "[FAIL] $Name failed (exit $exitCode)" -ForegroundColor Red
        exit 1
    }
}

function Get-ArcRange {
    param([int]$ArcNum)
    $planFile = Join-Path $RepoRoot 'reports/batch-plan.md'
    if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) {
        Write-Host "[ERROR] ไม่พบ reports/batch-plan.md" -ForegroundColor Red
        exit 2
    }

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

    Write-Host "[ERROR] ไม่พบช่วงตอนของ Arc $ArcNum ใน reports/batch-plan.md" -ForegroundColor Red
    exit 2
}

function Set-ArcPlanPhase {
    param(
        [int]$ArcNum,
        [string]$PhaseValue,
        [string]$ProgressColumn
    )

    $planFile = Join-Path $RepoRoot 'reports/batch-plan.md'
    if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) {
        Write-Host "[ERROR] ไม่พบ reports/batch-plan.md" -ForegroundColor Red
        exit 2
    }

    $lines = @(Get-Content -LiteralPath $planFile -Encoding UTF8)
    $inComment = $false
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 9 -or $cells[0] -notmatch '^\d+$') { continue }
        if ([int]$cells[0] -ne $ArcNum) { continue }

        $cells[2] = $PhaseValue
        switch ($ProgressColumn) {
            'A' { $cells[3] = 'done' }
            'B' { $cells[4] = 'done' }
            'C' { $cells[5] = 'done' }
        }

        $lines[$i] = '| ' + ($cells -join ' | ') + ' |'
        $updated = $true
        break
    }

    if (-not $updated) {
        Write-Host "[ERROR] ไม่พบแถว Arc $ArcNum ใน reports/batch-plan.md สำหรับอัปเดต phase" -ForegroundColor Red
        exit 2
    }

    # UTF-8 with BOM (กันไทยเพี้ยนถ้าเปิดด้วย PS 5.1 — Set-Content -Encoding UTF8 ไม่เขียน BOM บน PS7)
    [System.IO.File]::WriteAllText($planFile, ((@($lines) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "[OK] batch-plan Arc $ArcNum -> Phase $PhaseValue" -ForegroundColor Green
}

$etcDir = $SelfDir
$statusScript = Join-Path $etcDir 'set-status.ps1'
$auditScript = Join-Path $etcDir 'audit-workspace.ps1'
$titleScript = Join-Path $etcDir 'update-title-registry.ps1'
$okfScript = Join-Path $etcDir 'verify-okf.ps1'
$normalizeOkfScript = Join-Path $etcDir 'normalize-okf-placeholders.ps1'
$phaseScript = Join-Path $etcDir 'check-arc-phase.ps1'

foreach ($script in @($statusScript, $auditScript, $phaseScript)) {
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        Write-Host "[ERROR] missing required script: $script" -ForegroundColor Red
        exit 2
    }
}

if ($Stage -in @('draft', 'qa', 'edited', 'final')) {
    if ([string]::IsNullOrEmpty($Chapter)) {
        Write-Host "[ERROR] Stage $Stage ต้องระบุ -Chapter" -ForegroundColor Red
        exit 2
    }
    $num = ($Chapter -replace '\D', '')
    if ([string]::IsNullOrEmpty($num)) {
        Write-Host "[ERROR] Chapter ไม่ถูกต้อง: $Chapter" -ForegroundColor Red
        exit 2
    }
    $chapterNum = [int]$num

    $statusArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $statusScript,
        '-RepoRoot', $RepoRoot,
        '-Chapter', $chapterNum,
        '-Stage', $Stage
    )
    if ($Stage -eq 'draft') {
        if ([string]::IsNullOrEmpty($Arc)) {
            Write-Host "[ERROR] Stage draft ต้องระบุ -Arc" -ForegroundColor Red
            exit 2
        }
        $statusArgs += @('-Arc', $Arc)
    }
    if ($Stage -eq 'qa') {
        if ([string]::IsNullOrEmpty($Verdict)) {
            Write-Host "[ERROR] Stage qa ต้องระบุ -Verdict" -ForegroundColor Red
            exit 2
        }
        $statusArgs += @('-Verdict', $Verdict)
    }

    Invoke-Required "set-status $Stage ch$('{0:D3}' -f $chapterNum)" $statusArgs

    if ($Stage -eq 'draft' -and (Test-Path -LiteralPath $titleScript -PathType Leaf)) {
        Invoke-Required "update-title-registry ch$('{0:D3}' -f $chapterNum)" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $titleScript,
            '-RepoRoot', $RepoRoot,
            '-Chapter', $chapterNum,
            '-Stage', 'draft',
            '-Status', 'proposed'
        )
    }

    if ($Stage -in @('qa', 'final')) {
        Invoke-Required "audit workspace ch$('{0:D3}' -f $chapterNum)" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $auditScript,
            '-RepoRoot', $RepoRoot,
            '-Start', $chapterNum,
            '-End', $chapterNum,
            '-CheckText'
        )
    }

    Write-Host "[COMPLETE] Stage $Stage ch$('{0:D3}' -f $chapterNum) ผ่านครบ" -ForegroundColor Green
    exit 0
}

if ([string]::IsNullOrEmpty($Arc)) {
    Write-Host "[ERROR] Stage $Stage ต้องระบุ -Arc" -ForegroundColor Red
    exit 2
}
$arcNum = [int]($Arc -replace '\D', '')
$range = Get-ArcRange $arcNum

switch ($Stage) {
    'phase-b-ready' {
        if (-not (Test-Path -LiteralPath $okfScript -PathType Leaf)) {
            Write-Host "[ERROR] missing required script: $okfScript" -ForegroundColor Red
            exit 2
        }
        if (Test-Path -LiteralPath $normalizeOkfScript -PathType Leaf) {
            Invoke-Required "normalize OKF placeholders" @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', $normalizeOkfScript,
                '-RepoRoot', $RepoRoot
            )
        }
        Invoke-Required "verify-okf Arc $arcNum" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $okfScript,
            '-RepoRoot', $RepoRoot,
            '-Start', $range.Start,
            '-End', $range.End,
            '-CheckAllFiles',
            '-RequireRangeMetadata'
        )
        Invoke-Required "audit workspace Arc $arcNum" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $auditScript,
            '-RepoRoot', $RepoRoot,
            '-Start', $range.Start,
            '-End', $range.End,
            '-CheckText'
        )
        Invoke-Required "check phase B Arc $arcNum" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $phaseScript,
            '-RepoRoot', $RepoRoot,
            '-Arc', $arcNum,
            '-Phase', 'B'
        )
        Set-ArcPlanPhase -ArcNum $arcNum -PhaseValue 'B' -ProgressColumn 'A'
    }
    'phase-c-ready' {
        Invoke-Required "check phase C Arc $arcNum" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $phaseScript,
            '-RepoRoot', $RepoRoot,
            '-Arc', $arcNum,
            '-Phase', 'C'
        )
        Set-ArcPlanPhase -ArcNum $arcNum -PhaseValue 'C' -ProgressColumn 'B'
    }
    'ship' {
        if (Test-Path -LiteralPath $normalizeOkfScript -PathType Leaf) {
            Invoke-Required "normalize OKF placeholders" @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass',
                '-File', $normalizeOkfScript,
                '-RepoRoot', $RepoRoot
            )
        }
        Invoke-Required "check ship Arc $arcNum" @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $phaseScript,
            '-RepoRoot', $RepoRoot,
            '-Arc', $arcNum,
            '-Phase', 'ship'
        )
        Set-ArcPlanPhase -ArcNum $arcNum -PhaseValue 'Shipped' -ProgressColumn 'C'
    }
}

Write-Host "[COMPLETE] Arc $arcNum stage $Stage ผ่านครบ" -ForegroundColor Green
exit 0
