<#
.SYNOPSIS
    ตรวจว่า source files พร้อมและชื่อโฟลเดอร์ตรงมาตรฐานตอน setup — กัน AI หา source ไม่เจอทั้งโปรเจกต์

.DESCRIPTION
    แก้ปัญหาจากงานจริง: บางโปรเจกต์ใช้ชื่อโฟลเดอร์ source ไม่ตรงมาตรฐาน
    (เช่น cleaned_novtales/ แทน primary_chapter/) ทำให้ path ใน prompt ไม่ตรงของจริง
    ถ้า AI ไม่รู้ตัวจะหา source ไม่เจอเงียบๆ แล้วเดา/หลอนแทน

    template นี้เป็นกลางเรื่องภาษา — ต้นฉบับหลัก (primary) จะเป็นภาษาอะไรก็ได้
    (เกาหลี/อังกฤษ/จีน/ฯลฯ) ภาษาหลักบันทึกไว้ใน okf/source-map.md ให้ AI อ่านตอนแปล

    สคริปต์นี้ตรวจ:
    - มีโฟลเดอร์ sources/primary_chapter/ จริง และมีไฟล์อย่างน้อย ch001.txt
    - นับจำนวนไฟล์ในแต่ละ source folder
    - เตือนถ้าพบโฟลเดอร์ชื่อ non-standard ที่อาจเป็น source แต่ตั้งชื่อผิด
    - เตือนถ้า primary กับ reference เนื้อหาเหมือนกัน (สัญญาณก็อปไฟล์ผิด — อาจไม่ใช่คนละภาษาจริง)

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
$primaryDir = Join-Path $sourcesDir 'primary_chapter'
$referenceDir = Join-Path $sourcesDir 'reference_chapter'

$problems = 0

# helper: เตือนเรื่องโฟลเดอร์ non-standard ที่อาจเป็น source ตั้งชื่อผิด
function Show-NonStandardHint {
    if (Test-Path -LiteralPath $sourcesDir) {
        $suspects = Get-ChildItem -LiteralPath $sourcesDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin @('primary_chapter', 'reference_chapter') }
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
            Write-Host "       => เลือก rename ให้ตรงมาตรฐาน (primary_chapter / reference_chapter) หรือแก้ path ใน okf/source-map.md + okf/index.md + prompts (ดู SETUP.md)" -ForegroundColor Yellow
        }
    }
}

# 1. ตรวจโฟลเดอร์ต้นฉบับหลัก (primary — ภาษาอะไรก็ได้)
$primaryFiles = @()
if (-not (Test-Path -LiteralPath $primaryDir -PathType Container)) {
    Write-Host "[FAIL] ไม่พบโฟลเดอร์ต้นฉบับหลัก: sources/primary_chapter/" -ForegroundColor Red
    $problems++
    Show-NonStandardHint
} else {
    $primaryFiles = Get-ChildItem -LiteralPath $primaryDir -Filter '*.txt' -File -ErrorAction SilentlyContinue
    $primaryCount = $primaryFiles.Count
    if ($primaryCount -eq 0) {
        Write-Host "[FAIL] sources/primary_chapter/ ว่างเปล่า — ยังไม่มีไฟล์ต้นฉบับ" -ForegroundColor Red
        $problems++
        Show-NonStandardHint
    } else {
        Write-Host "[PASS] sources/primary_chapter/ มี $primaryCount ไฟล์" -ForegroundColor Green
        # ตรวจ ch001.txt
        if (-not (Test-Path -LiteralPath (Join-Path $primaryDir 'ch001.txt'))) {
            Write-Host "[WARN] ไม่พบ ch001.txt — ตรวจรูปแบบชื่อไฟล์ว่าเป็น chNNN.txt หรือไม่" -ForegroundColor Yellow
            $sample = $primaryFiles | Select-Object -First 3 | ForEach-Object { $_.Name }
            Write-Host "       ตัวอย่างไฟล์ที่พบ: $($sample -join ', ')" -ForegroundColor Yellow
        }
    }
}

# 2. ตรวจ reference_chapter (optional — ถ้า source มีภาษาเดียว reference ว่างได้)
$referenceFiles = @()
if (Test-Path -LiteralPath $referenceDir -PathType Container) {
    $referenceFiles = Get-ChildItem -LiteralPath $referenceDir -Filter '*.txt' -File -ErrorAction SilentlyContinue
    $referenceCount = $referenceFiles.Count
    if ($referenceCount -gt 0) {
        Write-Host "[INFO] sources/reference_chapter/ มี $referenceCount ไฟล์ (source อ้างอิงรอง — optional)" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO] sources/reference_chapter/ ว่าง (ไม่บังคับ — ใช้เมื่อมี source ภาษาที่สองไว้ตรวจชื่อ)" -ForegroundColor Cyan
    }
} else {
    Write-Host "[INFO] ไม่มี sources/reference_chapter/ (ไม่บังคับ — มีไว้ตรวจชื่อเฉพาะเมื่อมี source ภาษาที่สอง)" -ForegroundColor Cyan
}

# 3. corruption guard — ถ้า primary กับ reference เนื้อหาเหมือนกัน อาจก็อปไฟล์ผิด (ไม่ใช่คนละภาษาจริง)
# จากงานจริง: AI เคยก็อปต้นฉบับภาษาเดียวกันใส่ทั้งสองโฟลเดอร์เพื่อให้ผ่าน gate ทำให้ "source สองภาษา" เป็นภาพลวง
if ($primaryFiles.Count -gt 0 -and $referenceFiles.Count -gt 0) {
    $sameCount = 0
    $checked = 0
    foreach ($pf in ($primaryFiles | Select-Object -First 5)) {
        $rf = Join-Path $referenceDir $pf.Name
        if (Test-Path -LiteralPath $rf -PathType Leaf) {
            $checked++
            $hp = (Get-FileHash -LiteralPath $pf.FullName -Algorithm MD5).Hash
            $hr = (Get-FileHash -LiteralPath $rf -Algorithm MD5).Hash
            if ($hp -eq $hr) { $sameCount++ }
        }
    }
    if ($checked -gt 0 -and $sameCount -eq $checked) {
        Write-Host ""
        Write-Host "[WARN] primary_chapter กับ reference_chapter เนื้อหาเหมือนกันทุกไฟล์ที่ตรวจ ($sameCount/$checked)" -ForegroundColor Yellow
        Write-Host "       เป็นไปได้ว่าก็อปไฟล์ภาษาเดียวกันใส่ทั้งสองโฟลเดอร์ — reference ควรเป็นคนละภาษากับ primary" -ForegroundColor Yellow
        Write-Host "       ถ้ามี source ภาษาเดียวจริง ให้ลบไฟล์ใน reference_chapter/ ทิ้ง (ปล่อยว่าง) แทนการก็อปซ้ำ" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($problems -gt 0) {
    Write-Host "[RESULT] พบปัญหา source $problems จุด — แก้ก่อนเริ่มแปล ไม่งั้น AI จะหา source ไม่เจอ" -ForegroundColor Red
    exit 1
}
Write-Host "[RESULT] source พร้อมใช้งาน" -ForegroundColor Green
exit 0
