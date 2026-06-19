<#
.SYNOPSIS
    ด่านบังคับ (gate) — ตรวจว่า output ของ stage ก่อนหน้ามีจริงและสมเหตุสมผล ก่อนอนุญาตให้ทำขั้นถัดไป

.DESCRIPTION
    แก้ปัญหา "phantom chapter" จากงานจริง: โมเดลสร้าง QA report / notes / สถานะ Final ให้ตอนที่
    ไม่เคยแปลจริง (ไฟล์ thai_draft/chNNN.md ไม่มีอยู่) เพราะ workflow เดินเป็นจังหวะแล้วโมเดลทำ "ต่อ"
    แม้ขั้นก่อนหน้าจะล้มเหลว

    สคริปต์นี้คือด่านที่ prompt ขั้นถัดไปต้องรันก่อนเสมอ ถ้าไม่ผ่าน (exit 1) prompt ห้ามสร้างไฟล์ใดๆ

    Stage ที่ตรวจ:
    - draft     : ต้องมี thai_draft/chNNN.md (ก่อน QA)
    - notes     : ต้องมี reports/chNNN-translation-notes.md (ก่อนตั้ง Draft/ก่อน QA)
    - qa        : ต้องมี qa/reports/chNNN-qa.md (ก่อน Polish)
    - edited    : ต้องมี thai_edited/chNNN.md (ก่อน Finalize)
    - final     : ต้องมี thai_final/chNNN.md (ยืนยันหลัง Finalize)

.PARAMETER Chapter
    เลขตอน เช่น 22 หรือ 022 (normalize เป็น 3 หลักให้เอง)

.PARAMETER Stage
    stage ที่ต้องการให้ "มีอยู่แล้ว": draft | qa | edited | final

.PARAMETER MinBytes
    ขนาดไฟล์ขั้นต่ำที่ถือว่าเป็นเนื้อหาจริง (กันไฟล์ว่าง/สตับ) ค่าเริ่มต้น 200 ไบต์

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    # ก่อน QA ตอน 22 — ตรวจว่า draft มีจริง
    .\verify-chapter.ps1 -Chapter 22 -Stage draft
    # exit 0 = ผ่าน ทำ QA ต่อได้; exit 1 = ไม่มี draft ห้ามเขียน QA report

.EXAMPLE
    # ก่อน Finalize ตอน 5 — ตรวจว่า edited มีจริง
    .\verify-chapter.ps1 -Chapter 5 -Stage edited
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Chapter,

    [Parameter(Mandatory = $true)]
    [ValidateSet('draft', 'notes', 'qa', 'edited', 'final')]
    [string]$Stage,

    [int]$MinBytes = 200,

    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

# resolve RepoRoot แบบ robust — $PSScriptRoot ว่างได้บน PS 5.1 บางบริบท
if ([string]::IsNullOrEmpty($RepoRoot)) {
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $RepoRoot = Split-Path -Parent $scriptDir
}

# normalize chapter เป็น 3 หลัก (22 -> 022, 022 -> 022)
$num = ($Chapter -replace '\D', '')
if ([string]::IsNullOrEmpty($num)) {
    Write-Host "[ERROR] Chapter ไม่ถูกต้อง: '$Chapter'" -ForegroundColor Red
    exit 2
}
$nnn = '{0:D3}' -f [int]$num

# map stage -> path ของ output ที่ต้องมีจริง
$map = @{
    draft  = "thai_draft/ch$nnn.md"
    notes  = "reports/ch$nnn-translation-notes.md"
    qa     = "qa/reports/ch$nnn-qa.md"
    edited = "thai_edited/ch$nnn.md"
    final  = "thai_final/ch$nnn.md"
}

$rel = $map[$Stage]
$full = Join-Path $RepoRoot $rel

if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    Write-Host "[FAIL] ตอน $nnn : ไม่พบไฟล์ stage '$Stage' ที่ควรมีอยู่" -ForegroundColor Red
    Write-Host "       คาดว่าต้องมี: $rel" -ForegroundColor Red
    Write-Host "[STOP] ห้ามทำขั้นถัดไปหรือสร้างไฟล์ใดๆ — ตอนนี้ยังไม่ผ่าน stage '$Stage' จริง" -ForegroundColor Yellow
    exit 1
}

$size = (Get-Item -LiteralPath $full).Length
if ($size -lt $MinBytes) {
    Write-Host "[FAIL] ตอน $nnn : ไฟล์ '$rel' มีขนาด $size ไบต์ (< $MinBytes) — น่าจะว่างหรือเป็นสตับ" -ForegroundColor Red
    Write-Host "[STOP] ห้ามทำขั้นถัดไป — stage '$Stage' ยังไม่มีเนื้อหาจริง" -ForegroundColor Yellow
    exit 1
}

Write-Host "[PASS] ตอน $nnn : stage '$Stage' มีจริง ($rel, $size ไบต์) — ทำขั้นถัดไปได้" -ForegroundColor Green
exit 0
