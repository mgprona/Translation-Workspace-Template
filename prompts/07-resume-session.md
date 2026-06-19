# Prompt: Resume Session

กลับมาทำงานต่อจาก session ก่อนหน้า

## ขั้นตอน

### 1. ตรวจสถานะ

ก่อนตีความไฟล์เอง ให้รันตัวบอกงานถัดไป:

```powershell
powershell -File etc/next-task.ps1
```

ผลลัพธ์ `[NEXT]` คือคำสั่งนำทางหลักของ session นี้ ถ้าสคริปต์ fail ให้แก้ไฟล์สถานะ/arc plan ก่อน ห้ามเดาเอง

อ่านไฟล์สถานะเหล่านี้ก่อน:

- `logs/story-recap.md` — เนื้อเรื่องดำเนินมาถึงไหน (สถานการณ์ปัจจุบัน ปมค้าง ความสัมพันธ์ที่เปลี่ยน) เพื่อจับเรื่องต่อโดยไม่ต้องอ่านบทแปลเก่าทั้งหมด
- `reports/batch-plan.md` — **ดู arc ปัจจุบันและ Phase (A/B/C)** ของมัน + ช่วงตอนของ arc
- `logs/chapter-status.md` — ดูว่าตอนไหนใน arc ค้างที่ขั้นไหน (Draft/QA/Edited/Final) + คอลัมน์ Arc
- `okf/arc-freeze-log.md` — arc ปัจจุบัน freeze OKF แล้วหรือยัง
- `okf/human-review-needed.md` — ดูว่ามีรายการค้างที่ต้องตัดสินใจไหม

### 2. ระบุงานที่ต้องทำต่อ (ตาม Phase ของ arc ปัจจุบัน)

ใช้ผลจาก `etc/next-task.ps1` เป็นตัวตัดสินก่อนเสมอ รายการด้านล่างเป็นคำอธิบาย logic ของสคริปต์ ไม่ใช่ให้โมเดลเลือกเองถ้าสคริปต์ให้คำตอบแล้ว

ดู Phase ของ arc ปัจจุบันจาก `batch-plan.md` แล้วทำตามนั้น:

#### ถ้าอยู่ Phase A (Draft + QA รายตอน)

ไล่ดูตอนในช่วง arc จาก `chapter-status.md`:

- `Draft` → ต้อง QA (`prompts/02-qa-chapter.md`)
- `QA: Needs-revision` → ต้อง Polish เพื่อแก้ แล้ว QA ซ้ำ (`prompts/03-polish-chapter.md`)
- `QA: Re-translate` → ต้องแปลใหม่ (`prompts/01-translate-chapter.md`)
- ตอนที่ยังไม่มีแถว → แปลตอนถัดไป (`prompts/01-translate-chapter.md`)
- ตอน `QA: Pass` / `QA: Pass-minor` → **ปล่อยไว้ก่อน** (รอทั้ง arc ครบ — อย่าเพิ่งเกลา)
- **เมื่อทุกตอนใน arc ถึง `QA: Pass`/`Pass-minor`** → ทำ consistency ระดับ arc (`prompts/05-consistency-range.md` ช่วง = ทั้ง arc) → OKF freeze → เข้า Phase B

#### ถ้าอยู่ Phase B (เกลาทั้ง arc)

ก่อนเริ่ม: `powershell -File etc/check-arc-phase.ps1 -Arc {N} -Phase B` ต้องผ่าน

- ตอนที่ยัง `QA: Pass`/`Pass-minor` → Polish (`prompts/03-polish-chapter.md`)
- เกลาไล่จนทุกตอน `Edited` → เข้า Phase C

#### ถ้าอยู่ Phase C (final ทั้ง arc)

ก่อนเริ่ม: `powershell -File etc/check-arc-phase.ps1 -Arc {N} -Phase C` ต้องผ่าน

- ตอนที่ยัง `Edited` → Finalize (`prompts/06-finalize-chapter.md`)
- เมื่อทุกตอน `Final` → `check-arc-phase -Arc {N} -Phase ship` → ส่งมอบ arc → เริ่ม arc ถัดไป (เสนอขอบเขต arc ใหม่ → คนยืนยัน → ลง batch-plan → กลับไป Phase A)

> **กัน context rot**: ไม่ว่าเฟสไหน อย่าทำรวด 30 ตอนใน session เดียว — แบ่งทีละ ~10 ตอน

### 3. อ่าน OKF ใหม่

ก่อนทำงานต่อ ให้อ่าน OKF ทั้งหมดตาม `prompts/00-master-instructions.md` เพราะ OKF อาจถูกอัปเดตใน session ก่อน

### 4. รายงานสถานะ

หลังอ่านสถานะเสร็จ สรุปให้ผู้ใช้ก่อนเริ่มงาน:

- Arc ปัจจุบัน + Phase (A/B/C) + ช่วงตอนของ arc
- ตอนที่เสร็จแล้ว / ค้างอยู่ ใน arc นี้
- งานที่จะทำต่อ (ระบุตอนและขั้นตอน)
- OKF freeze ของ arc นี้ทำแล้วหรือยัง
- รายการ human-review-needed ที่ค้าง (ถ้ามี)
