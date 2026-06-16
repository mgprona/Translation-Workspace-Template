<#
.SYNOPSIS
    ตรวจว่า setup placeholder ถูกแทนค่าครบหรือยัง หลังเปิดโปรเจกต์ใหม่จาก template

.DESCRIPTION
    สแกนหา setup placeholder ที่ต้องแทนค่าครั้งเดียวตอน setup (ดู SETUP.md step 2):
    - {NOVEL_NAME}
    - {DATE}

    ตั้งใจ **ไม่** ตรวจ runtime placeholder เช่น {CHAPTER_NUMBER}, {NNN}, {START}, {END}
    เพราะพวกนั้นเป็น template token ของ prompt ที่ต้องคงไว้ — การ flag จะเป็น false positive

    ขอบเขตสแกน: okf/, README.md, WORKFLOW.md
    ข้าม: prompts/ (template ที่อ้าง {NOVEL_NAME} เชิงสอน), SETUP.md (doc ที่อธิบาย
          placeholder จึงมีตัวอย่างโดยตั้งใจ), etc/ (ตัวสคริปต์เอง), .git/

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    .\check-placeholders.ps1
    # ตรวจหลัง setup — exit 0 ถ้าแทนครบ, exit 1 ถ้ายังมีค้าง
#>

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

# setup placeholder ที่ต้องถูกแทนค่า (ไม่รวม runtime token)
$setupPlaceholders = '\{NOVEL_NAME\}|\{DATE\}'

# ไฟล์/โฟลเดอร์ที่อยู่ในขอบเขตการตรวจ
# หมายเหตุ: ไม่รวม SETUP.md — เป็น doc ที่อธิบาย placeholder จึงมีตัวอย่างโดยตั้งใจ
$targets = @(
    Join-Path $RepoRoot 'okf'
    Join-Path $RepoRoot 'README.md'
    Join-Path $RepoRoot 'WORKFLOW.md'
)

$files = foreach ($t in $targets) {
    if (Test-Path -LiteralPath $t -PathType Container) {
        Get-ChildItem -LiteralPath $t -Filter '*.md' -File -Recurse
    } elseif (Test-Path -LiteralPath $t -PathType Leaf) {
        Get-Item -LiteralPath $t
    }
}

$hits = $files | Select-String -Pattern $setupPlaceholders

if (-not $hits) {
    Write-Host "[PASS] All setup placeholders replaced. (scanned $($files.Count) file(s))" -ForegroundColor Green
    exit 0
}

Write-Host "[ISSUE] Unreplaced setup placeholder(s) found:`n" -ForegroundColor Yellow
Write-Host "| File | Line | Placeholder | Content |"
Write-Host "|---|---|---|---|"
foreach ($h in $hits) {
    $rel = $h.Path.Replace($RepoRoot, '').TrimStart('\', '/')
    $token = $h.Matches[0].Value
    $content = $h.Line.Trim() -replace '\|', '\|'
    Write-Host "| $rel | $($h.LineNumber) | $token | $content |"
}
Write-Host "`n[RESULT] $($hits.Count) unreplaced placeholder(s). See SETUP.md step 2." -ForegroundColor Yellow
exit 1
