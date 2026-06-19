<#
.SYNOPSIS
    เขียนสถานะตอนลง logs/chapter-status.md ผ่านสคริปต์ที่ตรวจไฟล์จริงก่อน — กันสถานะโกหก

.DESCRIPTION
    แก้ปัญหาจากงานจริง 2 ข้อ:
    1. โมเดลตั้งสถานะ "Final" ให้ตอนที่ไฟล์แปลไม่มีจริง (phantom chapter)
    2. timestamp ถูก backfill วันเดียวกันหมด ตรวจสอบย้อนหลังไม่ได้

    สคริปต์นี้:
    - ตรวจว่าไฟล์ output ของ stage ที่อ้างมีอยู่จริง ถ้าไม่มี = ปฏิเสธ (exit 1) เขียนสถานะไม่ได้
    - ตรวจว่า stage ก่อนหน้ามีไฟล์จริงครบก่อนเลื่อนสถานะ (QA ต้องมี draft, Edited ต้องมี draft+QA, Final ต้องมี draft+QA+edited)
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

$SelfDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($SelfDir)) {
    $SelfDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Invoke-GateProcess {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    Write-Host "[GATE] $Name" -ForegroundColor Cyan
    & powershell @Arguments
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    if ($exitCode -ne 0) {
        Write-Host "[FAIL] Gate '$Name' ไม่ผ่าน (exit $exitCode) — ห้ามตั้งสถานะ '$Stage'" -ForegroundColor Red
        exit 1
    }
}

function Test-QaReportEvidence {
    param(
        [string]$QaPath,
        [string]$VerdictValue
    )

    $qaText = Get-Content -LiteralPath $QaPath -Raw -Encoding UTF8
    $failures = @()

    if ($qaText -notmatch '(?:^|\W)(?:L\d+|line\s*\d+|บรรทัด\s*\d+|ย่อหน้า\s*\d+)(?:\W|$)') {
        $failures += 'QA report ไม่มี line/paragraph reference จริง'
    }
    if ($qaText -match '\|\s*(critical|major|minor)\s*\|\s*(-|Terminology|General)\s*\|') {
        $failures += 'QA report ใช้ Location ลอยๆ (-/Terminology/General) แทนบรรทัดจริง'
    }
    if ($VerdictValue -eq 'Pass-minor' -and $qaText -notmatch '\|\s*(critical|major|minor)\s*\|') {
        $failures += 'Verdict Pass-minor แต่ไม่มี issue row ระดับ minor/major/critical'
    }
    if ($VerdictValue -eq 'Pass' -and $qaText -match '\|\s*(critical|major)\s*\|') {
        $failures += 'Verdict Pass แต่ยังมี issue critical/major ในตาราง'
    }

    if ($failures.Count -gt 0) {
        Write-Host "[FAIL] QA report ไม่ผ่าน evidence gate:" -ForegroundColor Red
        foreach ($f in $failures) {
            Write-Host "  - $f" -ForegroundColor Yellow
        }
        exit 1
    }
    Write-Host "[PASS] QA report evidence ผ่าน" -ForegroundColor Green
}

function Get-StatusRank {
    param([string]$StatusValue)
    if ([string]::IsNullOrWhiteSpace($StatusValue)) { return 0 }
    switch -Regex ($StatusValue) {
        '^Draft$' { return 1 }
        '^QA:\s*(Needs-revision|Re-translate)' { return 2 }
        '^QA:\s*(Pass|Pass-minor)' { return 3 }
        '^Edited$' { return 4 }
        '^Final$' { return 5 }
        default { return 0 }
    }
}

function Get-StatusFromRow {
    param([string]$Row)
    if ([string]::IsNullOrWhiteSpace($Row)) { return '' }
    $parts = $Row.Trim('|').Split('|')
    if ($parts.Count -ge 3) { return $parts[2].Trim() }
    return ''
}

function Open-StatusLock {
    param([string]$Path)

    $deadline = (Get-Date).AddSeconds(30)
    do {
        try {
            return [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 200
        }
    } while ((Get-Date) -lt $deadline)

    Write-Host "[FAIL] รอ lock chapter-status.md เกิน 30 วินาที — มี process อื่นเขียนสถานะค้างอยู่" -ForegroundColor Red
    exit 1
}

# resolve RepoRoot แบบ robust ($PSScriptRoot ว่างได้บน PS 5.1 บางบริบท)
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $RepoRoot = Split-Path -Parent $SelfDir
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

# ตรวจ dependency ของ stage ก่อนหน้า — กันสถานะปลายทางทับ phantom/missing chapter
$requiredBefore = switch ($Stage) {
    'draft'  { @() }
    'qa'     { @("thai_draft/ch$nnn.md") }
    'edited' { @("thai_draft/ch$nnn.md", "qa/reports/ch$nnn-qa.md") }
    'final'  { @("thai_draft/ch$nnn.md", "qa/reports/ch$nnn-qa.md", "thai_edited/ch$nnn.md") }
}
foreach ($rel in $requiredBefore) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Write-Host "[FAIL] ตอน $nnn : stage '$Stage' ต้องมีไฟล์ก่อนหน้า '$rel' จริง" -ForegroundColor Red
        Write-Host "[STOP] ห้ามเลื่อนสถานะโดยที่ pipeline ก่อนหน้าไม่ครบ" -ForegroundColor Yellow
        exit 1
    }
}

if ($Stage -eq 'qa' -and [string]::IsNullOrEmpty($Verdict)) {
    Write-Host "[ERROR] stage 'qa' ต้องระบุ -Verdict (Pass / Pass-minor / Needs-revision / Re-translate)" -ForegroundColor Red
    exit 2
}

# ── 1b. Gate เสริมจาก production failures ──
$etcDir = $SelfDir
$verifyNotesScript = Join-Path $etcDir 'verify-notes.ps1'
$thaiTextScript = Join-Path $etcDir 'verify-thai-text.ps1'
$termScript = Join-Path $etcDir 'term-extract.ps1'
$encodingScript = Join-Path $etcDir 'check-encoding.ps1'

if ($Stage -eq 'draft' -or $Stage -eq 'qa') {
    if (Test-Path -LiteralPath $verifyNotesScript -PathType Leaf) {
        Invoke-GateProcess 'translation notes' @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', $verifyNotesScript,
            '-Chapter', $nnn,
            '-RepoRoot', $RepoRoot
        )
    }
}

if ($Stage -eq 'qa') {
    Test-QaReportEvidence -QaPath $stageFull -VerdictValue $Verdict
}

if ($Stage -in @('draft', 'edited', 'final') -and (Test-Path -LiteralPath $thaiTextScript -PathType Leaf)) {
    $sourcePathForThaiGate = Join-Path $RepoRoot "sources/eng_clean_chapter/ch$nnn.txt"
    Invoke-GateProcess "Thai text sanity ($stageFile)" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $thaiTextScript,
        '-TargetPath', $stageFull,
        '-SourcePath', $sourcePathForThaiGate
    )
}

if ($Stage -in @('draft', 'edited', 'final') -and (Test-Path -LiteralPath $termScript -PathType Leaf)) {
    Invoke-GateProcess "term scan ($stageFile)" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $termScript,
        '-TargetPath', $stageFull,
        '-OkfPath', (Join-Path $RepoRoot 'okf'),
        '-FailOnIssue',
        '-ReportOnly'
    )
}

if ($Stage -in @('edited', 'final') -and (Test-Path -LiteralPath $encodingScript -PathType Leaf)) {
    Invoke-GateProcess "encoding scan ($stageFile)" @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $encodingScript,
        '-TargetPath', $stageFull
    )
}

# ── 2. คำนวณค่าคอลัมน์ ──
$statusFile = Join-Path $RepoRoot 'logs/chapter-status.md'
if (-not (Test-Path -LiteralPath $statusFile)) {
    Write-Host "[ERROR] ไม่พบ logs/chapter-status.md" -ForegroundColor Red
    exit 2
}

# timestamp จริงจากนาฬิกาเครื่อง (กัน backfill) และบังคับ ค.ศ. ไม่ขึ้นกับ regional setting
$today = (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)

$lockPath = Join-Path $RepoRoot 'logs/chapter-status.lock'
$lockStream = $null
try {
    $lockStream = Open-StatusLock $lockPath

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
    $existingStatus = Get-StatusFromRow $existingRow

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

    # อัปเดตเซลล์ + candidate Status ตาม stage
    switch ($Stage) {
        'draft' {
            $candidateStatus = 'Draft'
            $cells.Draft = "``thai_draft/ch$nnn.md``"
        }
        'qa' {
            $candidateStatus = "QA: $Verdict"
            $cells.QA = "$Verdict`: ``qa/reports/ch$nnn-qa.md``"
        }
        'edited' {
            $candidateStatus = 'Edited'
            $cells.Edited = "``thai_edited/ch$nnn.md``"
        }
        'final' {
            $candidateStatus = 'Final'
            $cells.Final = "``thai_final/ch$nnn.md``"
        }
    }
    if (-not [string]::IsNullOrEmpty($Notes)) { $cells.Notes = $Notes }

    if ((Get-StatusRank $existingStatus) -gt (Get-StatusRank $candidateStatus)) {
        $status = $existingStatus
        Write-Host "[INFO] ตอน $nnn : คงสถานะ '$existingStatus' เพราะสูงกว่า '$candidateStatus' (forward-only)" -ForegroundColor Cyan
    } else {
        $status = $candidateStatus
    }

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
}
finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
}

Write-Host "[OK] ตอน $nnn : ตั้งสถานะ '$status' (ไฟล์ $stageFile ยืนยันแล้ว, อัปเดต $today)" -ForegroundColor Green
exit 0
