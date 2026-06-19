<#
.SYNOPSIS
    Regression harness จาก workspace จริงที่เคยพัง เพื่อยืนยันว่า gate ใหม่จับปัญหาซ้ำได้

.DESCRIPTION
    สคริปต์นี้ไม่แก้ workspace จริง:
    - รัน audit กับ run ที่มีปัญหาชัดเจน (gemini3 ch020-025) แล้วคาดว่า fail
    - รัน audit กับ run ล่าสุด draft-only (ownalpha ch310-320) แล้วคาดว่า pass
    - รัน audit กับ run เก่าแบบ status table แยก stage columns (old ch001-030) แล้วคาดว่า pass พร้อม QA warnings
    - รัน audit กับ scaffold ที่ยังไม่มี chapter evidence (gemini2.5 ch001-010) แล้วคาดว่า fail
    - สร้าง fixture ชั่วคราวจาก Claude ch001-005 ที่มีไฟล์ครบ แล้วรัน audit + phase gates ให้ครบสาย
    - สร้าง staged fixture จาก Claude ch001-005 แล้วเลื่อน Draft -> QA -> Edited -> Final ด้วย set-status จริง
    - สร้าง staged fixture จาก ownalpha ch310-314 (run ล่าสุดที่มี draft จริง) แล้วเดินไปถึง Final ด้วย gate จริง
    - สร้าง fixture สำหรับ failure cases ของ set-status และ check-arc-phase

    ใช้เป็น smoke/regression test หลังแก้ script gate.

.PARAMETER DesktopRoot
    โฟลเดอร์ Desktop ที่มี real-run folders ค่าเริ่มต้นคือ $env:USERPROFILE\Desktop

.PARAMETER RepoRoot
    ราก template repo ค่าเริ่มต้นคือโฟลเดอร์แม่ของ etc/
#>

param(
    [string]$DesktopRoot = (Join-Path $env:USERPROFILE 'Desktop'),
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

$auditScript = Join-Path $RepoRoot 'etc/audit-workspace.ps1'
$phaseScript = Join-Path $RepoRoot 'etc/check-arc-phase.ps1'
$statusScript = Join-Path $RepoRoot 'etc/set-status.ps1'

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [int]$ExpectedExitCode = 0
    )

    Write-Host "[TEST] $Name" -ForegroundColor Cyan
    & $Action
    $actual = $LASTEXITCODE
    if ($null -eq $actual) { $actual = 0 }
    if ($actual -ne $ExpectedExitCode) {
        Write-Host "[FAIL] $Name expected exit $ExpectedExitCode, got $actual" -ForegroundColor Red
        exit 1
    }
    Write-Host "[PASS] $Name" -ForegroundColor Green
}

function New-Dir {
    param([string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

$gemini3 = Join-Path $DesktopRoot 'Absolute Regression Novel gemini3'
$ownalpha = Join-Path $DesktopRoot 'Absolute-Regression-Novel-ownalpha'
$claude = Join-Path $DesktopRoot 'Absolute Regression Novel Claude'
$old = Join-Path $DesktopRoot 'Absolute Regression Novel-old'
$gemini25 = Join-Path $DesktopRoot 'Absolute Regression Novel gemini2.5'

$missingFixtures = @()
foreach ($required in @($gemini3, $ownalpha, $claude, $old, $gemini25)) {
    if (-not (Test-Path -LiteralPath $required -PathType Container)) {
        $missingFixtures += $required
    }
}
# suite นี้พึ่ง real-run folders ของผู้เขียนบน Desktop (ไม่ได้ bundle ใน repo)
# บน clone เปล่า/CI จะไม่มี fixture เหล่านี้ — skip แทน fail เพื่อไม่ให้ CI แดงจากเหตุที่คาดได้
if ($missingFixtures.Count -gt 0) {
    Write-Host "[SKIP] regression suite ต้องมี real-run fixtures บน Desktop ซึ่งไม่ได้ bundle ใน repo:" -ForegroundColor Yellow
    foreach ($m in $missingFixtures) { Write-Host "         - $m" -ForegroundColor Yellow }
    Write-Host "       suite นี้รันได้เฉพาะเครื่องที่มี run เดิม; ข้ามไปบนสภาพแวดล้อมอื่น (exit 0)" -ForegroundColor Yellow
    Write-Host "       (ส่ง -DesktopRoot ชี้โฟลเดอร์ที่มี fixtures เพื่อรันเต็ม)" -ForegroundColor Yellow
    exit 0
}

Invoke-Step 'gemini3 ch020-025 must fail audit (phantom + text leaks)' {
    powershell -File $auditScript -RepoRoot $gemini3 -Start 20 -End 25 -CheckText
} 1

Invoke-Step 'ownalpha ch310-320 draft-only must pass audit' {
    powershell -File $auditScript -RepoRoot $ownalpha -Start 310 -End 320 -CheckText
} 0

Invoke-Step 'old ch001-030 stage-column status table must pass with warnings only' {
    powershell -File $auditScript -RepoRoot $old -Start 1 -End 30 -CheckText
} 0

Invoke-Step 'gemini2.5 ch001-010 scaffold must fail audit when explicit range has no chapter evidence' {
    powershell -File $auditScript -RepoRoot $gemini25 -Start 1 -End 10 -CheckText
} 1

$fixtureRoot = Join-Path $RepoRoot 'workspace/real-run-gate-fixture'
Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
try {
    foreach ($d in @('reports', 'logs', 'okf', 'thai_draft', 'thai_edited', 'thai_final', 'qa/reports')) {
        New-Dir (Join-Path $fixtureRoot $d)
    }

    Get-ChildItem -Path (Join-Path $claude 'thai_draft/ch00*.md') | Copy-Item -Destination (Join-Path $fixtureRoot 'thai_draft')
    Get-ChildItem -Path (Join-Path $claude 'thai_edited/ch00*.md') | Copy-Item -Destination (Join-Path $fixtureRoot 'thai_edited')
    Get-ChildItem -Path (Join-Path $claude 'thai_final/ch00*.md') | Copy-Item -Destination (Join-Path $fixtureRoot 'thai_final')
    Get-ChildItem -Path (Join-Path $claude 'qa/reports/ch00*-qa.md') | Copy-Item -Destination (Join-Path $fixtureRoot 'qa/reports')

    Set-Content -LiteralPath (Join-Path $fixtureRoot 'reports/batch-plan.md') -Encoding UTF8 -Value @(
        '# Arc Plan',
        '',
        '| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |',
        '|---:|---|---|---|---|---|---|---|---|',
        '| 1 | 1-5 | C | done | done | | 2026-06-19 | reports/consistency-001-005.md | fixture |'
    )
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'reports/consistency-001-005.md') -Encoding UTF8 -Value @(
        '# Consistency 001-005',
        '',
        'Fixture report long enough to satisfy gate. No blocking drift found in this fixture.'
    )
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'okf/arc-freeze-log.md') -Encoding UTF8 -Value @(
        '# OKF Arc Freeze Log',
        '',
        '| Arc | Chapters | วันที่ freeze | จำนวนศัพท์ที่ล็อก | Consistency report | หมายเหตุ |',
        '|---:|---|---|---:|---|---|',
        '| 1 | 1-5 | 2026-06-19 | 1 | reports/consistency-001-005.md | fixture |'
    )
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'logs/chapter-status.md') -Encoding UTF8 -Value @(
        '# Chapter Status',
        '',
        '| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |',
        '|---:|---:|---|---|---|---|---|---|---|',
        '| 1 | 1 | Final | x | x | x | x | 2026-06-19 | |',
        '| 2 | 1 | Final | x | x | x | x | 2026-06-19 | |',
        '| 3 | 1 | Final | x | x | x | x | 2026-06-19 | |',
        '| 4 | 1 | Final | x | x | x | x | 2026-06-19 | |',
        '| 5 | 1 | Final | x | x | x | x | 2026-06-19 | |'
    )

    Invoke-Step 'Claude-derived 5 chapter fixture audit must pass with warnings only' {
        powershell -File $auditScript -RepoRoot $fixtureRoot -Start 1 -End 5 -CheckText
    } 0
    Invoke-Step 'Claude-derived fixture Phase B gate must pass' {
        powershell -File $phaseScript -RepoRoot $fixtureRoot -Arc 1 -Phase B
    } 0
    Invoke-Step 'Claude-derived fixture Phase C gate must pass' {
        powershell -File $phaseScript -RepoRoot $fixtureRoot -Arc 1 -Phase C
    } 0
    Invoke-Step 'Claude-derived fixture ship gate must pass' {
        powershell -File $phaseScript -RepoRoot $fixtureRoot -Arc 1 -Phase ship
    } 0
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$stagedRoot = Join-Path $RepoRoot 'workspace/staged-workflow-fixture'
Remove-Item -LiteralPath $stagedRoot -Recurse -Force -ErrorAction SilentlyContinue
try {
    foreach ($d in @('reports', 'logs', 'okf', 'thai_draft', 'thai_edited', 'thai_final', 'qa/reports')) {
        New-Dir (Join-Path $stagedRoot $d)
    }
    Set-Content -LiteralPath (Join-Path $stagedRoot 'reports/batch-plan.md') -Encoding UTF8 -Value @(
        '# Arc Plan',
        '',
        '| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |',
        '|---:|---|---|---|---|---|---|---|---|',
        '| 1 | 1-5 | A | | | | | | staged fixture |'
    )
    Set-Content -LiteralPath (Join-Path $stagedRoot 'logs/chapter-status.md') -Encoding UTF8 -Value @(
        '# Chapter Status',
        '',
        '| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |',
        '|---:|---:|---|---|---|---|---|---|---|'
    )

    foreach ($ch in 1..5) {
        $nnn = '{0:D3}' -f $ch
        Copy-Item -LiteralPath (Join-Path $claude "thai_draft/ch$nnn.md") -Destination (Join-Path $stagedRoot "thai_draft/ch$nnn.md")
        Invoke-Step "staged ch$nnn set draft" {
            powershell -File $statusScript -RepoRoot $stagedRoot -Chapter $ch -Stage draft -Arc 1
        } 0

        Copy-Item -LiteralPath (Join-Path $claude "qa/reports/ch$nnn-qa.md") -Destination (Join-Path $stagedRoot "qa/reports/ch$nnn-qa.md")
        Invoke-Step "staged ch$nnn set QA" {
            powershell -File $statusScript -RepoRoot $stagedRoot -Chapter $ch -Stage qa -Verdict Pass
        } 0
    }

    Set-Content -LiteralPath (Join-Path $stagedRoot 'reports/consistency-001-005.md') -Encoding UTF8 -Value @(
        '# Consistency 001-005',
        '',
        'Staged fixture report long enough to satisfy gate. No blocking drift found in this staged fixture.'
    )
    Set-Content -LiteralPath (Join-Path $stagedRoot 'okf/arc-freeze-log.md') -Encoding UTF8 -Value @(
        '# OKF Arc Freeze Log',
        '',
        '| Arc | Chapters | วันที่ freeze | จำนวนศัพท์ที่ล็อก | Consistency report | หมายเหตุ |',
        '|---:|---|---|---:|---|---|',
        '| 1 | 1-5 | 2026-06-19 | 1 | reports/consistency-001-005.md | staged fixture |'
    )

    Invoke-Step 'staged fixture Phase B gate after Draft+QA must pass' {
        powershell -File $phaseScript -RepoRoot $stagedRoot -Arc 1 -Phase B
    } 0

    foreach ($ch in 1..5) {
        $nnn = '{0:D3}' -f $ch
        Copy-Item -LiteralPath (Join-Path $claude "thai_edited/ch$nnn.md") -Destination (Join-Path $stagedRoot "thai_edited/ch$nnn.md")
        Invoke-Step "staged ch$nnn set edited" {
            powershell -File $statusScript -RepoRoot $stagedRoot -Chapter $ch -Stage edited
        } 0
    }

    Invoke-Step 'staged fixture Phase C gate after Edited must pass' {
        powershell -File $phaseScript -RepoRoot $stagedRoot -Arc 1 -Phase C
    } 0

    foreach ($ch in 1..5) {
        $nnn = '{0:D3}' -f $ch
        Copy-Item -LiteralPath (Join-Path $claude "thai_final/ch$nnn.md") -Destination (Join-Path $stagedRoot "thai_final/ch$nnn.md")
        Invoke-Step "staged ch$nnn set final" {
            powershell -File $statusScript -RepoRoot $stagedRoot -Chapter $ch -Stage final
        } 0
    }

    Invoke-Step 'staged fixture ship gate after Final must pass' {
        powershell -File $phaseScript -RepoRoot $stagedRoot -Arc 1 -Phase ship
    } 0
    Invoke-Step 'staged fixture final audit must pass with warnings only' {
        powershell -File $auditScript -RepoRoot $stagedRoot -Start 1 -End 5 -CheckText
    } 0
}
finally {
    Remove-Item -LiteralPath $stagedRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$ownalphaStagedRoot = Join-Path $RepoRoot 'workspace/ownalpha-staged-fixture'
Remove-Item -LiteralPath $ownalphaStagedRoot -Recurse -Force -ErrorAction SilentlyContinue
try {
    foreach ($d in @('reports', 'logs', 'okf', 'thai_draft', 'thai_edited', 'thai_final', 'qa/reports')) {
        New-Dir (Join-Path $ownalphaStagedRoot $d)
    }
    Set-Content -LiteralPath (Join-Path $ownalphaStagedRoot 'reports/batch-plan.md') -Encoding UTF8 -Value @(
        '# Arc Plan',
        '',
        '| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |',
        '|---:|---|---|---|---|---|---|---|---|',
        '| 1 | 310-314 | A | | | | | | ownalpha staged fixture |'
    )
    Set-Content -LiteralPath (Join-Path $ownalphaStagedRoot 'logs/chapter-status.md') -Encoding UTF8 -Value @(
        '# Chapter Status',
        '',
        '| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |',
        '|---:|---:|---|---|---|---|---|---|---|'
    )

    foreach ($ch in 310..314) {
        $nnn = '{0:D3}' -f $ch
        $draftSource = Join-Path $ownalpha "thai_draft/ch$nnn.md"
        if (-not (Test-Path -LiteralPath $draftSource -PathType Leaf)) {
            Write-Host "[ERROR] Missing ownalpha draft fixture source: $draftSource" -ForegroundColor Red
            exit 2
        }
        Copy-Item -LiteralPath $draftSource -Destination (Join-Path $ownalphaStagedRoot "thai_draft/ch$nnn.md")
        Invoke-Step "ownalpha staged ch$nnn set draft" {
            powershell -File $statusScript -RepoRoot $ownalphaStagedRoot -Chapter $ch -Stage draft -Arc 1
        } 0

        Set-Content -LiteralPath (Join-Path $ownalphaStagedRoot "qa/reports/ch$nnn-qa.md") -Encoding UTF8 -Value @(
            "# QA Report ch$nnn",
            '',
            '| Severity | Location | Original/Thai issue | Recommendation |',
            '|---|---|---|---|',
            '',
            '## Evidence',
            "- Checked real draft lines `L1-L3` from ownalpha ch$nnn fixture.",
            '',
            '## Verdict',
            'Pass'
        )
        Invoke-Step "ownalpha staged ch$nnn set QA" {
            powershell -File $statusScript -RepoRoot $ownalphaStagedRoot -Chapter $ch -Stage qa -Verdict Pass
        } 0
    }

    Set-Content -LiteralPath (Join-Path $ownalphaStagedRoot 'reports/consistency-310-314.md') -Encoding UTF8 -Value @(
        '# Consistency 310-314',
        '',
        'Ownalpha staged fixture report long enough to satisfy gate. This is a gate smoke test, not a literary edit.'
    )
    Set-Content -LiteralPath (Join-Path $ownalphaStagedRoot 'okf/arc-freeze-log.md') -Encoding UTF8 -Value @(
        '# OKF Arc Freeze Log',
        '',
        '| Arc | Chapters | วันที่ freeze | จำนวนศัพท์ที่ล็อก | Consistency report | หมายเหตุ |',
        '|---:|---|---|---:|---|---|',
        '| 1 | 310-314 | 2026-06-19 | 1 | reports/consistency-310-314.md | ownalpha staged fixture |'
    )

    Invoke-Step 'ownalpha staged fixture Phase B gate must pass' {
        powershell -File $phaseScript -RepoRoot $ownalphaStagedRoot -Arc 1 -Phase B
    } 0

    foreach ($ch in 310..314) {
        $nnn = '{0:D3}' -f $ch
        Copy-Item -LiteralPath (Join-Path $ownalphaStagedRoot "thai_draft/ch$nnn.md") -Destination (Join-Path $ownalphaStagedRoot "thai_edited/ch$nnn.md")
        Invoke-Step "ownalpha staged ch$nnn set edited" {
            powershell -File $statusScript -RepoRoot $ownalphaStagedRoot -Chapter $ch -Stage edited
        } 0
    }

    Invoke-Step 'ownalpha staged fixture Phase C gate must pass' {
        powershell -File $phaseScript -RepoRoot $ownalphaStagedRoot -Arc 1 -Phase C
    } 0

    foreach ($ch in 310..314) {
        $nnn = '{0:D3}' -f $ch
        Copy-Item -LiteralPath (Join-Path $ownalphaStagedRoot "thai_edited/ch$nnn.md") -Destination (Join-Path $ownalphaStagedRoot "thai_final/ch$nnn.md")
        Invoke-Step "ownalpha staged ch$nnn set final" {
            powershell -File $statusScript -RepoRoot $ownalphaStagedRoot -Chapter $ch -Stage final
        } 0
    }

    Invoke-Step 'ownalpha staged fixture ship gate must pass' {
        powershell -File $phaseScript -RepoRoot $ownalphaStagedRoot -Arc 1 -Phase ship
    } 0
    Invoke-Step 'ownalpha staged fixture final audit must pass' {
        powershell -File $auditScript -RepoRoot $ownalphaStagedRoot -Start 310 -End 314 -CheckText
    } 0
}
finally {
    Remove-Item -LiteralPath $ownalphaStagedRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$badStatusRoot = Join-Path $RepoRoot 'workspace/setstatus-negative-fixture'
Remove-Item -LiteralPath $badStatusRoot -Recurse -Force -ErrorAction SilentlyContinue
try {
    New-Dir (Join-Path $badStatusRoot 'logs')
    New-Dir (Join-Path $badStatusRoot 'thai_final')
    Set-Content -LiteralPath (Join-Path $badStatusRoot 'logs/chapter-status.md') -Encoding UTF8 -Value @(
        '# Chapter Status',
        '',
        '| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |',
        '|---:|---:|---|---|---|---|---|---|---|'
    )
    Set-Content -LiteralPath (Join-Path $badStatusRoot 'thai_final/ch001.md') -Encoding UTF8 -Value 'final only'

    Invoke-Step 'set-status final must fail without prior stage files' {
        powershell -File $statusScript -RepoRoot $badStatusRoot -Chapter 1 -Stage final
    } 1
}
finally {
    Remove-Item -LiteralPath $badStatusRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$badArcRoot = Join-Path $RepoRoot 'workspace/arcgate-negative-fixture'
Remove-Item -LiteralPath $badArcRoot -Recurse -Force -ErrorAction SilentlyContinue
try {
    foreach ($d in @('reports', 'logs', 'okf', 'thai_draft', 'qa/reports')) {
        New-Dir (Join-Path $badArcRoot $d)
    }
    Set-Content -LiteralPath (Join-Path $badArcRoot 'reports/batch-plan.md') -Encoding UTF8 -Value @(
        '# Arc Plan',
        '',
        '| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |',
        '|---:|---|---|---|---|---|---|---|---|',
        '| 1 | 1-2 | A | done | | | 2026-06-19 | reports/consistency-001-002.md | test |'
    )
    Set-Content -LiteralPath (Join-Path $badArcRoot 'logs/chapter-status.md') -Encoding UTF8 -Value @(
        '# Chapter Status',
        '',
        '| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |',
        '|---:|---:|---|---|---|---|---|---|---|',
        '| 1 | 1 | QA: Pass | x | x | | | 2026-06-19 | |',
        '| 2 | 1 | QA: Pass | x | x | | | 2026-06-19 | |'
    )
    Set-Content -LiteralPath (Join-Path $badArcRoot 'okf/arc-freeze-log.md') -Encoding UTF8 -Value @(
        '# OKF Arc Freeze Log',
        '',
        '| Arc | Chapters | วันที่ freeze | จำนวนศัพท์ที่ล็อก | Consistency report | หมายเหตุ |',
        '|---:|---|---|---:|---|---|',
        '| 1 | 1-2 | 2026-06-19 | 1 | reports/consistency-001-002.md | test |'
    )
    Set-Content -LiteralPath (Join-Path $badArcRoot 'thai_draft/ch001.md') -Encoding UTF8 -Value 'draft 1'
    Set-Content -LiteralPath (Join-Path $badArcRoot 'qa/reports/ch001-qa.md') -Encoding UTF8 -Value 'qa 1'

    Invoke-Step 'Phase B gate must fail when files and consistency report are missing' {
        powershell -File $phaseScript -RepoRoot $badArcRoot -Arc 1 -Phase B
    } 1
}
finally {
    Remove-Item -LiteralPath $badArcRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[PASS] real-run gate regression harness completed" -ForegroundColor Green
exit 0
