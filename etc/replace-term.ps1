<#
.SYNOPSIS
    แก้คำข้ามหลายตอนแบบปลอดภัย (encoding-safe) — แทน fix-english-leaks.ps1 ที่ทำไฟล์พัง

.DESCRIPTION
    จากงานจริง: โมเดลสร้าง fix-english-leaks.ps1 เองเพื่อ find-replace คำ แต่ไม่ระบุ
    -Encoding utf8 ทำให้ไฟล์ภาษาไทยพังเป็น mojibake ครึ่งโปรเจกต์

    สคริปต์นี้คือเครื่องมือ find-replace ที่ "ปลอดภัย" สำหรับใช้ตอน OKF freeze แบบอ่อน
    (arc หลังเปลี่ยนคำมาตรฐาน ต้องไล่แก้ตอนที่ส่งผลกระทบ):
    - อ่าน/เขียน UTF-8 ชัดเจนเสมอ + เขียนแบบ UTF-8 with BOM (กัน PS 5.1 อ่านผิด)
    - DEFAULT เป็น DryRun: โชว์ว่าจะแก้กี่จุดในไฟล์ไหน โดยไม่เขียนจริง
    - ต้องใส่ -Apply เท่านั้นถึงเขียนไฟล์จริง
    - หลังเขียน รัน check-encoding.ps1 อัตโนมัติเพื่อยืนยันไม่พัง
    - แทนที่แบบ literal (ไม่ใช่ regex) กันความผิดพลาด

.PARAMETER Old
    คำเดิมที่จะแทน (literal string)

.PARAMETER New
    คำใหม่

.PARAMETER Arc
    เลข arc — แก้ทุกไฟล์ thai_draft/thai_edited/thai_final ในช่วงตอนของ arc นั้น
    (อ่านช่วงจาก reports/batch-plan.md) ใช้แทน -Path ก็ได้อย่างใดอย่างหนึ่ง

.PARAMETER Path
    โฟลเดอร์หรือไฟล์เป้าหมายโดยตรง (ถ้าไม่ใช้ -Arc)

.PARAMETER Apply
    เขียนไฟล์จริง (ไม่ใส่ = DryRun โชว์อย่างเดียว)

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\replace-term.ps1 -Old "พลังดาบ" -New "รังสีดาบ" -Arc 1
    # DryRun: โชว์ว่าจะแก้กี่จุดในตอน 1-30
.EXAMPLE
    .\replace-term.ps1 -Old "พลังดาบ" -New "รังสีดาบ" -Arc 1 -Apply
    # เขียนจริง + ตรวจ encoding หลังแก้
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Old,

    [Parameter(Mandatory = $true)]
    [string]$New,

    [string]$Arc,

    [string]$Path,

    [switch]$Apply,

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

if ([string]::IsNullOrEmpty($Old)) {
    Write-Host "[ERROR] -Old ห้ามว่าง" -ForegroundColor Red
    exit 2
}

# ── 1. รวบรวมไฟล์เป้าหมาย ──
$targetFiles = @()

if (-not [string]::IsNullOrEmpty($Arc)) {
    $arcNum = [int]($Arc -replace '\D', '')
    $planFile = Join-Path $RepoRoot 'reports/batch-plan.md'
    if (-not (Test-Path -LiteralPath $planFile)) {
        Write-Host "[ERROR] ไม่พบ reports/batch-plan.md" -ForegroundColor Red
        exit 2
    }
    $arcStart = $null; $arcEnd = $null
    $inComment = $false
    foreach ($line in (Get-Content -LiteralPath $planFile -Encoding UTF8)) {
        if ($line -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -notmatch '^\|') { continue }
        $cells = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt 2) { continue }
        if (($cells[0] -replace '\D', '') -eq "$arcNum" -and $cells[1] -match '(\d+)\s*[-–]\s*(\d+)') {
            $arcStart = [int]$Matches[1]; $arcEnd = [int]$Matches[2]; break
        }
    }
    if ($null -eq $arcStart) {
        Write-Host "[ERROR] ไม่พบ arc $arcNum ใน batch-plan.md" -ForegroundColor Red
        exit 2
    }
    foreach ($dir in @('thai_draft', 'thai_edited', 'thai_final')) {
        for ($ch = $arcStart; $ch -le $arcEnd; $ch++) {
            $nnn = '{0:D3}' -f $ch
            $fp = Join-Path $RepoRoot "$dir/ch$nnn.md"
            if (Test-Path -LiteralPath $fp -PathType Leaf) { $targetFiles += $fp }
        }
    }
    Write-Host "[INFO] Arc $arcNum (ตอน $arcStart-$arcEnd): พบไฟล์เป้าหมาย $($targetFiles.Count) ไฟล์" -ForegroundColor Cyan
}
elseif (-not [string]::IsNullOrEmpty($Path)) {
    if (Test-Path -LiteralPath $Path -PathType Container) {
        $targetFiles = (Get-ChildItem -LiteralPath $Path -Filter '*.md' -File).FullName
    } elseif (Test-Path -LiteralPath $Path -PathType Leaf) {
        $targetFiles = @($Path)
    } else {
        Write-Host "[ERROR] ไม่พบ Path: $Path" -ForegroundColor Red
        exit 2
    }
}
else {
    Write-Host "[ERROR] ต้องระบุ -Arc หรือ -Path อย่างใดอย่างหนึ่ง" -ForegroundColor Red
    exit 2
}

if ($targetFiles.Count -eq 0) {
    Write-Host "[INFO] ไม่มีไฟล์เป้าหมาย" -ForegroundColor Yellow
    exit 0
}

# ── 2. สแกน/แก้ (literal replace, UTF-8 ชัดเจน) ──
$utf8bom = New-Object System.Text.UTF8Encoding($true)
$totalHits = 0
$changedFiles = @()

foreach ($file in $targetFiles) {
    $content = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    if ($null -eq $content) { continue }

    # นับจำนวนครั้งแบบ literal
    $count = ([regex]::Matches($content, [regex]::Escape($Old))).Count
    if ($count -eq 0) { continue }

    $totalHits += $count
    $name = Split-Path -Leaf $file
    Write-Host ("  {0} — {1} จุด" -f $name, $count) -ForegroundColor Gray

    if ($Apply) {
        $newContent = $content.Replace($Old, $New)
        [System.IO.File]::WriteAllText($file, $newContent, $utf8bom)
        $changedFiles += $file
    }
}

Write-Host ""
if ($totalHits -eq 0) {
    Write-Host "[RESULT] ไม่พบคำ '$Old' ในไฟล์เป้าหมาย" -ForegroundColor Green
    exit 0
}

if (-not $Apply) {
    Write-Host "[DRY-RUN] จะแทน '$Old' -> '$New' รวม $totalHits จุด ใน $($targetFiles.Count) ไฟล์" -ForegroundColor Cyan
    Write-Host "          ใส่ -Apply เพื่อเขียนจริง" -ForegroundColor Cyan
    exit 0
}

Write-Host "[APPLIED] แทน '$Old' -> '$New' รวม $totalHits จุด ใน $($changedFiles.Count) ไฟล์ (UTF-8 BOM)" -ForegroundColor Green

# ── 3. ตรวจ encoding หลังแก้ (กัน mojibake) ──
$encScript = Join-Path $PSScriptRoot 'check-encoding.ps1'
if (Test-Path -LiteralPath $encScript) {
    Write-Host "[CHECK] ตรวจ encoding หลังแก้..." -ForegroundColor Cyan
    $bad = 0
    foreach ($file in $changedFiles) {
        & $encScript -TargetPath $file | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [!] mojibake ใน $(Split-Path -Leaf $file)" -ForegroundColor Red
            $bad++
        }
    }
    if ($bad -gt 0) {
        Write-Host "[WARN] พบ mojibake $bad ไฟล์หลังแก้ — ตรวจสอบด่วน" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] encoding สะอาดทุกไฟล์ที่แก้" -ForegroundColor Green
}

exit 0
