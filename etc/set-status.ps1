<#
.SYNOPSIS
    เขียนสถานะตอนลง logs/chapter-status.md ผ่านสคริปต์ที่ตรวจไฟล์จริงก่อน — กันสถานะโกหก

.DESCRIPTION
    แก้ปัญหาจากงานจริง 2 ข้อ:
    1. โมเดลตั้งสถานะ "Final" ให้ตอนที่ไฟล์แปลไม่มีจริง (phantom chapter)
    2. timestamp ถูก backfill วันเดียวกันหมด ตรวจสอบย้อนหลังไม่ได้

    สคริปต์นี้:
    - ตรวจว่าไฟล์ output ของ stage ที่อ้างมีอยู่จริง ถ้าไม่มี = ปฏิเสธ (exit 1) เขียนสถานะไม่ได้
    - เขียน timestamp จริงจากนาฬิกาเครื่อง
    - เพิ่มหรือแก้แถวของตอนนั้นใน chapter-status.md (markdown table) ให้อัตโนมัติ

    คอลัมน์: | Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |

.PARAMETER Chapter
    เลขตอน เช่น 22 หรือ 022

.PARAMETER Arc
    เลข arc ที่ตอนนี้สังกัด (ดู reports/batch-plan.md) — ถ้าไม่ระบุจะคงค่าเดิมในแถว

.PARAMETER Stage
    stage ที่เพิ่งทำเสร็จ: draft | qa | edited | final
    - draft  -> Status=Draft,            ตรวจ thai_draft/chNNN.md
    - qa     -> Status=ตาม Verdict,       ตรวจ qa/reports/chNNN-qa.md (ต้องระบุ -Verdict)
    - edited -> Status=Edited,           ตรวจ thai_edited/chNNN.md
    - final  -> Status=Final,            ตรวจ thai_final/chNNN.md

.PARAMETER Verdict
    เฉพาะ stage qa: Pass | Pass-minor | Needs-revision | Re-translate

.PARAMETER Notes
    ข้อความหมายเหตุ (optional)

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\set-status.ps1 -Chapter 5 -Stage draft
.EXAMPLE
    .\set-status.ps1 -Chapter 5 -Stage qa -Verdict Pass-minor
.EXAMPLE
    .\set-status.ps1 -Chapter 5 -Stage final -Notes "title locked"
.EXAMPLE
    .\set-status.ps1 -Chapter 5 -Stage draft -Arc 1
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Chapter,

    [Parameter(Mandatory = $true)]
    [ValidateSet('draft', 'qa', 'edited', 'final')]
    [string]$Stage,

    [ValidateSet('Pass', 'Pass-minor', 'Needs-revision', 'Re-translate')]
    [string]$Verdict,

    # เลข arc ที่ตอนนี้สังกัด (ดู reports/batch-plan.md) — ถ้าไม่ระบุจะคงค่าเดิมในแถว
    [string]$Arc,

    [string]$Notes = '',

    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# resolve RepoRoot แบบ robust ($PSScriptRoot ว่างได้บน PS 5.1 บางบริบท)
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = Split-Path -Parent $scriptDir
}

$num = ($Chapter -replace '\D', '')
if ([string]::IsNullOrEmpty($num)) {
    Write-Host "[ERROR] Chapter ไม่ถูกต้อง: '$Chapter'" -ForegroundColor Red
    exit 2
}
$chNum = [int]$num
$nnn = '{0:D3}' -f $chNum

# ── 1. ตรวจว่าไฟล์ output ของ stage มีจริง (กันสถานะโกหก) ──
$stageFile = @{
    draft  = "thai_draft/ch$nnn.md"
    qa     = "qa/reports/ch$nnn-qa.md"
    edited = "thai_edited/ch$nnn.md"
    final  = "thai_final/ch$nnn.md"
}[$Stage]

$stageFull = Join-Path $RepoRoot $stageFile
if (-not (Test-Path -LiteralPath $stageFull -PathType Leaf)) {
    Write-Host "[FAIL] ตอน $nnn : ไม่มีไฟล์ '$stageFile' จริง — เขียนสถานะ '$Stage' ไม่ได้" -ForegroundColor Red
    Write-Host "[STOP] ห้ามตั้งสถานะให้ตอนที่ยังไม่ได้ทำ stage นั้นจริง" -ForegroundColor Yellow
    exit 1
}

if ($Stage -eq 'qa' -and [string]::IsNullOrEmpty($Verdict)) {
    Write-Host "[ERROR] stage 'qa' ต้องระบุ -Verdict (Pass / Pass-minor / Needs-revision / Re-translate)" -ForegroundColor Red
    exit 2
}

# ── 2. คำนวณค่าคอลัมน์ ──
$statusFile = Join-Path $RepoRoot 'logs/chapter-status.md'
if (-not (Test-Path -LiteralPath $statusFile)) {
    Write-Host "[ERROR] ไม่พบ logs/chapter-status.md" -ForegroundColor Red
    exit 2
}

# timestamp จริงจากนาฬิกาเครื่อง (กัน backfill)
$today = (Get-Date).ToString('yyyy-MM-dd')

# อ่านแถวเดิมของตอนนี้ (ถ้ามี) เพื่อรักษาค่า stage ที่ทำไปแล้ว
$allLines = Get-Content -LiteralPath $statusFile -Encoding UTF8
$rowRegex = '^\|\s*' + $chNum + '\s*\|'

# หาแถวจริง (นอก HTML comment) — กันไป match/แก้แถวตัวอย่างใน <!-- ... -->
$realRowIndex = -1
$inComment = $false
for ($i = 0; $i -lt $allLines.Count; $i++) {
    $ln = $allLines[$i]
    if ($ln -match '<!--') { $inComment = $true }
    if ($inComment) { if ($ln -match '-->') { $inComment = $false }; continue }
    if ($ln -match $rowRegex) { $realRowIndex = $i; break }
}
$existingRow = if ($realRowIndex -ge 0) { $allLines[$realRowIndex] } else { $null }

# ค่าเริ่มต้นของเซลล์ (ดึงจากแถวเดิมถ้ามี)
$cells = @{ Arc = ''; Draft = ''; QA = ''; Edited = ''; Final = ''; Notes = '' }
if ($existingRow) {
    $parts = $existingRow.Trim('|').Split('|')
    # | Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |
    if ($parts.Count -ge 9) {
        $cells.Arc    = $parts[1].Trim()
        $cells.Draft  = $parts[3].Trim()
        $cells.QA     = $parts[4].Trim()
        $cells.Edited = $parts[5].Trim()
        $cells.Final  = $parts[6].Trim()
        $cells.Notes  = $parts[8].Trim()
    }
}

# ถ้าระบุ -Arc ให้ override; ถ้าไม่ระบุคงค่าเดิม
if (-not [string]::IsNullOrEmpty($Arc)) {
    $cells.Arc = ($Arc -replace '\D', '')
}

# อัปเดตเซลล์ + Status ตาม stage
switch ($Stage) {
    'draft' {
        $status = 'Draft'
        $cells.Draft = "``thai_draft/ch$nnn.md``"
    }
    'qa' {
        $status = "QA: $Verdict"
        $cells.QA = "$Verdict`: ``qa/reports/ch$nnn-qa.md``"
    }
    'edited' {
        $status = 'Edited'
        $cells.Edited = "``thai_edited/ch$nnn.md``"
    }
    'final' {
        $status = 'Final'
        $cells.Final = "``thai_final/ch$nnn.md``"
    }
}
if (-not [string]::IsNullOrEmpty($Notes)) { $cells.Notes = $Notes }

$newRow = "| $chNum | $($cells.Arc) | $status | $($cells.Draft) | $($cells.QA) | $($cells.Edited) | $($cells.Final) | $today | $($cells.Notes) |"

# ── 3. เขียนกลับ (แทนแถวเดิม หรือ append ต่อท้ายตาราง) ──
if ($realRowIndex -ge 0) {
    # แทนเฉพาะแถวจริงที่ index นั้น (ไม่แตะแถวตัวอย่างใน comment)
    $out = @($allLines)
    $out[$realRowIndex] = $newRow
} else {
    # แทรกแถวใหม่ก่อนหัวข้อ ## แรก (เช่น ## Status vocabulary)
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    foreach ($line in $allLines) {
        if (-not $inserted -and $line -match '^##\s') {
            $out.Add($newRow)
            $out.Add('')
            $inserted = $true
        }
        $out.Add($line)
    }
    if (-not $inserted) { $out.Add($newRow) }
}

Set-Content -LiteralPath $statusFile -Value $out -Encoding UTF8

Write-Host "[OK] ตอน $nnn : ตั้งสถานะ '$status' (ไฟล์ $stageFile ยืนยันแล้ว, อัปเดต $today)" -ForegroundColor Green
exit 0
