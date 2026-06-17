<#
.SYNOPSIS
    ตรวจจับ mojibake (ตัวหนังสือเพี้ยนจาก encoding ผิด) ในไฟล์บทแปล — gate ก่อน finalize

.DESCRIPTION
    แก้ปัญหาจากงานจริง: ครึ่งหนึ่งของ thai_final/ ถูกทำลายด้วย double-encoded UTF-8
    (อักษรไทยถูกอ่านเป็น ANSI/Windows-874 แล้วเขียนกลับเป็น UTF-8 อีกชั้น) เช่น
    "บทที่ 25" กลายเป็น "เธเธ—เธ—เธตเน 25"

    ต้นเหตุคือสคริปต์ find-replace ที่เขียนทับไฟล์โดยไม่ระบุ -Encoding utf8

    สคริปต์นี้สแกนหา signature ของ double-encoding:
    - ลำดับ "เธ" + อักษร, "เน€", "เธ™", ฯลฯ ที่เป็นผลลัพธ์ของไทยที่ encode ซ้ำ
    - บรรทัดที่มีความหนาแน่นของ pattern เหล่านี้สูงผิดปกติ

    ใช้เป็น hard gate: exit 1 ถ้าพบ mojibake → ห้าม finalize

.PARAMETER TargetPath
    ไฟล์ .md เดียว หรือโฟลเดอร์ (สแกนทุก .md ในนั้น)

.EXAMPLE
    .\check-encoding.ps1 -TargetPath ..\thai_final\ch025.md
.EXAMPLE
    .\check-encoding.ps1 -TargetPath ..\thai_final
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath
)

$ErrorActionPreference = 'Stop'

# Signature ของ double-encoded UTF-8 Thai:
# เมื่อ UTF-8 ไทย (E0 B8 xx / E0 B9 xx) ถูกตีความเป็น Windows-874 แล้ว re-encode เป็น UTF-8
# จะได้ลำดับที่ขึ้นต้นด้วย "เธ" (จาก E0 B8) หรือ "เน" (จาก E0 B9) ตามด้วยอักษรแปลกๆ ติดกันถี่
# pattern จับ: "เธ" หรือ "เน" ที่ตามด้วยอักขระไม่ใช่สระ/วรรณยุกต์ปกติ ซ้ำติดกันหลายชุด
$mojibakePattern = '(เธ[฀-๿]){2,}|เน€เธ|เธย|เธฒเธ|เน„เธ|เธ"เน'

$files = @()
if (Test-Path -LiteralPath $TargetPath -PathType Container) {
    $files = Get-ChildItem -LiteralPath $TargetPath -Filter '*.md' -File
} elseif (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $TargetPath)
} else {
    Write-Host "[ERROR] ไม่พบ TargetPath: $TargetPath" -ForegroundColor Red
    exit 2
}

if ($files.Count -eq 0) {
    Write-Host "[INFO] ไม่พบไฟล์ .md ใน $TargetPath" -ForegroundColor Yellow
    exit 0
}

$badFiles = @()
foreach ($file in $files) {
    # อ่านเป็น UTF-8 ชัดเจน (กันการอ่านผิด encoding ระหว่างตรวจเอง)
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ([string]::IsNullOrEmpty($content)) { continue }

    $hits = [regex]::Matches($content, $mojibakePattern)
    if ($hits.Count -gt 0) {
        $sample = ($hits | Select-Object -First 3 | ForEach-Object { $_.Value }) -join ' , '
        $badFiles += [PSCustomObject]@{
            Name   = $file.Name
            Count  = $hits.Count
            Sample = $sample
        }
    }
}

if ($badFiles.Count -eq 0) {
    Write-Host "[PASS] ไม่พบ mojibake ใน $($files.Count) ไฟล์ — encoding สะอาด" -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] พบ mojibake (encoding เพี้ยน) ใน $($badFiles.Count) ไฟล์:" -ForegroundColor Red
foreach ($b in $badFiles) {
    Write-Host ("  {0} — {1} จุด เช่น: {2}" -f $b.Name, $b.Count, $b.Sample) -ForegroundColor Yellow
}
Write-Host ""
Write-Host "[STOP] ห้าม finalize — ไฟล์ถูกทำลายจาก encoding ผิด" -ForegroundColor Yellow
Write-Host "       สาเหตุที่พบบ่อย: สคริปต์ที่เขียนทับไฟล์โดยไม่ระบุ -Encoding utf8" -ForegroundColor Yellow
Write-Host "       ต้องกู้ไฟล์จากต้นฉบับที่ encoding ถูก หรือแปลตอนนั้นใหม่" -ForegroundColor Yellow
exit 1
