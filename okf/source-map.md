---
type: Source Map
title: Source Hierarchy
status: draft
updated: {DATE}
---

# Source Map

## ภาษาต้นฉบับ (ตั้งตอน setup — ดู prompts/08-bootstrap-okf.md)

- **ภาษาหลัก (primary):** _____ (ภาษาที่ยึดแปล เช่น เกาหลี / อังกฤษ / จีน)
- **ภาษาอ้างอิง (reference):** _____ (อีกภาษาหนึ่งไว้ตรวจชื่อ/นัย — เว้นว่างถ้ามี source ภาษาเดียว)
- **สกัด OKF (ชื่อเฉพาะ) จากภาษา:** _____ (มักเป็นภาษาต้นทางจริงเพื่อถอดเสียงชื่อให้ถูก)

> AI อ่านส่วนนี้ตอนแปลเพื่อรู้ว่ายึดภาษาไหนเป็นหลัก — กรอกให้ครบตอน bootstrap

## โฟลเดอร์ source

| Source | Path | Files | Role | Coverage |
|---|---|---|---:|---|
| Primary source | `../sources/primary_chapter` | N | Primary | Chapters 1-N |
| Reference source | `../sources/reference_chapter` | M | Reference | Chapters 1-M |

## Decision order

1. Primary source (ต้นฉบับหลักที่ยึดแปล)
2. Reference source (ถ้ามี) สำหรับยืนยันชื่อและความหมาย
