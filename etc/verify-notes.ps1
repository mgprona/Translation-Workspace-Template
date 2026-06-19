<#
.SYNOPSIS
    Gate ตรวจ Translation Notes รายตอน — กัน notes หาย/ลวก/ใส่ None ทุกช่อง

.DESCRIPTION
    จากงานจริง batch ใหญ่ทำให้ agent ข้าม logs/chNNN-notes.md หรือเขียนแบบ
    "None" ทุกหัวข้อ ทั้งที่ตอนนั้นมีชื่อเฉพาะและศัพท์ใหม่จำนวนมาก

    สคริปต์นี้ตรวจหลักฐานขั้นต่ำของ notes ก่อนอนุญาตให้ตั้งสถานะ Draft:
    - ไฟล์ notes มีจริงและไม่ใช่ stub
    - มีหัวข้อหลักครบตาม template
    - อ้าง source ของตอนนั้นจริง
    - ถ้า source มี proper noun/title-case candidates ต้องมีการกล่าวถึง candidate เหล่านั้นใน notes
    - ไม่ปล่อย placeholder เช่น {NNN}
    - ห้าม New Characters / Groups / Places / Terms เป็น none/ว่างพร้อมกัน เว้นแต่มีคำยืนยันว่า
      ตรวจ proper noun แล้วไม่มีชื่อเฉพาะใหม่ และมี Existing OKF Terms Used จริง
    - Points of Uncertainty ต้องมีเนื้อหา หรือระบุชัดว่า "ตรวจแล้วไม่มีจุดคลุมเครือ"

.PARAMETER Chapter
    เลขตอน เช่น 22 หรือ 022

.PARAMETER MinBytes
    ขนาดไฟล์ขั้นต่ำที่ถือว่าเป็น notes จริง ค่าเริ่มต้น 250 ไบต์

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/verify-notes.ps1 -Chapter 22
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Chapter,

    [int]$MinBytes = 250,

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

$num = ($Chapter -replace '\D', '')
if ([string]::IsNullOrEmpty($num)) {
    Write-Host "[ERROR] Chapter ไม่ถูกต้อง: '$Chapter'" -ForegroundColor Red
    exit 2
}
$chNum = [int]$num
$nnn = '{0:D3}' -f $chNum

$rel = "logs/ch$nnn-notes.md"
$full = Join-Path $RepoRoot $rel

function Add-Fail {
    param(
        [System.Collections.Generic.List[string]]$Failures,
        [string]$Message
    )
    $Failures.Add($Message) | Out-Null
}

function Get-SectionBody {
    param(
        [string]$Text,
        [string]$Heading
    )
    $pattern = '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(.*?)(?=^##\s+|\z)'
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value.Trim()
}

function Test-LazyBody {
    param([string]$Body)
    if ($null -eq $Body) { return $true }
    $clean = $Body.Trim()
    $clean = $clean -replace '(?m)^\s*[-*]\s*', ''
    $clean = $clean -replace '[`*_>\s]', ''
    if ([string]::IsNullOrWhiteSpace($clean)) { return $true }
    if ($clean -match '(ตรวจแล้วไม่มีชื่อเฉพาะใหม่|ตรวจแล้วไม่พบชื่อเฉพาะใหม่|no new proper nouns|no new terms after checking)') { return $true }
    return ($clean -match '^(?i:none|n/a|null|nil|ไม่มี|ไม่พบ|-)+$')
}

function Get-SourceCandidates {
    param([string]$SourcePath)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        return @()
    }

    $sourceText = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    $ignore = @(
        'Chapter', 'Send Me', 'The Past', 'Of Course', 'But The', 'At That',
        'In The', 'On The', 'For The', 'To The', 'And The'
    )

    foreach ($m in [regex]::Matches($sourceText, '\b[A-Z][A-Za-z''-]{2,}(?:\s+[A-Z][A-Za-z''-]{2,})+\b')) {
        $candidate = ($m.Value -replace '\s+', ' ').Trim()
        if ($candidate.Length -lt 5) { continue }
        if ($ignore -contains $candidate) { continue }
        if ($candidate -match '^Chapter\b') { continue }
        $candidates.Add($candidate) | Out-Null
    }

    return @($candidates | Sort-Object -Unique)
}

if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    Write-Host "[FAIL] ตอน $nnn : ไม่พบ Translation Notes" -ForegroundColor Red
    Write-Host "       คาดว่าต้องมี: $rel" -ForegroundColor Red
    Write-Host "[STOP] ห้ามตั้งสถานะ Draft จนกว่าจะเขียน notes จริง" -ForegroundColor Yellow
    exit 1
}

$size = (Get-Item -LiteralPath $full).Length
if ($size -lt $MinBytes) {
    Write-Host "[FAIL] ตอน $nnn : $rel มีขนาด $size ไบต์ (< $MinBytes) — น่าจะเป็น notes ลวกหรือ stub" -ForegroundColor Red
    exit 1
}

$text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
$failures = [System.Collections.Generic.List[string]]::new()

$requiredHeadings = @(
    'Source Files Used',
    'Chapter Title',
    'New Characters (need OKF addition)',
    'New Groups/Factions (need OKF addition)',
    'New Places/Organizations (need OKF addition)',
    'New Terms (need OKF addition)',
    'Existing OKF Terms Used',
    'Points of Uncertainty',
    'Draft Stats'
)

foreach ($heading in $requiredHeadings) {
    if ($text -notmatch ('(?m)^##\s+' + [regex]::Escape($heading) + '\s*$')) {
        Add-Fail $failures "ขาดหัวข้อ ## $heading"
    }
}

if ($text -match '\{NNN\}|\{CHAPTER_NUMBER\}|ch\{') {
    Add-Fail $failures "ยังมี placeholder จาก template เช่น {NNN}/{CHAPTER_NUMBER}"
}

if ($text -notmatch [regex]::Escape("sources/primary_chapter/ch$nnn.txt")) {
    Add-Fail $failures "ไม่อ้าง source หลักของตอนนี้: sources/primary_chapter/ch$nnn.txt"
}

$sourcePath = Join-Path $RepoRoot "sources/primary_chapter/ch$nnn.txt"
$sourceCandidates = @(Get-SourceCandidates $sourcePath)
if ($sourceCandidates.Count -gt 0) {
    $mentioned = @()
    foreach ($candidate in $sourceCandidates) {
        if ($text -match [regex]::Escape($candidate)) {
            $mentioned += $candidate
        }
    }
    $requiredMentions = [Math]::Min(2, $sourceCandidates.Count)
    if ($mentioned.Count -lt $requiredMentions) {
        Add-Fail $failures ("source มี proper noun candidates แต่ notes กล่าวถึงไม่พอ ({0}/{1}): {2}" -f $mentioned.Count, $requiredMentions, (($sourceCandidates | Select-Object -First 6) -join ', '))
    }
}

$newSections = @(
    'New Characters (need OKF addition)',
    'New Groups/Factions (need OKF addition)',
    'New Places/Organizations (need OKF addition)',
    'New Terms (need OKF addition)'
)

$lazyNewCount = 0
foreach ($heading in $newSections) {
    $body = Get-SectionBody $text $heading
    if (Test-LazyBody $body) { $lazyNewCount++ }
}

$existingBody = Get-SectionBody $text 'Existing OKF Terms Used'
$uncertaintyBody = Get-SectionBody $text 'Points of Uncertainty'
$draftStatsBody = Get-SectionBody $text 'Draft Stats'

if ($lazyNewCount -eq $newSections.Count) {
    $confirmedNoNew = ($text -match '(ตรวจแล้วไม่มีชื่อเฉพาะใหม่|ตรวจแล้วไม่พบชื่อเฉพาะใหม่|no new proper nouns|no new terms after checking)')
    if (-not $confirmedNoNew) {
        Add-Fail $failures "New Characters/Groups/Places/Terms ว่างหรือ None พร้อมกัน โดยไม่มีคำยืนยันว่าไล่ proper noun แล้ว"
    }
    if (Test-LazyBody $existingBody) {
        Add-Fail $failures "ถ้าไม่มีศัพท์ใหม่ ต้องมี Existing OKF Terms Used เป็นหลักฐานว่าเทียบ OKF แล้ว"
    }
}

if (Test-LazyBody $uncertaintyBody) {
    Add-Fail $failures "Points of Uncertainty ว่าง/None — ต้องมีอย่างน้อย 1 ข้อ หรือเขียนว่า 'ตรวจแล้วไม่มีจุดคลุมเครือ'"
} elseif ($uncertaintyBody -match '^(?is)\s*[-*]?\s*(none|n/a|ไม่มี|-)\s*$') {
    Add-Fail $failures "Points of Uncertainty ใช้ None ลอยๆ — ต้องระบุคำยืนยันแบบตรวจแล้ว"
}

if (Test-LazyBody $draftStatsBody) {
    Add-Fail $failures "Draft Stats ว่าง — ต้องมีหลักฐานจำนวนย่อหน้า/คำโดยคร่าว"
}

if ($failures.Count -gt 0) {
    Write-Host "[FAIL] Translation Notes ตอน $nnn ไม่ผ่าน gate:" -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host "  - $f" -ForegroundColor Yellow
    }
    Write-Host "[STOP] แก้ $rel ก่อนตั้งสถานะ Draft" -ForegroundColor Yellow
    exit 1
}

Write-Host "[PASS] ตอน $nnn : Translation Notes ผ่าน gate ($rel, $size ไบต์)" -ForegroundColor Green
exit 0
