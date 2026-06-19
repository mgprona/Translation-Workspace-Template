<#
.SYNOPSIS
    อ่านสถานะจริงแล้วบอกงานถัดไปแบบ deterministic

.DESCRIPTION
    ใช้แทนการให้โมเดลตีความ logs/chapter-status.md เองหลัง resume หรือระหว่าง batch
    สคริปต์นี้อ่าน reports/batch-plan.md + logs/chapter-status.md + ไฟล์ artifact จริง
    แล้วเลือก next action ตาม state machine ของ arc model

.PARAMETER Arc
    เลข arc ที่ต้องการตรวจ ถ้าไม่ระบุจะเลือก arc แรกที่ Phase ยังไม่ Shipped

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/next-task.ps1
.EXAMPLE
    powershell -File etc/next-task.ps1 -Arc 1
#>

param(
    [string]$Arc,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = Split-Path -Parent $scriptDir
}

function Test-RelFile {
    param([string]$Rel)
    return (Test-Path -LiteralPath (Join-Path $RepoRoot $Rel) -PathType Leaf)
}

function Get-ArcRows {
    $planFile = Join-Path $RepoRoot 'reports/batch-plan.md'
    $rows = @()
    if (-not (Test-Path -LiteralPath $planFile -PathType Leaf)) { return $rows }
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $planFile -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 3) { continue }
        if ($cells[0] -notmatch '^\d+$') { continue }
        $rangeMatch = [regex]::Match($cells[1], '(\d+)\s*[-–]\s*(\d+)')
        if (-not $rangeMatch.Success) { continue }
        $rows += [PSCustomObject]@{
            Arc   = [int]$cells[0]
            Start = [int]$rangeMatch.Groups[1].Value
            End   = [int]$rangeMatch.Groups[2].Value
            Phase = $cells[2]
            Raw   = $cells
        }
    }
    return @($rows | Sort-Object Arc)
}

function Get-StatusMap {
    $statusFile = Join-Path $RepoRoot 'logs/chapter-status.md'
    $map = @{}
    if (-not (Test-Path -LiteralPath $statusFile -PathType Leaf)) { return $map }
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $statusFile -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 3) { continue }
        if ($cells[0] -notmatch '^\d+$') { continue }
        $map[[int]$cells[0]] = $cells[2]
    }
    return $map
}

function Get-StageFromEvidence {
    param([int]$Chapter, [string]$Status)
    $nnn = '{0:D3}' -f $Chapter
    $hasDraft = Test-RelFile "thai_draft/ch$nnn.md"
    $hasNotes = Test-RelFile "reports/ch$nnn-translation-notes.md"
    $hasQa = Test-RelFile "qa/reports/ch$nnn-qa.md"
    $hasEdited = Test-RelFile "thai_edited/ch$nnn.md"
    $hasFinal = Test-RelFile "thai_final/ch$nnn.md"

    if ($hasFinal -and $Status -eq 'Final') { return 'Final' }
    if ($hasEdited -and $Status -eq 'Edited') { return 'Edited' }
    if ($hasQa -and $Status -match '^QA:') { return $Status }
    if ($hasDraft -and $hasNotes -and $Status -eq 'Draft') { return 'Draft' }
    if ($hasDraft -and -not $hasNotes) { return 'DraftMissingNotes' }
    if ($hasDraft -and $hasNotes -and -not $hasQa) { return 'DraftUnstamped' }
    return 'Missing'
}

function Write-Next {
    param(
        [int]$ArcNum,
        [int]$Chapter,
        [string]$Action,
        [string]$Prompt,
        [string]$Command,
        [string]$Reason
    )

    $nnn = '{0:D3}' -f $Chapter
    Write-Host "[NEXT] Arc $ArcNum ch$nnn -> $Action" -ForegroundColor Green
    Write-Host "Prompt: $Prompt" -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        Write-Host "After artifact command:" -ForegroundColor Cyan
        Write-Host "  $Command" -ForegroundColor Gray
    }
    Write-Host "Reason: $Reason" -ForegroundColor Yellow
}

$arcRows = Get-ArcRows
if ($arcRows.Count -eq 0) {
    Write-Host "[FAIL] ไม่พบ arc ที่ parse ได้ใน reports/batch-plan.md" -ForegroundColor Red
    Write-Host "       ต้องมีแถวรูป | 1 | 1-30 | A | ..." -ForegroundColor Yellow
    exit 1
}

if ([string]::IsNullOrEmpty($Arc)) {
    $arcRow = @($arcRows | Where-Object { $_.Phase -notmatch '^(?i)Shipped$' } | Select-Object -First 1)[0]
    if ($null -eq $arcRow) { $arcRow = $arcRows[-1] }
} else {
    $arcNumRequested = [int]($Arc -replace '\D', '')
    $arcRow = @($arcRows | Where-Object { $_.Arc -eq $arcNumRequested } | Select-Object -First 1)[0]
}

if ($null -eq $arcRow) {
    Write-Host "[FAIL] ไม่พบ arc $Arc ใน reports/batch-plan.md" -ForegroundColor Red
    exit 1
}

$statusMap = Get-StatusMap
$phase = $arcRow.Phase
$arcNum = $arcRow.Arc

# arc ที่ยังไม่เปิดงานมักมี Phase เป็น '-' หรือว่างใน batch-plan (ค่าเริ่มต้นตอนวางแผน)
# ถือเป็น Phase A (draft+QA รายตอน) ไม่งั้นจะตกไป [DONE] ทั้งที่ยังไม่ได้แปลสักตอน
if ([string]::IsNullOrWhiteSpace($phase) -or $phase -match '^[-–—]$') {
    Write-Host "[STATE] Arc $arcNum Phase=$phase (ยังไม่เปิดงาน) -> ถือเป็น Phase A; ควรตั้ง Phase=A ใน reports/batch-plan.md" -ForegroundColor Yellow
    $phase = 'A'
}

Write-Host "[STATE] Arc $arcNum Phase=$phase Chapters=$($arcRow.Start)-$($arcRow.End)" -ForegroundColor Cyan

if ($phase -match '^(?i)A') {
    for ($ch = $arcRow.Start; $ch -le $arcRow.End; $ch++) {
        $status = if ($statusMap.ContainsKey($ch)) { $statusMap[$ch] } else { '' }
        $stage = Get-StageFromEvidence $ch $status
        switch -Regex ($stage) {
            '^Missing$' {
                Write-Next $arcNum $ch 'translate' 'prompts/01-translate-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage draft -Arc $arcNum" 'ยังไม่มี draft+notes ที่ผ่าน status'
                exit 0
            }
            '^DraftMissingNotes$' {
                Write-Next $arcNum $ch 'write-translation-notes' 'reports/chNNN-translation-notes-template.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage draft -Arc $arcNum" 'มี draft แต่ยังไม่มี translation notes'
                exit 0
            }
            '^Draft$|^DraftUnstamped$' {
                Write-Next $arcNum $ch 'qa' 'prompts/02-qa-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage qa -Verdict Pass" 'มี draft+notes แล้ว แต่ยังไม่ QA ผ่าน'
                exit 0
            }
            '^QA:\s*Needs-revision$' {
                Write-Next $arcNum $ch 'revise-after-qa' 'prompts/03-polish-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage edited" 'QA ตีกลับแบบแก้ได้'
                exit 0
            }
            '^QA:\s*Re-translate$' {
                Write-Next $arcNum $ch 're-translate' 'prompts/01-translate-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage draft -Arc $arcNum" 'QA ตีกลับหนัก'
                exit 0
            }
        }
    }

    Write-Host "[NEXT] Arc $arcNum -> consistency-freeze" -ForegroundColor Green
    Write-Host "Prompt: prompts/05-consistency-range.md" -ForegroundColor Cyan
    Write-Host "After report command:" -ForegroundColor Cyan
    Write-Host "  powershell -File etc/complete-stage.ps1 -Arc $arcNum -Stage phase-b-ready" -ForegroundColor Gray
    Write-Host "Reason: ทุกตอนใน Phase A ถึง QA pass/pass-minor แล้ว" -ForegroundColor Yellow
    exit 0
}

if ($phase -match '^(?i)B') {
    for ($ch = $arcRow.Start; $ch -le $arcRow.End; $ch++) {
        $status = if ($statusMap.ContainsKey($ch)) { $statusMap[$ch] } else { '' }
        if ($status -match '^QA:\s*(Pass|Pass-minor)$') {
            Write-Next $arcNum $ch 'polish' 'prompts/03-polish-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage edited" 'Phase B ต้องเกลาตอนที่ QA ผ่านแล้ว'
            exit 0
        }
    }
    Write-Host "[NEXT] Arc $arcNum -> phase-c-ready" -ForegroundColor Green
    Write-Host "Command: powershell -File etc/complete-stage.ps1 -Arc $arcNum -Stage phase-c-ready" -ForegroundColor Gray
    exit 0
}

if ($phase -match '^(?i)C') {
    for ($ch = $arcRow.Start; $ch -le $arcRow.End; $ch++) {
        $status = if ($statusMap.ContainsKey($ch)) { $statusMap[$ch] } else { '' }
        if ($status -eq 'Edited') {
            Write-Next $arcNum $ch 'finalize' 'prompts/06-finalize-chapter.md' "powershell -File etc/complete-stage.ps1 -Chapter $ch -Stage final" 'Phase C ต้อง finalize ตอนที่ Edited แล้ว'
            exit 0
        }
    }
    Write-Host "[NEXT] Arc $arcNum -> ship" -ForegroundColor Green
    Write-Host "Command: powershell -File etc/complete-stage.ps1 -Arc $arcNum -Stage ship" -ForegroundColor Gray
    exit 0
}

Write-Host "[DONE] Arc $arcNum phase is $phase" -ForegroundColor Green
exit 0
