# Prompt: Finalize Chapter

ทำฉบับสุดท้ายตอนที่ `{CHAPTER_NUMBER}`

## Input

ฉบับเกลา:

`thai_edited/ch{CHAPTER_NUMBER}.md`

รายงาน QA:

`qa/reports/ch{CHAPTER_NUMBER}-qa.md`

OKF:

`okf/`

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
- [ ] term-extract scan — ถ้ามี `etc/term-extract.ps1` ให้รันล่าสุดแล้วไม่มี issue ระดับ CJK/Hangul/Markup ค้าง
- [ ] chapter-status.md — สถานะปัจจุบันของตอนนี้ต้องเป็น `Edited` (ผ่าน Draft → QA → Edited มาครบ)
- [ ] Prose quality — อ่านย่อหน้าสุ่ม 3 จุด (ต้น กลาง ท้าย) แล้วประเมิน: ไม่มี translation-ese ค้าง, คำเลือกเหมาะกับ genre, จังหวะลื่น

## Output

บันทึกที่:

`thai_final/ch{CHAPTER_NUMBER}.md`

แล้วบันทึกสถานะใน `logs/chapter-status.md`: ตั้ง `Status` = `Final`, เติมเซลล์ `Final` = path ฉบับสมบูรณ์ (`thai_final/chNNN.md`), อัปเดต `Updated`

ถ้าตอนนี้มีเหตุการณ์/ความสัมพันธ์/ปมที่กระทบการแปลตอนถัดไป (ตัวละครตาย เพิ่งสนิท/แตกหัก ได้วิชาใหม่ ปมใหม่ที่จะถูก callback) ให้อัปเดต `logs/story-recap.md` ให้สะท้อนสถานะล่าสุด (เขียนทับ กระชับ ไม่สะสมประวัติ)
