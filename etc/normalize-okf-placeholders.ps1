<#
.SYNOPSIS
    Normalize common OKF template placeholders before freeze gates.

.DESCRIPTION
    OKF files created from the template often still contain placeholders such as
    {DATE} or {NOVEL_NAME}. verify-okf.ps1 now blocks these before Phase B/ship.

    This helper performs only safe mechanical replacements:
    - {DATE} -> invariant current date
    - {NOVEL_NAME} -> supplied novel name

    It intentionally does not invent missing table content. Files that are still
    semantically empty must be fixed by the normal OKF update flow and verify-okf.
#>

param(
    [string]$RepoRoot,
    [string]$NovelName = 'Absolute Regression'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = Split-Path -Parent $scriptDir
}

$okfDir = Join-Path $RepoRoot 'okf'
if (-not (Test-Path -LiteralPath $okfDir -PathType Container)) {
    Write-Host "[ERROR] ไม่พบ okf/: $okfDir" -ForegroundColor Red
    exit 2
}

$today = (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
$updated = 0

foreach ($file in (Get-ChildItem -LiteralPath $okfDir -Filter '*.md' -File)) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $newText = $text.Replace('{DATE}', $today).Replace('{NOVEL_NAME}', $NovelName)
    if ($newText -ne $text) {
        # UTF-8 with BOM (กันไทยเพี้ยนถ้าเปิดด้วย PS 5.1) — เขียน raw string คงรูป line-ending เดิม เติมแค่ BOM
        [System.IO.File]::WriteAllText($file.FullName, $newText, (New-Object System.Text.UTF8Encoding($true)))
        Write-Host "[OK] normalized $($file.Name)" -ForegroundColor Green
        $updated++
    }
}

Write-Host "[PASS] normalized OKF placeholders in $updated file(s)" -ForegroundColor Green
exit 0
