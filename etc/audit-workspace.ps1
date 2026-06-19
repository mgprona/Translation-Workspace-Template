<#
.SYNOPSIS
    ตรวจ workspace จริงแบบ end-to-end เพื่อจับปัญหาที่ gate รายขั้นอาจมองไม่เห็น

.DESCRIPTION
    ใช้หลังทำงานหลายตอนหรือก่อนส่งมอบ arc เพื่อตรวจหลักฐานจริงจากไฟล์ ไม่เชื่อแค่ตารางสถานะ:
    - แถว status อ้าง stage แล้วไฟล์จริงไม่มี (phantom/missing chapter)
    - ไฟล์ chapter ใน draft/edited/final มี gap ในช่วงที่คาดหวัง
    - QA report ไม่มี line/paragraph reference จริง หรือใช้ location ลอยๆ เช่น Terminology/General
    - บทแปลมีเศษ CJK/Hangul/markup/วงเล็บอังกฤษ/mojibake

.PARAMETER Start
    ตอนเริ่มตรวจ เช่น 1

.PARAMETER End
    ตอนจบที่ต้องการตรวจ เช่น 10

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.PARAMETER CheckText
    สแกนเนื้อหา translation files หา CJK/Hangul/markup/EnglishGloss/mojibake ด้วย

.EXAMPLE
    powershell -File etc/audit-workspace.ps1 -Start 1 -End 10 -CheckText
#>

param(
    [int]$Start,
    [int]$End,
    [string]$RepoRoot,
    [switch]$CheckText
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

function Get-StatusRows {
    $statusFile = Join-Path $RepoRoot 'logs/chapter-status.md'
    $rows = @{}
    if (-not (Test-Path -LiteralPath $statusFile -PathType Leaf)) {
        return $rows
    }

    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $statusFile -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt 3 -or $cells[0] -notmatch '^\d+$') { continue }

        # New template format: Chapter | Arc | Status | Draft | QA | Edited | Final | ...
        # Short real-run format seen in the field: ตอน | Arc | Stage | Verdict | วันที่
        # Older stage-column format: Chapter | Draft | QA | Edited | Final | Notes
        # Older status-column format: Chapter | Status | Quality | Assigned To | Last Updated | Notes
        $chapter = [int]$cells[0]
        $status = ''
        if ($cells.Count -ge 3 -and $cells[1] -match '^\d+$') {
            $status = $cells[2]
        } elseif (
            $cells.Count -ge 6 -and
            (
                $cells[1] -match '(?i)\bDone\b|thai_draft/' -or
                $cells[2] -match '(?i)Pass|Needs|Re-translate|qa/reports/' -or
                $cells[3] -match '(?i)\bDone\b|thai_edited/' -or
                $cells[4] -match '(?i)\bDone\b|thai_final/'
            )
        ) {
            if ($cells[4] -match '(?i)\bDone\b|thai_final/') {
                $status = 'Final'
            } elseif ($cells[3] -match '(?i)\bDone\b|thai_edited/') {
                $status = 'Edited'
            } elseif ($cells[2] -match '(?i)Pass with minor fixes|Pass-minor') {
                $status = 'QA: Pass-minor'
            } elseif ($cells[2] -match '(?i)\bPass\b') {
                $status = 'QA: Pass'
            } elseif ($cells[2] -match '(?i)Needs-revision|Needs revision') {
                $status = 'QA: Needs-revision'
            } elseif ($cells[2] -match '(?i)Re-translate') {
                $status = 'QA: Re-translate'
            } elseif ($cells[1] -match '(?i)\bDone\b|thai_draft/') {
                $status = 'Draft'
            }
        } else {
            $status = $cells[1]
        }
        $rows[$chapter] = $status
    }
    return $rows
}

function Find-ChapterNumbers {
    $numbers = @()
    foreach ($dir in @('thai_draft', 'thai_edited', 'thai_final', 'qa/reports', 'sources/eng_clean_chapter')) {
        $full = Join-Path $RepoRoot $dir
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $full -File -ErrorAction SilentlyContinue)) {
            if ($f.Name -match '^ch(\d{3})(?:-qa)?\.(?:md|txt)$') {
                $numbers += [int]$Matches[1]
            }
        }
    }
    return @($numbers | Sort-Object -Unique)
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Severity,
        [string]$Kind,
        [int]$Chapter,
        [string]$Detail
    )
    $Issues.Add([PSCustomObject]@{
        Severity = $Severity
        Kind     = $Kind
        Chapter  = $Chapter
        Detail   = $Detail
    }) | Out-Null
}

$numbers = Find-ChapterNumbers
if (-not $PSBoundParameters.ContainsKey('Start')) {
    if ($numbers.Count -gt 0) { $Start = ($numbers | Measure-Object -Minimum).Minimum } else { $Start = 1 }
}
if (-not $PSBoundParameters.ContainsKey('End')) {
    if ($numbers.Count -gt 0) { $End = ($numbers | Measure-Object -Maximum).Maximum } else { $End = $Start }
}
if ($End -lt $Start) {
    Write-Host "[ERROR] -End ต้องมากกว่าหรือเท่ากับ -Start" -ForegroundColor Red
    exit 2
}

$issues = [System.Collections.Generic.List[object]]::new()
$statusRows = Get-StatusRows

for ($ch = $Start; $ch -le $End; $ch++) {
    $nnn = '{0:D3}' -f $ch
    $draft = "thai_draft/ch$nnn.md"
    $qa = "qa/reports/ch$nnn-qa.md"
    $edited = "thai_edited/ch$nnn.md"
    $final = "thai_final/ch$nnn.md"

    $hasDraft = Test-RelFile $draft
    $hasQa = Test-RelFile $qa
    $hasEdited = Test-RelFile $edited
    $hasFinal = Test-RelFile $final

    if (-not $statusRows.ContainsKey($ch) -and -not $hasDraft -and -not $hasQa -and -not $hasEdited -and -not $hasFinal) {
        Add-Issue $issues 'block' 'chapter-evidence-missing' $ch "ไม่มี status row หรือไฟล์ stage ใดๆ สำหรับช่วงที่สั่งตรวจ"
        continue
    }

    if ($statusRows.ContainsKey($ch)) {
        $status = $statusRows[$ch]
        if ($status -match '^Draft' -and -not $hasDraft) {
            Add-Issue $issues 'block' 'status-file-missing' $ch "Status=$status แต่ไม่มี $draft"
        }
        if ($status -match '^QA:' -and (-not $hasDraft -or -not $hasQa)) {
            Add-Issue $issues 'block' 'status-file-missing' $ch "Status=$status แต่ไม่มี draft/QA ครบ"
        }
        if ($status -eq 'Edited' -and (-not $hasDraft -or -not $hasQa -or -not $hasEdited)) {
            Add-Issue $issues 'block' 'status-file-missing' $ch "Status=Edited แต่ไฟล์ก่อนหน้าไม่ครบ"
        }
        if ($status -eq 'Final' -and (-not $hasDraft -or -not $hasQa -or -not $hasEdited -or -not $hasFinal)) {
            Add-Issue $issues 'block' 'status-file-missing' $ch "Status=Final แต่ไม่มี draft/QA/edited/final ครบ"
        }
    }

    if ($hasQa) {
        $qaText = Get-Content -LiteralPath (Join-Path $RepoRoot $qa) -Raw -Encoding UTF8
        if ($qaText -match '\|\s*(critical|major|minor)\s*\|\s*(-|Terminology|General)\s*\|') {
            Add-Issue $issues 'warn' 'qa-weak-location' $ch "$qa ใช้ location ลอยๆ"
        }
        if ($qaText -notmatch '(?:^|\W)(?:L\d+|line\s*\d+|บรรทัด\s*\d+|ย่อหน้า\s*\d+)(?:\W|$)') {
            Add-Issue $issues 'warn' 'qa-no-line-reference' $ch "$qa ไม่มี line/paragraph reference จริง"
        }
        if (($qaText -match 'Pass with minor fixes|Pass-minor') -and ($qaText -notmatch '\|\s*(critical|major|minor)\s*\|')) {
            Add-Issue $issues 'block' 'qa-verdict-contradiction' $ch "$qa verdict minor แต่ไม่มี issue row"
        }
    }

    if ($CheckText) {
        foreach ($rel in @($draft, $edited, $final)) {
            if (-not (Test-RelFile $rel)) { continue }
            $text = Get-Content -LiteralPath (Join-Path $RepoRoot $rel) -Raw -Encoding UTF8
            $bad = @()
            if ($text -match '[一-鿿]') { $bad += 'CJK' }
            if ($text -match '[가-힯]') { $bad += 'Hangul' }
            if ($text -match '\[/?\w+[\w="]*\]|</?\w+>') { $bad += 'Markup' }
            if ($text -match '[\(（][^)）]*[A-Za-z]{2,}[^)）]*[\)）]') { $bad += 'EnglishGloss' }
            if ($text -match '(เธ[฀-๿]){2,}|เน€เธ|เธย|เธฒเธ|เน„เธ|เธ"เน') { $bad += 'Mojibake' }
            if ($bad.Count -gt 0) {
                Add-Issue $issues 'block' 'text-leak' $ch "$rel พบ $($bad -join ',')"
            }
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Host "[PASS] Workspace audit ผ่านสำหรับ ch$('{0:D3}' -f $Start)-ch$('{0:D3}' -f $End)" -ForegroundColor Green
    exit 0
}

$blocking = @($issues | Where-Object { $_.Severity -eq 'block' })
if ($blocking.Count -gt 0) {
    Write-Host "[FAIL] Workspace audit พบ $($issues.Count) issue ($($blocking.Count) block) สำหรับ ch$('{0:D3}' -f $Start)-ch$('{0:D3}' -f $End)" -ForegroundColor Red
} else {
    Write-Host "[WARN] Workspace audit พบ $($issues.Count) warning สำหรับ ch$('{0:D3}' -f $Start)-ch$('{0:D3}' -f $End)" -ForegroundColor Yellow
}
foreach ($issue in $issues) {
    Write-Host ("  [{0}] ch{1:D3} {2}: {3}" -f $issue.Severity, $issue.Chapter, $issue.Kind, $issue.Detail) -ForegroundColor Yellow
}

if ($blocking.Count -gt 0) { exit 1 }
exit 0
