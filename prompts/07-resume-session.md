# Prompt: Resume Session

กลับมาทำงานต่อจาก session ก่อนหน้า

## ขั้นตอน

### 1. ตรวจสถานะ

อ่านไฟล์สถานะเหล่านี้ก่อน:

- `logs/story-recap.md` — เนื้อเรื่องดำเนินมาถึงไหน (สถานการณ์ปัจจุบัน ปมค้าง ความสัมพันธ์ที่เปลี่ยน) เพื่อจับเรื่องต่อโดยไม่ต้องอ่านบทแปลเก่าทั้งหมด
- `logs/chapter-status.md` — ดูว่าตอนไหนค้างที่ขั้นไหน (Draft/QA/Edited/Final)
- `reports/batch-plan.md` — ดูว่า batch ปัจจุบันคือ batch ไหน, ตอนไหนเสร็จแล้ว, consistency check ทำถึงไหน
- `okf/human-review-needed.md` — ดูว่ามีรายการค้างที่ต้องตัดสินใจไหม

### 2. ระบุงานที่ต้องทำต่อ

จาก `chapter-status.md` (ใช้ status vocabulary ที่นิยามในไฟล์นั้น):

- `Draft` → ต้อง QA (`prompts/02-qa-chapter.md`)
- `QA: Needs-revision` → ต้อง Polish เพื่อแก้ แล้ว QA ซ้ำ (`prompts/03-polish-chapter.md`)
- `QA: Re-translate` → ต้องแปลใหม่ (`prompts/01-translate-chapter.md`)
- `QA: Pass` หรือ `QA: Pass-minor` → ต้อง Polish (`prompts/03-polish-chapter.md`)
- `Edited` → ต้อง Finalize (`prompts/06-finalize-chapter.md`)
- `Final` → ตอนนี้เสร็จแล้ว ข้ามไป
- ถ้าไม่มีตอนค้าง → เริ่มแปลตอนถัดไปตาม batch plan

จาก `batch-plan.md`:

- ถ้า `Next check due` ครบแล้ว → ทำ consistency check ก่อน (`prompts/05-consistency-range.md`)
- ถ้ายังไม่ครบ → แปลต่อตามปกติ

**Gate บังคับก่อนแปลตอนใหม่** — รัน:

```powershell
powershell -File etc/check-consistency-due.ps1
```

ถ้า exit ≠ 0 (มี consistency check ค้าง) → ห้ามแปลตอนใหม่ ให้ทำ consistency ที่ค้างก่อน

### 3. อ่าน OKF ใหม่

ก่อนทำงานต่อ ให้อ่าน OKF ทั้งหมดตาม `prompts/00-master-instructions.md` เพราะ OKF อาจถูกอัปเดตใน session ก่อน

### 4. รายงานสถานะ

หลังอ่านสถานะเสร็จ สรุปให้ผู้ใช้ก่อนเริ่มงาน:

- Batch ปัจจุบัน
- ตอนที่เสร็จแล้ว / ค้างอยู่
- งานที่จะทำต่อ (ระบุตอนและขั้นตอน)
- Consistency check ครั้งล่าสุดและครั้งถัดไป
- รายการ human-review-needed ที่ค้าง (ถ้ามี)
