---
type: Translation Policy
title: Translation Policy
status: draft
updated: {DATE}
---

# Translation Policy

1. Use the primary source (`../sources/primary_chapter`) as the chapter-by-chapter source of truth. The primary language is set during setup — see [source-map.md](source-map.md).
2. Use the reference source (`../sources/reference_chapter`, a second language when available) to verify names, title nuance, and faction terminology.
3. When the sources disagree, prefer the primary source unless the discrepancy is clearly a typo or a missing continuation cue.
5. Never mix two Thai renderings for the same term across the same arc. (Arc = หน่วยงาน ≈30 ตอน ≈ หนึ่งเล่ม — ดูขอบเขตใน `../reports/batch-plan.md`)
6. Never let source markup, notes, or half-finished edits leak into the final prose.

## OKF freeze per arc (soft-freeze)

ตอนจบ Phase A ของแต่ละ arc (draft+QA ครบทั้ง arc) ให้ **freeze ศัพท์ของ arc นั้น** ก่อนเข้า Phase B (เกลา) — บันทึกใน `arc-freeze-log.md`

Freeze แบบอ่อน: ศัพท์ที่ freeze เป็นมาตรฐาน **แต่แก้ย้อนได้ถ้ามีเหตุผล** (arc หลังพบว่าคำเดิมพลาด) โดยต้อง (1) บันทึกใน `arc-freeze-log.md` (2) แก้ OKF (3) รัน `../etc/replace-term.ps1` ไล่แก้ทั้ง arc (encoding-safe) (4) รัน `../etc/check-encoding.ps1` ยืนยันไม่พัง

## Default rendering rules

- Use semantic Thai for titles and factions when that keeps the line readable.
- Use transliteration only when the name is the identity.
- Keep chapter numbering intact.
- Clean chapter titles before registry output.
