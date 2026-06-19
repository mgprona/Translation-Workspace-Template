# Real-Run Gate Test Results

Date: 2026-06-19
Branch: `harden-real-run-gates`

## Command

```powershell
powershell -File etc/test-real-run-gates.ps1
```

## Result

PASS.

## Covered Cases

| Case | Source data | Expected | Result |
|---|---|---:|---:|
| Broken real run | `Absolute Regression Novel gemini3` ch020-025 | fail | pass: audit failed as expected |
| Latest draft-only run | `Absolute-Regression-Novel-ownalpha` ch310-320 | pass | pass |
| Legacy completed run | `Absolute Regression Novel-old` ch001-030 | pass with QA warnings | pass |
| Incomplete scaffold run | `Absolute Regression Novel gemini2.5` ch001-010 | fail | pass: audit failed as expected |
| Existing five-chapter completed run | `Absolute Regression Novel Claude` ch001-005 copied into temp fixture | pass with QA warnings | pass |
| Staged five-chapter process | Claude ch001-005 copied stage-by-stage into temp fixture | Draft -> QA -> Phase B -> Edited -> Phase C -> Final -> ship | pass |
| Latest-run staged five-chapter process | `Absolute-Regression-Novel-ownalpha` ch310-314 drafts copied stage-by-stage into temp fixture | Draft -> QA -> Phase B -> Edited -> Phase C -> Final -> ship -> final audit | pass |
| Negative final status | Temp fixture with only `thai_final/ch001.md` | fail | pass: `set-status` rejected Final |
| Negative Phase B gate | Temp fixture missing ch002 files and consistency report | fail | pass: `check-arc-phase` rejected Phase B |

## Key Evidence

- `gemini3` ch022 is caught as `status-file-missing`: status says `Final`, but draft/edited/final files are missing.
- `gemini3` ch020-025 are caught for text leaks, including English glosses and CJK/Hangul residues in final files.
- `old` ch001-030 proves the audit can read the older status table shape with separate Draft/QA/Edited/Final columns.
- `gemini2.5` ch001-010 proves an explicit audit range fails when there is no status row or chapter stage file evidence.
- The staged five-chapter fixture uses `set-status.ps1` for every stage transition, not a prefilled status table.
- The ownalpha staged fixture starts from the latest real draft files ch310-314 and reaches ship with a clean final audit.
- Phase gates are executed after each staged milestone:
  - Phase B after Draft+QA.
  - Phase C after Edited.
  - Ship after Final.

## Remaining Warning

The Claude-derived and old-run fixtures pass file/stage gates but warn that QA reports lack line/paragraph references. This is intentionally non-blocking for legacy data, but prompts now require real locations for new QA reports.
