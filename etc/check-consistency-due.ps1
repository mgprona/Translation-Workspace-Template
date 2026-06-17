<#
.SYNOPSIS
    ตรวจว่า consistency check ที่ batch-plan สั่งไว้ ถูกทำจริง (มีไฟล์รายงาน) — gate ก่อนเปิด batch ใหม่

.DESCRIPTION
    แก้ปัญหาจากงานจริง: ทุกโปรเจกต์ทิ้ง consistency check กลางคัน (บางอันทำแค่ 2 ตอนแล้วเลิก)
    เพราะ workflow บอกให้ทำแต่ "ไม่บังคับ" ตรวจสอบไม่ได้

    สคริปต์นี้อ่าน reports/batch-plan.md หา batch ที่ Final เสร็จแล้ว แต่ยังไม่มีไฟล์
    consistency report ที่ครอบคลุมช่วงตอนนั้น แล้วรายงานว่าค้างที่ไหน

    ตรรกะ: ทุก batch ที่ทำ Final เสร็จ ควรมีไฟล์ reports/consistency-{START}-{END}.md
    ที่ครอบคลุมช่วงตอนของมัน ถ้าไม่มี = ค้าง = ห้ามเปิด batch ถัดไป

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\check-consistency-due.ps1
    # exit 0 = ไม่มีค้าง เปิด batch ใหม่ได้; exit 1 = มี consistency ค้าง ต้องทำก่อน
#>

param(
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

$reportsDir = Join-Path $RepoRoot 'reports'
$planFile = Join-Path $reportsDir 'batch-plan.md'

if (-not (Test-Path -LiteralPath $planFile)) {
    Write-Host "[ERROR] ไม่พบ reports/batch-plan.md" -ForegroundColor Red
    exit 2
}

# รวบรวมไฟล์ consistency report ที่มีจริง -> ช่วง [start,end]
$ranges = @()
Get-ChildItem -LiteralPath $reportsDir -Filter 'consistency-*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^consistency-(\d+)-(\d+)\.md$' } |
    ForEach-Object {
        if ($_.Name -match '^consistency-(\d+)-(\d+)\.md$') {
            $ranges += [PSCustomObject]@{ Start = [int]$Matches[1]; End = [int]$Matches[2] }
        }
    }

# helper: ช่วงตอน [s,e] ถูกครอบคลุมด้วย consistency report ที่มีจริงหรือไม่
function Test-Covered($s, $e) {
    foreach ($r in $ranges) {
        if ($r.Start -le $s -and $r.End -ge $e) { return $true }
    }
    return $false
}

# อ่าน batch-plan หาแถวที่ Final เสร็จแล้ว (มีคำว่า done/✅/Final ในคอลัมน์ Final)
$planLines = Get-Content -LiteralPath $planFile -Encoding UTF8
$pending = @()

foreach ($line in $planLines) {
    # ข้ามหัวตาราง / separator / ที่ไม่ใช่แถวข้อมูล
    if ($line -notmatch '^\|') { continue }
    if ($line -match '^\|\s*Batch\s*\|' -or $line -match '^\|\s*-+') { continue }

    $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
    # | Batch | Chapters | Draft | QA | Edited | Final | Last consistency check | Next check due | Notes |
    if ($cells.Count -lt 6) { continue }

    $chapters = $cells[1]   # เช่น ch001-010 หรือ 1-10
    $finalCell = $cells[5]

    # batch นี้ทำ Final เสร็จหรือยัง (ยืดหยุ่นกับ vocab ที่ต่างกัน)
    $finalDone = $finalCell -match 'done|final|✅|เสร็จ|complete'
    if (-not $finalDone) { continue }

    # parse ช่วงตอนจาก "ch001-010" / "1-10" / "001-010"
    if ($chapters -match '(\d+)\s*[-–]\s*(\d+)') {
        $s = [int]$Matches[1]; $e = [int]$Matches[2]
        if (-not (Test-Covered $s $e)) {
            $pending += [PSCustomObject]@{ Batch = $cells[0]; Range = "$('{0:D3}' -f $s)-$('{0:D3}' -f $e)" }
        }
    }
}

if ($pending.Count -eq 0) {
    Write-Host "[PASS] ทุก batch ที่ Final เสร็จ มี consistency report ครบ — เปิด batch ถัดไปได้" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] มี batch ที่ Final เสร็จแล้วแต่ยังไม่มี consistency report:" -ForegroundColor Red
foreach ($p in $pending) {
    Write-Host "       Batch $($p.Batch) (ตอน $($p.Range)) — ต้องทำ reports/consistency-$($p.Range).md" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "[STOP] ห้ามเปิด batch ถัดไป — ทำ consistency check ที่ค้างก่อน (prompts/05-consistency-range.md)" -ForegroundColor Yellow
exit 1
