<#
.SYNOPSIS
    Gate ตรวจ OKF ตาม okf/index.md — กันอัปเดตไม่ครบไฟล์และ metadata ค้าง

.DESCRIPTION
    จากงานจริง OKF มีหลายไฟล์ตาม index แต่ agent อัปเดตเพียงบางไฟล์ แล้วข้าม files สำคัญ
    เช่น places.md, voice-register.md, chapter-registry.md, source-map.md

    สคริปต์นี้ใช้ okf/index.md เป็น canonical list แล้วตรวจ:
    - ไฟล์ที่ index อ้างมีอยู่จริงและไม่ว่าง
    - ไม่มี placeholder `{DATE}` / `{NOVEL_NAME}` ใน OKF
    - ไฟล์ metadata สำคัญมีแถวข้อมูลจริงนอก HTML comment
    - ช่วงตอนที่ระบุมี chapter-registry/title-registry/source-map ครอบคลุมพอ

.PARAMETER Start
    ตอนเริ่มตรวจ เช่น 1

.PARAMETER End
    ตอนจบ เช่น 33

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.PARAMETER CheckAllFiles
    ตรวจไฟล์ทุกตัวที่ okf/index.md อ้าง (ค่าแนะนำก่อน freeze/ship)

.PARAMETER RequireRangeMetadata
    บังคับ metadata รายตอนสำหรับ chapter-registry/title-registry/source-map ในช่วง Start-End

.PARAMETER MinBytes
    ขนาดขั้นต่ำของ OKF file ที่ถือว่าไม่ใช่ stub ค่าเริ่มต้น 80 ไบต์

.EXAMPLE
    powershell -File etc/verify-okf.ps1 -Start 1 -End 33 -CheckAllFiles -RequireRangeMetadata
#>

param(
    [int]$Start,
    [int]$End,

    [string]$RepoRoot,

    [switch]$CheckAllFiles,

    [switch]$RequireRangeMetadata,

    [int]$MinBytes = 80
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = Split-Path -Parent $scriptDir
}

$okfDir = Join-Path $RepoRoot 'okf'
$indexFile = Join-Path $okfDir 'index.md'

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Severity,
        [string]$File,
        [string]$Detail
    )
    $Issues.Add([PSCustomObject]@{
        Severity = $Severity
        File     = $File
        Detail   = $Detail
    }) | Out-Null
}

function Get-IndexOkfFiles {
    param([string]$IndexPath)
    $files = [System.Collections.Generic.List[string]]::new()
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $IndexPath -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        foreach ($m in [regex]::Matches($line, '\[[^\]]+\]\(([^)]+\.md)\)')) {
            $path = $m.Groups[1].Value.Trim()
            if ($path -notmatch '^[a-zA-Z0-9._/-]+\.md$') { continue }
            $files.Add($path) | Out-Null
        }
    }
    return @($files | Sort-Object -Unique)
}

function Get-RealTableRows {
    param([string]$Path)
    $rows = @()
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $rows }
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -eq 0) { continue }
        if ($cells[0] -match '^(?i)(Chapter|Source|English|Term|Arc|Status|Character\s*(?:/.*)?|วันที่|แก้ใน Arc|---|\s*-+)$') { continue }
        if ($line -match '^\|\s*-+') { continue }
        $rows += ,$cells
    }
    return $rows
}

function Find-ChapterFiles {
    param(
        [string]$Dir,
        [string]$Ext
    )
    $set = [System.Collections.Generic.HashSet[int]]::new()
    $full = Join-Path $RepoRoot $Dir
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return $set }
    foreach ($f in (Get-ChildItem -LiteralPath $full -File -Filter "*.$Ext" -ErrorAction SilentlyContinue)) {
        if ($f.Name -match '^ch(\d{3})\.' + [regex]::Escape($Ext) + '$') {
            $null = $set.Add([int]$Matches[1])
        }
    }
    return $set
}

function Test-RowHasChapter {
    param(
        [object[]]$Rows,
        [int]$Chapter
    )
    foreach ($cells in $Rows) {
        if ($cells.Count -gt 0 -and $cells[0] -match '^\d+$' -and [int]$cells[0] -eq $Chapter) {
            return $true
        }
    }
    return $false
}

function Get-ChapterRow {
    param(
        [object[]]$Rows,
        [int]$Chapter
    )
    foreach ($cells in $Rows) {
        if ($cells.Count -gt 0 -and $cells[0] -match '^\d+$' -and [int]$cells[0] -eq $Chapter) {
            return $cells
        }
    }
    return $null
}

function Get-NotesSectionBody {
    param(
        [string]$Text,
        [string]$Heading
    )
    $pattern = '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(.*?)(?=^##\s+|\z)'
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value.Trim()
}

function Test-LazyNotesBody {
    param([string]$Body)
    if ($null -eq $Body) { return $true }
    $clean = $Body.Trim()
    $clean = $clean -replace '(?m)^\s*[-*]\s*', ''
    $clean = $clean -replace '[`*_>\s]', ''
    if ([string]::IsNullOrWhiteSpace($clean)) { return $true }
    if ($clean -match '(ตรวจแล้วไม่มีชื่อเฉพาะใหม่|ตรวจแล้วไม่พบชื่อเฉพาะใหม่|no new proper nouns|no new terms after checking)') { return $true }
    return ($clean -match '^(?i:none|n/a|null|nil|ไม่มี|ไม่พบ|-)+$')
}

function Test-CoverageCoversRange {
    param(
        [string]$Coverage,
        [int]$StartChapter,
        [int]$EndChapter
    )
    if ([string]::IsNullOrWhiteSpace($Coverage)) { return $false }
    if ($Coverage -match 'Chapters\s+(\d+)\s*[-–]\s*(\d+|N)') {
        $from = [int]$Matches[1]
        if ($Matches[2] -eq 'N') { return ($StartChapter -ge $from) }
        $to = [int]$Matches[2]
        return ($StartChapter -ge $from -and $EndChapter -le $to)
    }
    return $false
}

if (-not (Test-Path -LiteralPath $indexFile -PathType Leaf)) {
    Write-Host "[ERROR] ไม่พบ okf/index.md" -ForegroundColor Red
    exit 2
}

$issues = [System.Collections.Generic.List[object]]::new()
$okfFiles = Get-IndexOkfFiles $indexFile
if ($okfFiles.Count -eq 0) {
    Add-Issue $issues 'block' 'okf/index.md' 'index.md ไม่มีลิงก์ไฟล์ OKF ใดๆ'
}

if ($CheckAllFiles) {
    foreach ($rel in $okfFiles) {
        $full = Join-Path $okfDir $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Add-Issue $issues 'block' "okf/$rel" 'ไฟล์นี้ถูกอ้างใน index.md แต่ไม่มีจริง'
            continue
        }
        $size = (Get-Item -LiteralPath $full).Length
        if ($size -lt $MinBytes) {
            Add-Issue $issues 'block' "okf/$rel" "ไฟล์เล็กผิดปกติ ($size ไบต์ < $MinBytes) — น่าจะยังเป็น stub"
        }
        $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        if ($text -match '\{DATE\}|\{NOVEL_NAME\}|\{CHAPTER_NUMBER\}|\{NNN\}') {
            Add-Issue $issues 'block' "okf/$rel" 'ยังมี placeholder จาก template'
        }
    }
}

$criticalTables = @(
    'source-map.md',
    'chapter-registry.md',
    'title-registry.md'
)
foreach ($rel in $criticalTables) {
    if ($okfFiles -contains $rel) {
        $rows = Get-RealTableRows (Join-Path $okfDir $rel)
        if ($rows.Count -eq 0) {
            Add-Issue $issues 'block' "okf/$rel" 'ไม่มีแถวข้อมูลจริงนอก comment'
        }
    }
}

if ($RequireRangeMetadata) {
    if (-not $PSBoundParameters.ContainsKey('Start') -or -not $PSBoundParameters.ContainsKey('End')) {
        Write-Host "[ERROR] -RequireRangeMetadata ต้องระบุ -Start และ -End" -ForegroundColor Red
        exit 2
    }
    if ($End -lt $Start) {
        Write-Host "[ERROR] -End ต้องมากกว่าหรือเท่ากับ -Start" -ForegroundColor Red
        exit 2
    }

    $chapterRows = Get-RealTableRows (Join-Path $okfDir 'chapter-registry.md')
    $titleRows = Get-RealTableRows (Join-Path $okfDir 'title-registry.md')
    $sourceRows = Get-RealTableRows (Join-Path $okfDir 'source-map.md')
    $sourceMapText = ''
    $sourceMapPath = Join-Path $okfDir 'source-map.md'
    if (Test-Path -LiteralPath $sourceMapPath -PathType Leaf) {
        $sourceMapText = Get-Content -LiteralPath $sourceMapPath -Raw -Encoding UTF8
    }

    $engFiles = Find-ChapterFiles 'sources/eng_clean_chapter' 'txt'
    $rawFiles = Find-ChapterFiles 'sources/raw_chapter' 'txt'

    for ($ch = $Start; $ch -le $End; $ch++) {
        if ($engFiles.Contains($ch)) {
            $chapterRow = Get-ChapterRow $chapterRows $ch
            if ($null -eq $chapterRow) {
                Add-Issue $issues 'block' 'okf/chapter-registry.md' ("ขาด metadata ตอน ch{0:D3}" -f $ch)
            } elseif ($chapterRow.Count -lt 4 -or [string]::IsNullOrWhiteSpace($chapterRow[3])) {
                Add-Issue $issues 'block' 'okf/chapter-registry.md' ("แถว ch{0:D3} ยังไม่มี Coverage" -f $ch)
            }

            $titleRow = Get-ChapterRow $titleRows $ch
            if ($null -eq $titleRow) {
                Add-Issue $issues 'block' 'okf/title-registry.md' ("ยังไม่มีแถวชื่อบท/สถานะสำหรับ ch{0:D3} (ใช้ etc/update-title-registry.ps1 ช่วยเติมได้)" -f $ch)
            } elseif ($titleRow.Count -lt 5 -or [string]::IsNullOrWhiteSpace($titleRow[3]) -or [string]::IsNullOrWhiteSpace($titleRow[4])) {
                Add-Issue $issues 'block' 'okf/title-registry.md' ("แถว ch{0:D3} ต้องมี Thai title และ Status" -f $ch)
            }
        }
    }

    if ($sourceRows.Count -gt 0) {
        $engCount = $engFiles.Count
        $rawCount = $rawFiles.Count

        $englishCoverageOk = $false
        foreach ($row in $sourceRows) {
            if ($row.Count -lt 5) { continue }
            $sourceName = $row[0]
            $filesCell = $row[2]
            $coverageCell = $row[4]

            if ($engCount -gt 0 -and $sourceName -match '(?i)English' -and $filesCell -match '^\s*N\s*$') {
                Add-Issue $issues 'block' 'okf/source-map.md' "ยังใช้ Files=N ทั้งที่พบ English chapter files $engCount ไฟล์"
            }
            if ($rawCount -gt 0 -and $sourceName -match '(?i)(Raw|Korean)' -and $filesCell -match '^\s*M\s*$') {
                Add-Issue $issues 'warn' 'okf/source-map.md' "ยังใช้ Files=M ทั้งที่พบ raw chapter files $rawCount ไฟล์"
            }
            if ($sourceName -match '(?i)English' -and (Test-CoverageCoversRange $coverageCell $Start $End)) {
                $englishCoverageOk = $true
            }
        }

        if ($engCount -gt 0 -and -not $englishCoverageOk) {
            Add-Issue $issues 'warn' 'okf/source-map.md' "English source coverage ไม่ชัดว่าครอบคลุม ch$('{0:D3}' -f $Start)-ch$('{0:D3}' -f $End)"
        }
    }

    $notesNeeds = @{
        Characters = $false
        Factions   = $false
        Places     = $false
        Terms      = $false
    }

    for ($ch = $Start; $ch -le $End; $ch++) {
        $nnn = '{0:D3}' -f $ch
        $notesPath = Join-Path $RepoRoot "reports/ch$nnn-translation-notes.md"
        if (-not (Test-Path -LiteralPath $notesPath -PathType Leaf)) {
            Add-Issue $issues 'block' 'reports/' ("ขาด translation notes สำหรับ ch$nnn")
            continue
        }
        $notesText = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
        if (-not (Test-LazyNotesBody (Get-NotesSectionBody $notesText 'New Characters (need OKF addition)'))) {
            $notesNeeds.Characters = $true
        }
        if (-not (Test-LazyNotesBody (Get-NotesSectionBody $notesText 'New Groups/Factions (need OKF addition)'))) {
            $notesNeeds.Factions = $true
        }
        if (-not (Test-LazyNotesBody (Get-NotesSectionBody $notesText 'New Places/Organizations (need OKF addition)'))) {
            $notesNeeds.Places = $true
        }
        if (-not (Test-LazyNotesBody (Get-NotesSectionBody $notesText 'New Terms (need OKF addition)'))) {
            $notesNeeds.Terms = $true
        }
    }

    $charactersRows = Get-RealTableRows (Join-Path $okfDir 'characters.md')
    $factionRows = Get-RealTableRows (Join-Path $okfDir 'factions.md')
    $placeRows = Get-RealTableRows (Join-Path $okfDir 'places.md')
    $termRows = Get-RealTableRows (Join-Path $okfDir 'terms.md')
    $voiceRows = Get-RealTableRows (Join-Path $okfDir 'voice-register.md')

    if ($notesNeeds.Characters -and $charactersRows.Count -eq 0) {
        Add-Issue $issues 'block' 'okf/characters.md' 'translation notes ระบุ New Characters แต่ characters.md ยังไม่มีแถวข้อมูลจริง'
    }
    if ($notesNeeds.Factions -and $factionRows.Count -eq 0) {
        Add-Issue $issues 'block' 'okf/factions.md' 'translation notes ระบุ New Groups/Factions แต่ factions.md ยังไม่มีแถวข้อมูลจริง'
    }
    if ($notesNeeds.Places -and $placeRows.Count -eq 0) {
        Add-Issue $issues 'block' 'okf/places.md' 'translation notes ระบุ New Places/Organizations แต่ places.md ยังไม่มีแถวข้อมูลจริง'
    }
    if ($notesNeeds.Terms -and $termRows.Count -eq 0) {
        Add-Issue $issues 'block' 'okf/terms.md' 'translation notes ระบุ New Terms แต่ terms.md ยังไม่มีแถวข้อมูลจริง'
    }
    if ($charactersRows.Count -gt 0 -and $voiceRows.Count -eq 0) {
        Add-Issue $issues 'block' 'okf/voice-register.md' 'characters.md มีตัวละครแล้ว แต่ voice-register.md ยังไม่มีเสียงตัวละครจริง'
    }
}

if ($issues.Count -eq 0) {
    Write-Host "[PASS] OKF gate ผ่าน ($($okfFiles.Count) files from okf/index.md)" -ForegroundColor Green
    exit 0
}

$blocking = @($issues | Where-Object { $_.Severity -eq 'block' })
if ($blocking.Count -gt 0) {
    Write-Host "[FAIL] OKF gate พบ $($issues.Count) issue ($($blocking.Count) block)" -ForegroundColor Red
} else {
    Write-Host "[WARN] OKF gate พบ $($issues.Count) warning" -ForegroundColor Yellow
}

foreach ($issue in $issues) {
    Write-Host ("  [{0}] {1}: {2}" -f $issue.Severity, $issue.File, $issue.Detail) -ForegroundColor Yellow
}

if ($blocking.Count -gt 0) { exit 1 }
exit 0
