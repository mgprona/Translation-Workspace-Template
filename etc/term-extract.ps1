<#
.SYNOPSIS
    สแกนร่างแปลไทยหาเศษภาษาแปลกปลอม (จีน/เกาหลี/อังกฤษ/markup) ที่ไม่ควรหลุดในบทแปล

.DESCRIPTION
    ใช้ก่อนหรือระหว่าง QA stage เพื่อจับ:
    - อักษรจีน (CJK Unified Ideographs)
    - อักษรเกาหลี (Hangul Syllables)
    - ภาษาอังกฤษที่อยู่ในบรรทัดแปล (ไม่ใช่ชื่อเฉพาะใน OKF)
    - Markup: [b], [/b], [color], BBCode tags
    - ตัวเลขที่ติดกับอักษรไทยผิดปกติ

.PARAMETER TargetPath
    ไฟล์ .md เดียว หรือโฟลเดอร์ที่รวม draft/edited/final ทั้งหมด

.PARAMETER OkfPath
    พาธไปยังโฟลเดอร์ okf/ สำหรับ Whitelist (ชื่อตัวละคร/ศัพท์ที่ขึ้นต้นด้วยอังกฤษได้)

.PARAMETER ReportOnly
    ถ้าใส่ flag นี้ จะ overwrite report เดิมโดยไม่ถาม user ก่อน

.PARAMETER FailOnIssue
    คืน exit code 1 เมื่อพบ issue ระดับ block แม้มี report เดิมอยู่แล้ว

.EXAMPLE
    .\term-extract.ps1 -TargetPath "..\thai_draft\ch300.md" -OkfPath "..\okf"

.EXAMPLE
    .\term-extract.ps1 -TargetPath "..\thai_draft" -OkfPath "..\okf"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [Parameter(Mandatory = $false)]
    [string]$OkfPath = (Join-Path -Path $TargetPath -ChildPath "..\..\okf"),

    [switch]$ReportOnly,

    # ถ้าใส่ flag นี้ สคริปต์จะคืน exit code 1 เมื่อพบ issue ระดับ block
    # (CJK / Hangul / Markup / วงเล็บอังกฤษ) เพื่อใช้เป็น hard gate ก่อน finalize
    [switch]$FailOnIssue
)

# ──────────────────────────────────────────────
# 1. Regex patterns
# ──────────────────────────────────────────────

# Chinese characters (CJK Unified Ideographs: U+4E00–U+9FFF)
# .NET regex uses \uXXXX (4 hex digits), NOT \x{XXXX} which is a parse error here.
$cjkPattern = '[一-鿿]'

# Korean Hangul Syllables (U+AC00–U+D7AF)
$hangulPattern = '[가-힯]'

# English letters (whole words, not abbreviations)
$englishWordPattern = '\b[A-Za-z]{2,}\b'

# BBCode / markup tags — ชื่อ tag ต้องขึ้นต้นด้วย ASCII letter
# (กัน false-positive กับวงเล็บแหลมครอบคำไทย เช่น <ก็ได้> และ footnote ตัวเลข เช่น [1])
$markupPattern = '\[/?[A-Za-z][\w="]*\]|</?[A-Za-z][\w-]*>'

# วงเล็บกำกับศัพท์อังกฤษในเนื้อเรื่อง เช่น 'สามผนึก' (Three Seals)
# จากงานจริง โมเดลชอบแปะอังกฤษกำกับในวงเล็บ ซึ่งละเมิดกฎ "ห้ามใส่วงเล็บอธิบายศัพท์"
# จับวงเล็บที่เนื้อในมีคำอังกฤษยาว >=2 ตัวอักษร (ติดกันเป็นคำ)
$englishGlossPattern = '[\(（][^)）]*[A-Za-z]{2,}[^)）]*[\)）]'

# Thai characters range
$thaiRange = '[\u0E00-\u0E7F]'

# ──────────────────────────────────────────────
# 2. Build whitelist from OKF
# ──────────────────────────────────────────────

$whitelist = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

if (Test-Path -LiteralPath $OkfPath) {
    $okfFiles = Get-ChildItem -LiteralPath $OkfPath -Filter "*.md"
    foreach ($f in $okfFiles) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        # Extract Thai-column values (proper nouns that legitimately contain Thai)
        $thaiMatches = [regex]::Matches($content, '(?<=\|)\s*([\u0E00-\u0E7F][\u0E00-\u0E7F\s]+?)(?=\s*\|)')
        foreach ($m in $thaiMatches) {
            $term = $m.Groups[1].Value.Trim()
            if ($term.Length -ge 2) {
                $null = $whitelist.Add($term)
            }
        }
        # Extract English proper nouns from OKF tables so they don't get flagged as stray English.
        # Split each English cell into individual words \u2014 the scanner checks word-by-word.
        $engMatches = [regex]::Matches($content, '(?<=\|)\s*([A-Za-z][A-Za-z0-9 .''\-]+?)(?=\s*\|)')
        foreach ($m in $engMatches) {
            foreach ($word in ($m.Groups[1].Value -split '\s+')) {
                $clean = $word.Trim("'", '.', '-')
                if ($clean.Length -ge 2 -and $clean -match '^[A-Za-z]') {
                    $null = $whitelist.Add($clean)
                }
            }
        }
    }
    Write-Host "[INFO] Loaded $($whitelist.Count) whitelist terms from OKF" -ForegroundColor Cyan
} else {
    Write-Host "[WARN] OKF path not found: $OkfPath — Skipping whitelist" -ForegroundColor Yellow
}

# ──────────────────────────────────────────────
# 3. Resolve target files
# ──────────────────────────────────────────────

$files = @()
if (Test-Path -LiteralPath $TargetPath -PathType Container) {
    $files = Get-ChildItem -LiteralPath $TargetPath -Filter "*.md" -File
} elseif (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $TargetPath)
} else {
    Write-Host "[ERROR] TargetPath not found: $TargetPath" -ForegroundColor Red
    exit 1
}

if ($files.Count -eq 0) {
    Write-Host "[INFO] No .md files found in $TargetPath" -ForegroundColor Yellow
    exit 0
}

# ──────────────────────────────────────────────
# 4. Scan each file
# ──────────────────────────────────────────────

$report = @()
$totalIssues = 0

foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
    $lineNum = 0
    $fileIssues = 0

    foreach ($line in $lines) {
        $lineNum++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Skip lines that are only markdown headers, separators, or OKF terms
        if ($line -match '^#{1,6}\s' -or $line -match '^---$' -or $line -match '^\*{3,}$') { continue }

        $issues = @()

        # 4a. Check CJK (Chinese)
        if ($line -match $cjkPattern) {
            $matched = [regex]::Matches($line, $cjkPattern) | ForEach-Object { $_.Value } | Select-Object -Unique
            $issues += "CJK-Chinese: [$($matched -join ', ')]"
        }

        # 4b. Check Hangul (Korean)
        if ($line -match $hangulPattern) {
            $matched = [regex]::Matches($line, $hangulPattern) | ForEach-Object { $_.Value } | Select-Object -Unique
            $issues += "Hangul-Korean: [$($matched -join ', ')]"
        }

        # 4c. Check markup tags
        if ($line -match $markupPattern) {
            $matched = [regex]::Matches($line, $markupPattern) | ForEach-Object { $_.Value } | Select-Object -Unique
            $issues += "Markup: [$($matched -join ', ')]"
        }

        # 4c2. Check English gloss in parentheses เช่น 'สามผนึก' (Three Seals)
        if ($line -match $englishGlossPattern) {
            $matched = [regex]::Matches($line, $englishGlossPattern) | ForEach-Object { $_.Value } | Select-Object -Unique
            $issues += "EnglishGloss: [$($matched -join ', ')]"
        }

        # 4d. Check English words (filter out whitelisted terms)
        if ($line -match $englishWordPattern) {
            $wordMatches = [regex]::Matches($line, $englishWordPattern)
            $unmatched = @()
            foreach ($wm in $wordMatches) {
                $word = $wm.Value
                # Exact, case-insensitive membership (HashSet is OrdinalIgnoreCase)
                if ($whitelist.Contains($word)) { continue }
                # Skip common English stopwords that are harmless even if they leak
                if ($word -notmatch '^(?:by|the|is|in|at|on|to|for|of|and|or|a|an|it|be|do|up|no|go|so|if|as|we|he|she|my|me|us)$') {
                    $unmatched += $word
                }
            }
            if ($unmatched.Count -gt 0) {
                $issues += "English: [$($unmatched -join ', ')]"
            }
        }

        if ($issues.Count -gt 0) {
            $report += [PSCustomObject]@{
                File    = $file.Name
                Line    = $lineNum
                Content = $line.Trim()
                Issues  = $issues -join '; '
            }
            $fileIssues++
        }
    }

    if ($fileIssues -eq 0) {
        Write-Host "  [PASS] $($file.Name) — clean" -ForegroundColor Green
    } else {
        Write-Host "  [ISSUES] $($file.Name) — $fileIssues line(s) with issues" -ForegroundColor Yellow
    }
    $totalIssues += $fileIssues
}

# ──────────────────────────────────────────────
# 5. Output report
# ──────────────────────────────────────────────

$reportPath = Join-Path -Path (Get-Location) -ChildPath "term-extract-report.md"
$writeReport = $true

# Guard against silently clobbering an existing report. -ReportOnly forces overwrite.
# Important: do not exit here. -FailOnIssue must still evaluate the fresh scan result.
if ((Test-Path -LiteralPath $reportPath) -and -not $ReportOnly) {
    $writeReport = $false
    Write-Host "[WARN] Report already exists: $reportPath" -ForegroundColor Yellow
    Write-Host "[WARN] Re-run with -ReportOnly to overwrite it. Skipping write." -ForegroundColor Yellow
    if ($report.Count -eq 0) {
        Write-Host "`n[RESULT] PASS — No issues found across $($files.Count) file(s) (report not written)" -ForegroundColor Green
    } else {
        Write-Host "`n[RESULT] $($report.Count) issue(s) found (report not written)" -ForegroundColor Yellow
    }
}

if ($writeReport -and $report.Count -eq 0) {
    $summary = "# Term Extraction Report`n`n**Result: PASS** — No issues found in $($files.Count) file(s).`n"
    [System.IO.File]::WriteAllText($reportPath, $summary, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "`n[RESULT] PASS — No issues found across $($files.Count) file(s)" -ForegroundColor Green
} elseif ($writeReport) {
    $lines = @(
        "# Term Extraction Report",
        "",
        "**Result: $($report.Count) issue(s) found across $($files.Count) file(s)**",
        "",
        "| File | Line | Issue | Content |",
        "|---|---|---|---|"
    )

    foreach ($r in $report) {
        $escapedContent = $r.Content -replace '\|', '\|'
        $lines += "| $($r.File) | $($r.Line) | $($r.Issues) | $escapedContent |"
    }

    $lines += ""
    $lines += "## Summary"
    $lines += ""
    $lines += "- Files scanned: $($files.Count)"
    $lines += "- Total issues: $($report.Count)"
    $lines += ""

    [System.IO.File]::WriteAllText($reportPath, ($lines -join "`n"), (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "`n[RESULT] $($report.Count) issue(s) found — Report saved to: $reportPath" -ForegroundColor Yellow

    # Show top issues inline
    Write-Host "`nTop issues:" -ForegroundColor Cyan
    $report | Group-Object -Property Issues | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $($_.Count)x — $($_.Name)" -ForegroundColor Gray
    }
}

# ──────────────────────────────────────────────
# 6. Exit code gate (สำหรับ -FailOnIssue)
# ──────────────────────────────────────────────
# Issue ระดับ block = CJK / Hangul / Markup / EnglishGloss (เศษภาษา/วงเล็บอังกฤษที่ห้ามหลุด)
# English (คำเดี่ยว) ถือเป็น warning ไม่ block เพราะอาจเป็น false positive จากชื่อเฉพาะที่ยังไม่ลง OKF
if ($FailOnIssue) {
    $blocking = @($report | Where-Object { $_.Issues -match 'CJK|Hangul|Markup|EnglishGloss' })
    if ($blocking.Count -gt 0) {
        Write-Host "`n[GATE FAIL] พบ issue ระดับ block $($blocking.Count) จุด (CJK/Hangul/Markup/EnglishGloss) — ห้าม finalize" -ForegroundColor Red
        exit 1
    }
    Write-Host "`n[GATE PASS] ไม่มี issue ระดับ block" -ForegroundColor Green
}
exit 0
