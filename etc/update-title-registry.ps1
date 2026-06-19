<#
.SYNOPSIS
    เติม/อัปเดต okf/title-registry.md จาก heading บรรทัดแรกของไฟล์บทแปล

.DESCRIPTION
    ลดงานมือที่ลืมง่าย: หลัง draft/edited/final มีชื่อบทไทยอยู่บรรทัดแรก สคริปต์นี้จะดึง heading
    แล้วเพิ่มหรือแก้แถวของตอนนั้นใน okf/title-registry.md โดยไม่เดา English/Korean title

.PARAMETER Chapter
    เลขตอนเดียว เช่น 1 หรือ 001

.PARAMETER Start
    ตอนเริ่มสำหรับรันแบบช่วง

.PARAMETER End
    ตอนจบสำหรับรันแบบช่วง

.PARAMETER Stage
    แหล่งไฟล์บทแปล: draft | edited | final ค่าเริ่มต้น draft

.PARAMETER Status
    สถานะชื่อบทใน registry: proposed | locked | review-needed ค่าเริ่มต้น proposed

.PARAMETER RepoRoot
    รากโปรเจกต์ ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/

.EXAMPLE
    powershell -File etc/update-title-registry.ps1 -Chapter 1 -Stage draft
.EXAMPLE
    powershell -File etc/update-title-registry.ps1 -Start 1 -End 33 -Stage final -Status locked
#>

param(
    [string]$Chapter,

    [int]$Start,

    [int]$End,

    [ValidateSet('draft', 'edited', 'final')]
    [string]$Stage = 'draft',

    [ValidateSet('proposed', 'locked', 'review-needed')]
    [string]$Status = 'proposed',

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

if (-not [string]::IsNullOrEmpty($Chapter)) {
    $num = ($Chapter -replace '\D', '')
    if ([string]::IsNullOrEmpty($num)) {
        Write-Host "[ERROR] Chapter ไม่ถูกต้อง: '$Chapter'" -ForegroundColor Red
        exit 2
    }
    $Start = [int]$num
    $End = [int]$num
} elseif (-not $PSBoundParameters.ContainsKey('Start') -or -not $PSBoundParameters.ContainsKey('End')) {
    Write-Host "[ERROR] ต้องระบุ -Chapter หรือ -Start และ -End" -ForegroundColor Red
    exit 2
}

if ($End -lt $Start) {
    Write-Host "[ERROR] -End ต้องมากกว่าหรือเท่ากับ -Start" -ForegroundColor Red
    exit 2
}

$stageDir = @{
    draft  = 'thai_draft'
    edited = 'thai_edited'
    final  = 'thai_final'
}[$Stage]

$registryPath = Join-Path $RepoRoot 'okf/title-registry.md'
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    Write-Host "[ERROR] ไม่พบ okf/title-registry.md" -ForegroundColor Red
    exit 2
}

function Get-ThaiTitle {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trim)) { continue }
        if ($trim -match '^#{1,3}\s+(.+)$') {
            $title = $Matches[1].Trim()
        } else {
            $title = $trim
        }
        # strip เฉพาะ BBCode/HTML tag จริง (ชื่อ tag ขึ้นต้นด้วย ASCII letter)
        # กันการลบวงเล็บแหลม/ก้ามปูที่ครอบคำไทยในชื่อบทโดยไม่ตั้งใจ เช่น <ตอนพิเศษ> [ภาคผนวก]
        $title = $title -replace '\[/?[A-Za-z][\w="]*\]', ''
        $title = $title -replace '</?[A-Za-z][\w-]*>', ''
        $title = $title.Trim()
        if ($title.Length -gt 0) { return $title }
    }
    return $null
}

$allLines = @(Get-Content -LiteralPath $registryPath -Encoding UTF8)
$updated = 0

for ($ch = $Start; $ch -le $End; $ch++) {
    $nnn = '{0:D3}' -f $ch
    $chapterPath = Join-Path $RepoRoot "$stageDir/ch$nnn.md"
    if (-not (Test-Path -LiteralPath $chapterPath -PathType Leaf)) {
        Write-Host "[WARN] ข้าม ch$nnn — ไม่มี $stageDir/ch$nnn.md" -ForegroundColor Yellow
        continue
    }

    $thaiTitle = Get-ThaiTitle $chapterPath
    if ([string]::IsNullOrWhiteSpace($thaiTitle)) {
        Write-Host "[WARN] ข้าม ch$nnn — หา heading/title ไม่ได้" -ForegroundColor Yellow
        continue
    }

    $rowRegex = '^\|\s*' + $ch + '\s*\|'
    $realRowIndex = -1
    $inComment = $false
    for ($i = 0; $i -lt $allLines.Count; $i++) {
        $ln = $allLines[$i]
        if ($ln -match '<!--') { $inComment = $true }
        if ($inComment) {
            if ($ln -match '-->') { $inComment = $false }
            continue
        }
        if ($ln -match $rowRegex) {
            $realRowIndex = $i
            break
        }
    }

    if ($realRowIndex -ge 0) {
        $cells = $allLines[$realRowIndex].Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        while ($cells.Count -lt 6) { $cells += '' }
        $cells[3] = $thaiTitle
        $cells[4] = $Status
        $cells[5] = "auto-extracted from $stageDir/ch$nnn.md"
        $allLines[$realRowIndex] = '| ' + ($cells -join ' | ') + ' |'
    } else {
        $newRow = "| $ch |  |  | $thaiTitle | $Status | auto-extracted from $stageDir/ch$nnn.md |"
        $inserted = $false
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($line in $allLines) {
            if (-not $inserted -and $line -match '^##\s') {
                $out.Add($newRow)
                $out.Add('')
                $inserted = $true
            }
            $out.Add($line)
        }
        if (-not $inserted) { $out.Add($newRow) }
        $allLines = @($out)
    }
    Write-Host "[OK] title-registry ch$nnn = $thaiTitle" -ForegroundColor Green
    $updated++
}

if ($updated -gt 0) {
    # UTF-8 with BOM (กันไทยเพี้ยนถ้าเปิดด้วย PS 5.1 — Set-Content -Encoding UTF8 ไม่เขียน BOM บน PS7)
    [System.IO.File]::WriteAllText($registryPath, ((@($allLines) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
}

Write-Host "[PASS] update-title-registry อัปเดต $updated ตอน" -ForegroundColor Green
exit 0
