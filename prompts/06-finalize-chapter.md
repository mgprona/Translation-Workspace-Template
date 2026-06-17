# Prompt: Finalize Chapter (Phase C — final ทั้ง arc)

ทำฉบับสุดท้ายตอนที่ `{CHAPTER_NUMBER}`

> **บริบท arc model**: prompt นี้คือ **Phase C** ทำ *หลัง* เกลา (Phase B) ครบทั้ง arc แล้ว (gate B→C ผ่าน) — finalize ทั้ง arc รวดทีละตอน จบแล้วส่งมอบทั้งเล่ม

## Input

ฉบับเกลา:

`thai_edited/ch{CHAPTER_NUMBER}.md`

รายงาน QA:

`qa/reports/ch{CHAPTER_NUMBER}-qa.md`

OKF:

`okf/`

## ⛔ Gate ก่อนเริ่ม (บังคับ)

**ก่อนเริ่ม Phase C ของ arc** (ทำครั้งเดียวตอนเปิดเฟส) — ตรวจว่าทั้ง arc เกลาครบ:

```powershell
powershell -File etc/check-arc-phase.ps1 -Arc {ARC_NUMBER} -Phase C
```

ถ้า `[FAIL]` → ยังมีตอนยังไม่ `Edited` → **ห้ามเริ่ม finalize** กลับไปทำ Phase B ให้ครบก่อน

**รายตอน** ก่อน finalize แต่ละตอน ต้องรัน verify-chapter ยืนยันว่าฉบับเกลามีอยู่จริง:

```powershell
powershell -File etc/verify-chapter.ps1 -Chapter {CHAPTER_NUMBER} -Stage edited
```

- ถ้า `[FAIL]` → **ห้ามสร้าง `thai_final/`** ให้รายงานว่าตอนนี้ยังไม่ผ่านขั้น Polish (ไม่มี `thai_edited/ch{CHAPTER_NUMBER}.md`) แล้วหยุด

## ตรวจสุดท้าย

- ไม่มี issue ระดับ critical หรือ major ค้างอยู่
- ชื่อตัวละครและศัพท์เฉพาะตรง OKF
- ไม่มี note หรือ markup หลุด
- ภาษาไทยอ่านลื่น
- ชื่อบทสะอาด ไม่มี source markup

## Stage gate checklist (ต้องผ่านทุกข้อก่อน Finalize)

- [ ] QA report verdict เป็น "Pass" หรือ "Pass with minor fixes" (ห้าม Finalize ถ้า Needs revision หรือ Re-translate)
- [ ] translation-decisions.md — มีบันทึกสำหรับตอนนี้หรือถ้าไม่มีศัพท์ใหม่ ให้ลงว่า "No new terms"
- [ ] human-review-needed.md — ถ้ามีรายการใหม่จากตอนนี้ ให้ confirmed ว่าถูกเพิ่มแล้ว; ถ้าไม่มี ตรวจว่าของเก่าไม่มี status ค้างเป็น `review-needed` โดยไม่มีความคืบหน้า
- [ ] term-extract scan — รัน `powershell -File etc/term-extract.ps1 -TargetPath thai_edited/ch{CHAPTER_NUMBER}.md -OkfPath okf -FailOnIssue -ReportOnly` แล้ว **exit code = 0** (ไม่มี issue ระดับ CJK/Hangul/Markup/EnglishGloss ค้าง) — ถ้า exit ≠ 0 ห้าม Finalize
- [ ] encoding scan — รัน `powershell -File etc/check-encoding.ps1 -TargetPath thai_edited/ch{CHAPTER_NUMBER}.md` แล้ว **exit code = 0** (ไม่มี mojibake) — ถ้า `[FAIL]` ห้าม Finalize ต้องกู้ไฟล์ก่อน
- [ ] chapter-status.md — สถานะปัจจุบันของตอนนี้ต้องเป็น `Edited` (ผ่าน Draft → QA → Edited มาครบ)
- [ ] Prose quality — อ่านย่อหน้าสุ่ม 3 จุด (ต้น กลาง ท้าย) แล้วประเมิน: ไม่มี translation-ese ค้าง, คำเลือกเหมาะกับ genre, จังหวะลื่น

## Output

บันทึกที่:

`thai_final/ch{CHAPTER_NUMBER}.md`

แล้วบันทึกสถานะ **ผ่านสคริปต์** (ตรวจว่าไฟล์ final มีจริงก่อนตั้ง Final — กันสถานะ Final ปลอม):

```powershell
powershell -File etc/set-status.ps1 -Chapter {CHAPTER_NUMBER} -Stage final
```

ถ้าตอนนี้มีเหตุการณ์/ความสัมพันธ์/ปมที่กระทบการแปลตอนถัดไป (ตัวละครตาย เพิ่งสนิท/แตกหัก ได้วิชาใหม่ ปมใหม่ที่จะถูก callback) ให้อัปเดต `logs/story-recap.md` ให้สะท้อนสถานะล่าสุด (เขียนทับ กระชับ ไม่สะสมประวัติ)
