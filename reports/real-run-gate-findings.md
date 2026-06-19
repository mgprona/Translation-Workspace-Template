# Real-Run Gate Findings

This branch hardens the workflow from failures found in actual Absolute Regression runs, not from hypothetical review.

## Evidence From Real Runs

| Run folder | Evidence | Risk |
|---|---|---|
| `Absolute Regression Novel gemini3` | `logs/chapter-status.md` marks ch022 as `Final`, and `qa/reports/ch022-qa.md` exists, but `thai_draft/ch022.md`, `thai_edited/ch022.md`, and `thai_final/ch022.md` are missing. | Phantom chapter: delivery can silently skip a chapter. |
| `Absolute Regression Novel gemini3` | ch020-025 contain English glosses in final files; ch021 and ch023 also contain CJK/Hangul leaks. | Final output can ship source-language residue. |
| `Absolute Regression Novel gemini3` | QA reports use weak locations such as `Terminology`/`General` and mostly lack real line/paragraph references. | Rubber-stamp QA: report exists but does not prove the draft was inspected. |
| `Absolute Regression Novel Claude` | ch001-005 have draft/QA/edited/final files, but QA reports lack line/paragraph references. | Usable as a pass fixture for file gates, while still surfacing QA-evidence warnings. |
| `Absolute-Regression-Novel-ownalpha` | ch310-320 are draft-only and status says Draft. | Correct in-progress state; audit should not require later-stage files yet. |
| `Absolute Regression Novel-old` | ch001-030 use an older status table with separate Draft/QA/Edited/Final columns. Files exist, but QA reports mostly lack line/paragraph references. ch031 has no status row or stage file evidence. | Audit must support legacy status shape without treating old QA evidence as clean, and must fail if asked to audit past the real completed range. |
| `Absolute Regression Novel gemini2.5` | Scaffold contains `sources/absolute_regression_full.txt` but no `logs/chapter-status.md` and no chapter stage files for ch001-010. | An explicit audit range with no chapter evidence must fail, not pass silently. |

## Gate Strategy

- `set-status.ps1` now verifies prior stage files before moving to QA, Edited, or Final.
- `check-arc-phase.ps1` now verifies real stage files, not only status table values.
- Phase B now requires a real consistency report referenced from `okf/arc-freeze-log.md`.
- `term-extract.ps1 -FailOnIssue` evaluates the fresh scan even when an old `term-extract-report.md` exists.
- `audit-workspace.ps1` scans a range for phantom chapters, missing stage files, weak QA evidence, text leaks, and mojibake.
- `audit-workspace.ps1` now blocks explicit chapter ranges with no status row or stage file evidence.
- `audit-workspace.ps1` supports the old stage-column status table used by `Absolute Regression Novel-old`.
- `test-real-run-gates.ps1` replays real-run regressions and a five-chapter staged workflow smoke test.

## Regression Command

Run this from the template repo:

```powershell
powershell -File etc/test-real-run-gates.ps1
```

The expected result is:

- `gemini3` ch020-025 fails audit.
- `ownalpha` ch310-320 passes as draft-only.
- `old` ch001-030 passes file/text gates with QA evidence warnings.
- `gemini2.5` ch001-010 fails audit because the explicit range has no chapter evidence.
- A five-chapter Claude-derived fixture walks Draft -> QA -> Edited -> Final via `set-status.ps1`.
- Phase B, Phase C, and ship gates pass on that staged fixture.
- Negative fixtures fail when prior-stage files or consistency reports are missing.
