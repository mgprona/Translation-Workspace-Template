<#
.SYNOPSIS
    ตรวจว่า source files พร้อมและชื่อโฟลเดอร์ตรงมาตรฐานตอน setup — กัน AI หา source ไม่เจอทั้งโปรเจกต์

.DESCRIPTION
    แก้ปัญหาจากงานจริง: บางโปรเจกต์ใช้ชื่อโฟลเดอร์ source ไม่ตรงมาตรฐาน
    (เช่น cleaned_novtales/ แทน eng_clean_chapter/) ทำให้ path ใน prompt ไม่ตรงของจริง
    ถ้า AI ไม่รู้ตัวจะหา source ไม่เจอเงียบๆ แล้วเดา/หลอนแทน

    สคริปต์นี้ตรวจ:
    - มีโฟลเดอร์ sources/eng_clean_chapter/ จริง
    - มีไฟล์ ch001.txt อย่างน้อย (source หลักตอนแรก)
    - นับจำนวนไฟล์ในแต่ละ source folder
    - เตือนถ้าพบโฟลเดอร์ชื่อ non-standard ที่อาจเป็น source แต่ตั้งชื่อผิด

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\verify-sources.ps1
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

$sourcesDir = Join-Path $RepoRoot 'sources'
$engDir = Join-Path $sourcesDir 'eng_clean_chapter'
$rawDir = Join-Path $sourcesDir 'raw_chapter'

$problems = 0

# helper: เตือนเรื่องโฟลเดอร์ non-standard ที่อาจเป็น source ตั้งชื่อผิด
function Show-NonStandardHint {
    if (Test-Path -LiteralPath $sourcesDir) {
        $suspects = Get-ChildItem -LiteralPath $sourcesDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('eng_clean_chapter', 'raw_chapter') }
        # นับเฉพาะโฟลเดอร์ที่มีไฟล์ .txt จริง (กันเตือนโฟลเดอร์ว่าง)
        $withTxt = @()
        foreach ($s in $suspects) {
            $cnt = (Get-ChildItem -LiteralPath $s.FullName -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count
            if ($cnt -gt 0) { $withTxt += [PSCustomObject]@{ Name = $s.Name; Count = $cnt } }
        }
        if ($withTxt.Count -gt 0) {
            Write-Host "       พบโฟลเดอร์อื่นใน sources/ ที่อาจเป็น source แต่ชื่อไม่ตรงมาตรฐาน:" -ForegroundColor Yellow
            foreach ($s in $withTxt) {
                Write-Host "         - sources/$($s.Name)/ ($($s.Count) ไฟล์ .txt)" -ForegroundColor Yellow
            }
            Write-Host "       => เลือก rename ให้ตรงมาตรฐาน หรือแก้ path ใน okf/source-map.md + okf/index.md + prompts (ดู SETUP.md)" -ForegroundColor Yellow
        }
    }
}

# 1. ตรวจโฟลเดอร์มาตรฐาน
if (-not (Test-Path -LiteralPath $engDir -PathType Container)) {
    Write-Host "[FAIL] ไม่พบโฟลเดอร์ source หลัก: sources/eng_clean_chapter/" -ForegroundColor Red
    $problems++
    Show-NonStandardHint
} else {
    $engFiles = Get-ChildItem -LiteralPath $engDir -Filter '*.txt' -File -ErrorAction SilentlyContinue
    $engCount = $engFiles.Count
    if ($engCount -eq 0) {
        Write-Host "[FAIL] sources/eng_clean_chapter/ ว่างเปล่า — ยังไม่มีไฟล์ต้นฉบับ" -ForegroundColor Red
        $problems++
        Show-NonStandardHint
    } else {
        Write-Host "[PASS] sources/eng_clean_chapter/ มี $engCount ไฟล์" -ForegroundColor Green
        # ตรวจ ch001.txt
        if (-not (Test-Path -LiteralPath (Join-Path $engDir 'ch001.txt'))) {
            Write-Host "[WARN] ไม่พบ ch001.txt — ตรวจรูปแบบชื่อไฟล์ว่าเป็น chNNN.txt หรือไม่" -ForegroundColor Yellow
            $sample = $engFiles | Select-Object -First 3 | ForEach-Object { $_.Name }
            Write-Host "       ตัวอย่างไฟล์ที่พบ: $($sample -join ', ')" -ForegroundColor Yellow
        }
    }
}

# 2. ตรวจ raw_chapter (optional)
if (Test-Path -LiteralPath $rawDir -PathType Container) {
    $rawCount = (Get-ChildItem -LiteralPath $rawDir -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count
    Write-Host "[INFO] sources/raw_chapter/ มี $rawCount ไฟล์ (ต้นฉบับดิบ — optional)" -ForegroundColor Cyan
} else {
    Write-Host "[INFO] ไม่มี sources/raw_chapter/ (ไม่บังคับ — ใช้ตรวจชื่อเฉพาะเมื่อมี)" -ForegroundColor Cyan
}

Write-Host ""
if ($problems -gt 0) {
    Write-Host "[RESULT] พบปัญหา source $problems จุด — แก้ก่อนเริ่มแปล ไม่งั้น AI จะหา source ไม่เจอ" -ForegroundColor Red
    exit 1
}
Write-Host "[RESULT] source พร้อมใช้งาน" -ForegroundColor Green
exit 0
