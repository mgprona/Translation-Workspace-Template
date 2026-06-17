<#
.SYNOPSIS
    ทำให้ทุกไฟล์ .ps1 ใน etc/ เป็น UTF-8 with BOM — รันหลัง copy/clone โปรเจกต์

.DESCRIPTION
    จากการรันจริง: บางครั้งหลัง copy/clone โปรเจกต์ ไฟล์ .ps1 ที่เคยมี BOM กลับหาย BOM
    (เช่น git autocrlf normalize, เครื่องมือบางตัว strip BOM) ทำให้ PowerShell 5.1 อ่าน
    คอมเมนต์/ข้อความภาษาไทยในสคริปต์ผิด → parser พัง → gate ทุกตัวใช้ไม่ได้

    สคริปต์นี้เป็น safety net: สแกน etc/*.ps1 ตัวไหนไม่มี BOM ให้เติมให้ (อ่าน UTF-8 เขียนกลับ
    เป็น UTF-8 with BOM) เนื้อหาไม่เปลี่ยน เปลี่ยนแค่ byte นำหน้า

    รันสคริปต์นี้เป็นขั้นแรกหลัง copy template (ดู SETUP.md ขั้น 1)

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/ensure-bom.ps1
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

$etcDir = Join-Path $RepoRoot 'etc'
if (-not (Test-Path -LiteralPath $etcDir)) {
    Write-Host "[ERROR] ไม่พบโฟลเดอร์ etc/" -ForegroundColor Red
    exit 2
}

$utf8bom = New-Object System.Text.UTF8Encoding($true)
$fixed = 0
$total = 0

Get-ChildItem -LiteralPath $etcDir -Filter '*.ps1' -File | ForEach-Object {
    $total++
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if (-not $hasBom) {
        # อ่านเป็น UTF-8 (no-BOM) แล้วเขียนกลับเป็น UTF-8 with BOM
        $content = [System.IO.File]::ReadAllText($_.FullName, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($_.FullName, $content, $utf8bom)
        Write-Host "  [FIXED] เติม BOM: $($_.Name)" -ForegroundColor Yellow
        $fixed++
    }
}

if ($fixed -eq 0) {
    Write-Host "[PASS] ทุกไฟล์ .ps1 มี BOM ครบ ($total ไฟล์)" -ForegroundColor Green
} else {
    Write-Host "[OK] เติม BOM ให้ $fixed จาก $total ไฟล์ — สคริปต์พร้อมรันบน PowerShell 5.1" -ForegroundColor Green
}
exit 0
