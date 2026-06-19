<#
.SYNOPSIS
    Gate ตรวจว่าไฟล์ stage เป็นบทแปลไทยจริง ไม่ใช่ source อังกฤษ/ไฟล์ลวก

.DESCRIPTION
    จาก real-run พบช่องโหว่สำคัญ: ถ้าโมเดลคัดลอก source อังกฤษทั้งตอนลง thai_draft/
    term-extract จะรายงาน English เป็น warning แต่ยังให้ตั้งสถานะ Draft ได้

    สคริปต์นี้เป็น hard gate สำหรับไฟล์ thai_draft/thai_edited/thai_final:
    - ต้องมีตัวอักษรไทยขั้นต่ำ
    - สัดส่วนภาษาไทยต้องเป็นเนื้อหลักของไฟล์
    - จำนวนคำอังกฤษต้องต่ำมาก เพราะบทแปลไทยไม่ควรเหลือ source อังกฤษ

.PARAMETER TargetPath
    ไฟล์ .md ที่ต้องตรวจ

.PARAMETER MinBytes
    ขนาดขั้นต่ำของไฟล์ที่ถือว่าไม่ใช่ stub

.PARAMETER MinThaiChars
    จำนวนตัวอักษรไทยขั้นต่ำ

.PARAMETER MinThaiShare
    สัดส่วนไทยขั้นต่ำเมื่อเทียบกับ Thai + English letters

.PARAMETER MaxEnglishWords
    จำนวนคำอังกฤษสูงสุดที่ยอมให้หลงเหลือ

.PARAMETER SourcePath
    ไฟล์ source อังกฤษของตอนเดียวกัน ถ้าระบุจะตรวจความครบเชิงปริมาณด้วย

.PARAMETER MinThaiPerSourceWord
    จำนวนตัวอักษรไทยขั้นต่ำต่อ 1 คำอังกฤษใน source

.PARAMETER MinParagraphShare
    สัดส่วนย่อหน้า output/source ขั้นต่ำ เพื่อจับไฟล์ที่แปลขาด/ย่อรุนแรง

.EXAMPLE
    powershell -File etc/verify-thai-text.ps1 -TargetPath thai_draft/ch001.md
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [int]$MinBytes = 500,
    [int]$MinThaiChars = 200,
    [double]$MinThaiShare = 0.70,
    [int]$MaxEnglishWords = 5,

    [string]$SourcePath,
    [double]$MinThaiPerSourceWord = 1.50,
    [double]$MinParagraphShare = 0.50
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    Write-Host "[FAIL] ไม่พบไฟล์ที่ต้องตรวจ: $TargetPath" -ForegroundColor Red
    exit 1
}

$item = Get-Item -LiteralPath $TargetPath
if ($item.Length -lt $MinBytes) {
    Write-Host "[FAIL] $TargetPath เล็กเกินไป ($($item.Length) bytes < $MinBytes) — น่าจะเป็น stub" -ForegroundColor Red
    exit 1
}

$text = Get-Content -LiteralPath $TargetPath -Raw -Encoding UTF8

# Remove fenced code blocks if any; translation prose should not need them, but this avoids noisy counts.
$scan = [regex]::Replace($text, '(?ms)^```.*?^```', '')

$thaiChars = ([regex]::Matches($scan, '[\u0E00-\u0E7F]')).Count
$englishLetters = ([regex]::Matches($scan, '[A-Za-z]')).Count
$englishWords = ([regex]::Matches($scan, '\b[A-Za-z]{2,}\b')).Count

$denominator = $thaiChars + $englishLetters
$thaiShare = 0.0
if ($denominator -gt 0) {
    $thaiShare = [double]$thaiChars / [double]$denominator
}

$failures = [System.Collections.Generic.List[string]]::new()
if ($thaiChars -lt $MinThaiChars) {
    $failures.Add("มีตัวอักษรไทยน้อยเกินไป ($thaiChars < $MinThaiChars)") | Out-Null
}
if ($thaiShare -lt $MinThaiShare) {
    $failures.Add(("สัดส่วนภาษาไทยต่ำเกินไป ({0:P1} < {1:P0})" -f $thaiShare, $MinThaiShare)) | Out-Null
}
if ($englishWords -gt $MaxEnglishWords) {
    $failures.Add("พบคำอังกฤษมากเกินไป ($englishWords > $MaxEnglishWords) — อาจคัดลอก source อังกฤษหรือแปลไม่ครบ") | Out-Null
}

if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        $failures.Add("ไม่พบ source สำหรับเทียบความครบ: $SourcePath") | Out-Null
    } else {
        $sourceText = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
        $sourceWords = ([regex]::Matches($sourceText, '\b[A-Za-z]+\b')).Count
        $sourceParas = @(($sourceText -split "\r?\n\s*\r?\n") | Where-Object { $_.Trim().Length -gt 0 }).Count
        $targetParas = @(($scan -split "\r?\n\s*\r?\n") | Where-Object { $_.Trim().Length -gt 0 }).Count

        if ($sourceWords -gt 0) {
            $thaiPerSourceWord = [double]$thaiChars / [double]$sourceWords
            if ($thaiPerSourceWord -lt $MinThaiPerSourceWord) {
                $failures.Add(("เนื้อหาไทยสั้นเกินไปเมื่อเทียบ source (ThaiChars/SourceWords={0:N2} < {1:N2})" -f $thaiPerSourceWord, $MinThaiPerSourceWord)) | Out-Null
            }
        }
        if ($sourceParas -gt 10) {
            $paragraphShare = [double]$targetParas / [double]$sourceParas
            if ($paragraphShare -lt $MinParagraphShare) {
                $failures.Add(("จำนวนย่อหน้า output ต่ำผิดปกติเมื่อเทียบ source ({0}/{1} = {2:P1} < {3:P0})" -f $targetParas, $sourceParas, $paragraphShare, $MinParagraphShare)) | Out-Null
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "[FAIL] Thai text sanity ไม่ผ่าน: $TargetPath" -ForegroundColor Red
    Write-Host "       ThaiChars=$thaiChars EnglishWords=$englishWords ThaiShare=$('{0:P1}' -f $thaiShare)" -ForegroundColor Yellow
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "[PASS] Thai text sanity ผ่าน: $TargetPath (ThaiChars=$thaiChars, EnglishWords=$englishWords, ThaiShare=$('{0:P1}' -f $thaiShare))" -ForegroundColor Green
exit 0
