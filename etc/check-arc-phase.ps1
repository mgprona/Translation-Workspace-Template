<#
.SYNOPSIS
    Gate หลักของ arc model — ตรวจว่า arc พร้อมเข้า Phase ถัดไปหรือยัง (อ่านสถานะจริงจากไฟล์)

.DESCRIPTION
    Arc model: แต่ละ arc (≈30 ตอน) เดิน Phase A (Draft+QA รายตอน) → B (Edit ทั้ง arc)
    → C (Final ทั้ง arc) → ship แต่ละรอยต่อมี gate บังคับ

    สคริปต์นี้อ่าน:
    - reports/batch-plan.md  -> หาช่วงตอนของ arc (คอลัมน์ Chapters รูป START-END)
    - logs/chapter-status.md -> หาสถานะรายตอนในช่วงนั้น
    - okf/arc-freeze-log.md  -> ตรวจ OKF freeze (เฉพาะ gate เข้า Phase B)

    แล้วตรวจเงื่อนไขตาม Phase ที่จะ "เข้า":
    - Phase B : ทุกตอนใน arc ต้อง QA: Pass หรือ QA: Pass-minor (ไม่มีตอนค้าง
                Draft / Needs-revision / Re-translate / ไม่มีแถว) + มี freeze ของ arc นี้
    - Phase C : ทุกตอนใน arc ต้อง Edited (หรือ Final)
    - ship    : ทุกตอนใน arc ต้อง Final

    exit 0 = ผ่าน เข้า Phase นั้นได้; exit 1 = ยังไม่พร้อม (รายงานตอนที่ค้าง)

.PARAMETER Arc
    เลข arc เช่น 1

.PARAMETER Phase
    Phase ที่ต้องการ "เข้า": B | C | ship

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\check-arc-phase.ps1 -Arc 1 -Phase B
    # ก่อนเริ่มเกลาทั้ง arc 1 — ผ่านเมื่อทุกตอน QA ผ่าน + freeze แล้ว
.EXAMPLE
    .\check-arc-phase.ps1 -Arc 1 -Phase C
.EXAMPLE
    .\check-arc-phase.ps1 -Arc 1 -Phase ship
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Arc,

    [Parameter(Mandatory = $true)]
    [ValidateSet('B', 'C', 'ship')]
    [string]$Phase,

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

$arcNum = [int]($Arc -replace '\D', '')
$planFile   = Join-Path $RepoRoot 'reports/batch-plan.md'
$statusFile = Join-Path $RepoRoot 'logs/chapter-status.md'
$freezeFile = Join-Path $RepoRoot 'okf/arc-freeze-log.md'

foreach ($f in @($planFile, $statusFile)) {
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "[ERROR] ไม่พบไฟล์: $f" -ForegroundColor Red
        exit 2
    }
}

# ── 1. หาช่วงตอนของ arc จาก batch-plan ──
$planLines = Get-Content -LiteralPath $planFile -Encoding UTF8
$arcStart = $null; $arcEnd = $null
$inComment = $false
foreach ($line in $planLines) {
    if ($line -match '<!--') { $inComment = $true }
    if ($inComment) { if ($line -match '-->') { $inComment = $false }; continue }
    if ($line -notmatch '^\|') { continue }
    if ($line -match '^\|\s*Arc\s*\|' -or $line -match '^\|\s*-+') { continue }
    $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 2) { continue }
    # คอลัมน์ 0 = Arc, 1 = Chapters (START-END)
    if (($cells[0] -replace '\D', '') -eq "$arcNum" -and $cells[1] -match '(\d+)\s*[-–]\s*(\d+)') {
        $arcStart = [int]$Matches[1]; $arcEnd = [int]$Matches[2]
        break
    }
}

if ($null -eq $arcStart) {
    Write-Host "[ERROR] ไม่พบ arc $arcNum ใน batch-plan.md หรือคอลัมน์ Chapters ไม่ใช่รูป START-END" -ForegroundColor Red
    Write-Host "        ตั้งขอบเขต arc ใน reports/batch-plan.md ก่อน (เช่น | $arcNum | 1-30 | ... |)" -ForegroundColor Yellow
    exit 2
}

# ── 2. อ่านสถานะรายตอนในช่วง arc ──
$statusLines = Get-Content -LiteralPath $statusFile -Encoding UTF8
$statusOf = @{}   # chapter number -> status string
$inComment = $false
foreach ($line in $statusLines) {
    if ($line -match '<!--') { $inComment = $true }
    if ($inComment) { if ($line -match '-->') { $inComment = $false }; continue }
    if ($line -notmatch '^\|') { continue }
    $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
    # | Chapter | Arc | Status | ... ต้องมีอย่างน้อย 3 คอลัมน์ และคอลัมน์แรกเป็นตัวเลขล้วน
    if ($cells.Count -lt 3) { continue }
    if ($cells[0] -notmatch '^\d+$') { continue }
    $statusOf[[int]$cells[0]] = $cells[2]
}

# ── 3. กำหนดเงื่อนไข "ผ่าน" ตาม Phase ──
# สถานะที่ถือว่า "ผ่านขั้นต่ำ" สำหรับการเข้าแต่ละ Phase
$okStatuses = switch ($Phase) {
    'B'    { @('QA: Pass', 'QA: Pass-minor', 'Edited', 'Final') }  # draft+QA ครบ
    'C'    { @('Edited', 'Final') }                                 # เกลาครบ
    'ship' { @('Final') }                                           # final ครบ
}

$blocked = @()
for ($ch = $arcStart; $ch -le $arcEnd; $ch++) {
    $st = $statusOf[$ch]
    if ([string]::IsNullOrEmpty($st)) {
        $blocked += [PSCustomObject]@{ Ch = $ch; Status = '(ไม่มีในตาราง)' }
    } elseif ($okStatuses -notcontains $st) {
        $blocked += [PSCustomObject]@{ Ch = $ch; Status = $st }
    }
}

# ── 4. ตรวจ OKF freeze (เฉพาะ gate เข้า Phase B) ──
$freezeMissing = $false
if ($Phase -eq 'B') {
    $hasFreeze = $false
    if (Test-Path -LiteralPath $freezeFile) {
        $freezeLines = Get-Content -LiteralPath $freezeFile -Encoding UTF8
        $inComment = $false
        foreach ($line in $freezeLines) {
            # ข้ามบรรทัดใน HTML comment block (<!-- ... -->) — กันแถวตัวอย่างถูกนับเป็นข้อมูลจริง
            if ($line -match '<!--') { $inComment = $true }
            if ($inComment) { if ($line -match '-->') { $inComment = $false }; continue }
            if ($line -notmatch '^\|') { continue }
            $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
            if ($cells.Count -lt 3) { continue }
            if ($cells[0] -notmatch '^\d+$') { continue }
            # | Arc | Chapters | วันที่ freeze | ... ต้องมีวันที่ freeze (คอลัมน์ 2) ไม่ว่าง
            if ([int]$cells[0] -eq $arcNum -and -not [string]::IsNullOrWhiteSpace($cells[2])) {
                $hasFreeze = $true; break
            }
        }
    }
    if (-not $hasFreeze) { $freezeMissing = $true }
}

# ── 5. สรุปผล ──
$phaseLabel = switch ($Phase) {
    'B'    { 'Phase B (Edit ทั้ง arc)' }
    'C'    { 'Phase C (Final ทั้ง arc)' }
    'ship' { 'ส่งมอบ arc (ship)' }
}

if ($blocked.Count -eq 0 -and -not $freezeMissing) {
    Write-Host "[PASS] Arc $arcNum (ตอน $arcStart-$arcEnd) พร้อมเข้า $phaseLabel" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] Arc $arcNum (ตอน $arcStart-$arcEnd) ยังไม่พร้อมเข้า $phaseLabel" -ForegroundColor Red

if ($blocked.Count -gt 0) {
    Write-Host "       ตอนที่ยังค้าง $($blocked.Count) ตอน:" -ForegroundColor Yellow
    foreach ($b in $blocked) {
        Write-Host ("         ch{0:D3} — {1}" -f $b.Ch, $b.Status) -ForegroundColor Yellow
    }
}
if ($freezeMissing) {
    Write-Host "       ยังไม่มี OKF freeze ของ arc $arcNum (ต้อง freeze ก่อนเข้า Phase B — ดู okf/arc-freeze-log.md)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[STOP] ห้ามเข้า $phaseLabel จนกว่าจะเคลียร์ที่ค้างข้างบน" -ForegroundColor Yellow
exit 1
