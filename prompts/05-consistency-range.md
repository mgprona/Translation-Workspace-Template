# Prompt: Consistency Check Range

ตรวจ consistency ระหว่างตอน `{START}`-`{END}`

## Files

บทแปลอยู่ที่:

`thai_draft/`

หรือถ้าเกลาแล้ว:

`thai_edited/`

OKF:

`okf/`

## ตรวจ

- ชื่อคน
- ชื่อสำนัก/ฝ่าย
- ชื่อวิชา
- ชื่อวัตถุ
- คำเรียกตำแหน่ง
- สรรพนามและระดับภาษา
- ความสัมพันธ์ตัวละคร
- คำแปลที่แกว่งระหว่างตอน
- ชื่อบทไทยที่แกว่งหรือยังไม่ล็อกใน `title-registry.md`
- รายการที่ค้างใน `human-review-needed.md`
- เศษอังกฤษ เกาหลี จีน markup หรือ note
- **Term scan**: ถ้ามี `etc/term-extract.ps1` ให้รันครอบคลุมทุกตอนในช่วงนี้ — ชี้ไปที่ทั้งโฟลเดอร์:
  ```powershell
  powershell -File etc/term-extract.ps1 -TargetPath thai_edited -OkfPath okf -ReportOnly
  ```
  (ใช้ `thai_draft` ถ้ายังไม่เกลา; `-ReportOnly` เพื่อเขียนทับรายงานเดิม)

## Output

เขียนรายงานที่:

`reports/consistency-{START}-{END}.md`

รูปแบบ:

| Term/Issue | Found forms | OKF standard | Files to fix | Severity |
|---|---|---|---|---|

ท้ายรายงานให้สรุป:

- คำที่ต้องแก้ทันที
- คำที่ควรเพิ่ม OKF
- คำที่ควรส่งให้มนุษย์ตัดสินใน `human-review-needed.md`
- ไฟล์ที่ควรตรวจซ้ำ
- **ถ้าพบ drift มากกว่า 3 จุด → แนะนำให้ QA รอบ 2 ก่อนเปิด Batch ถัดไป**

## Checkpoint enforcement

หลังจากเขียนรายงานนี้แล้ว ให้อัปเดต `reports/batch-plan.md`:
- ตั้ง `Last consistency check` สำหรับ Batch นี้
- ตั้ง `Next check due` = `{CURRENT_END + 1}-{CURRENT_END + 10}`
- ตัวอย่าง: ถ้าตรวจ 001-010 → Next check due = 011-020
