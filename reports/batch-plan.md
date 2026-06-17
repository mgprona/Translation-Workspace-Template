# Arc Plan

แผนระดับ **arc** (≈ 30 ตอน ≈ หนึ่งเล่ม) — หน่วยส่งมอบของโปรเจกต์นี้

แต่ละ arc เดิน 3 เฟส: **A (Draft+QA รายตอน)** → **B (Edit ทั้ง arc)** → **C (Final ทั้ง arc)** → ส่งมอบ

| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |
|---:|---|---|---|---|---|---|---|---|

<!-- ตัวอย่างแถว (ลบทิ้งได้เมื่อเริ่มงานจริง):
| 1 | 1-30 | A | 12/30 | | | | | ศึกแรก จบที่ ch30 |
- Phase: A / B / C / Shipped
- A/B/C cell: ความคืบหน้า เช่น 12/30 หรือ done
- OKF freeze: วันที่ freeze ศัพท์ของ arc นี้ (ก่อนเข้า Phase B) เช่น 2026-06-17
- Consistency: path รายงาน เช่น reports/consistency-001-030.md
-->

## รูปแบบช่วงตอน (สำคัญ — สคริปต์อ่านคอลัมน์นี้)

คอลัมน์ `Chapters` ต้องเป็นรูป `START-END` (เช่น `1-30`, `31-58`) — `etc/check-arc-phase.ps1` parse ช่วงนี้เพื่อรู้ว่า arc มีตอนไหนบ้าง

## Rules (gate บังคับ)

- **ขอบเขต arc**: AI อ่าน source เสนอจุดตัด arc (ยืดหยุ่น 28-34 ตอน ตัดที่รอยต่อเนื้อเรื่อง) → คนยืนยัน → ลงแถวนี้ก่อนเริ่ม Phase A
- **Phase A → B**: ก่อนเริ่ม Edit ต้องรัน `powershell -File etc/check-arc-phase.ps1 -Arc <N> -Phase B` — ผ่านเมื่อทุกตอนใน arc มีสถานะ `QA: Pass`/`QA: Pass-minor` (ไม่มีตอนค้าง Draft/Needs-revision/Re-translate) **และ** ทำ consistency ระดับ arc + OKF freeze แล้ว
- **Phase B → C**: ก่อนเริ่ม Final ต้องรัน `powershell -File etc/check-arc-phase.ps1 -Arc <N> -Phase C` — ผ่านเมื่อทุกตอน `Edited`
- **ปิด arc (ส่งมอบ)**: รัน `powershell -File etc/check-arc-phase.ps1 -Arc <N> -Phase ship` — ผ่านเมื่อทุกตอน `Final`
- **OKF freeze** ทำก่อนเข้า Phase B เสมอ (ดู `okf/arc-freeze-log.md`) — freeze แบบอ่อน: แก้ย้อนได้ถ้ามีเหตุผล + บันทึก + รัน `etc/replace-term.ps1` ไล่แก้ทั้ง arc
- **ห้ามเริ่ม arc ถัดไป** จนกว่า arc ปัจจุบันจะ Shipped (ยกเว้นผู้ใช้สั่งเป็นอย่างอื่น)
