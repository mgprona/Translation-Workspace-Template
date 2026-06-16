---
type: Source Map
title: Source Hierarchy
status: draft
updated: {DATE}
---

# Source Map

| Source | Path | Files | Role | Coverage |
|---|---|---|---:|---|
| English serial | `../sources/eng_clean_chapter` | N | Primary | Chapters 1-N |
| Raw source (Korean/other) | `../sources/raw_chapter` | M | Secondary | Chapters 1-M |
| Full text | `../sources/full_text.txt` | 1 | Continuity fallback | Whole story |

## Decision order

1. English serial
2. Raw source (if available) for name and meaning verification
3. Full text for continuity and gap filling
