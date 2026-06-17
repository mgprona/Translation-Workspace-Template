# Chapter Status

แหล่งความจริงเดียว (single source of truth) ของสถานะแต่ละตอน — ทุก prompt ในไพป์ไลน์ต้องอัปเดตไฟล์นี้หลังทำงานเสร็จ

คอลัมน์ `Status` = สถานะปัจจุบัน (ให้ `07-resume` อ่านเร็ว); คอลัมน์ Draft/QA/Edited/Final = ร่องรอยแต่ละ stage (path + verdict เพื่อตามประวัติย้อนหลังได้); คอลัมน์ `Arc` = ตอนนี้อยู่ arc ไหน (ดู `reports/batch-plan.md`)

| Chapter | Arc | Status | Draft | QA | Edited | Final | Updated | Notes |
|---:|---:|---|---|---|---|---|---|---|

<!-- ตัวอย่างแถว (ลบทิ้งได้เมื่อเริ่มงานจริง):
| 1 | 1 | Final | `thai_draft/ch001.md` | Pass-minor: `qa/reports/ch001-qa.md` | `thai_edited/ch001.md` | `thai_final/ch001.md` | 2026-06-17 | title locked |
-->

## Status vocabulary

สถานะเดินหน้าตามลำดับ (forward-only เว้นแต่ QA ตีกลับ):

| Status | ความหมาย | ตั้งโดย prompt | ขั้นถัดไป |
|---|---|---|---|
| `Draft` | แปลร่างเสร็จแล้ว รอ QA | `01-translate-chapter` | QA |
| `QA: Pass` | QA ผ่าน รอเกลา | `02-qa-chapter` | Polish |
| `QA: Pass-minor` | QA ผ่านแบบมีจุดแก้เล็กน้อย รอเกลา | `02-qa-chapter` | Polish |
| `QA: Needs-revision` | QA ตีกลับ ต้องแก้แล้ว QA ใหม่ | `02-qa-chapter` | Polish (แก้) → QA ซ้ำ |
| `QA: Re-translate` | QA ตีกลับหนัก ต้องแปลใหม่ | `02-qa-chapter` | Translate ใหม่ |
| `Edited` | เกลาสำนวนเสร็จ รอ finalize | `03-polish-chapter` | Finalize |
| `Final` | ฉบับสมบูรณ์ | `06-finalize-chapter` | — (จบ) |

## Rules

- ทุก prompt ที่เปลี่ยนสถานะตอนต้อง **อัปเดตแถวของตอนนั้น** (เพิ่มแถวใหม่ถ้ายังไม่มี) ก่อนจบงาน — ตั้ง `Status` ปัจจุบัน และเติมเซลล์ stage ที่เพิ่งทำ (ใส่ path ของ output; ช่อง QA ใส่ verdict ด้วย)
- ใช้ `etc/set-status.ps1` เขียนสถานะเสมอ (ตรวจไฟล์จริง + ลง timestamp + คอลัมน์ Arc ให้อัตโนมัติ) — ห้ามแก้ตารางด้วยมือ
- `Status` ต้องเป็นค่าใดค่าหนึ่งจาก vocabulary ด้านบนเท่านั้น
- `07-resume-session` อ่านคอลัมน์ `Status` + `Arc` เป็นหลักเพื่อรู้ว่าตอนไหนค้างขั้นไหนใน arc ไหน — ถ้าไม่อัปเดต วงจร resume จะพัง
- ห้ามตั้ง `Final` ถ้า stage gate ใน `06-finalize-chapter` ยังไม่ผ่านครบ

## หมายเหตุเรื่อง Arc/Phase

สถานะตอน (Draft→QA→Edited→Final) เป็นของ **รายตอน** ส่วน Phase A/B/C เป็นของ **arc** (ดู `reports/batch-plan.md`):

- **Phase A** ของ arc = ตอนในนั้นเดิน Draft → QA รายตอน (`Status` ขึ้นได้ถึง `QA: Pass`/`Pass-minor`)
- **Phase B** = เกลาทั้ง arc รวด (`Status` → `Edited`) ทำหลัง gate A→B ผ่าน + OKF freeze
- **Phase C** = finalize ทั้ง arc รวด (`Status` → `Final`) ทำหลัง gate B→C ผ่าน

ดังนั้นตอนหนึ่งอาจค้างที่ `QA: Pass` นานจนกว่าทั้ง arc จะ draft ครบแล้วเข้า Phase B พร้อมกัน — นี่คือพฤติกรรมที่ถูกต้องของ arc model (ไม่ใช่ค้างผิดปกติ)

