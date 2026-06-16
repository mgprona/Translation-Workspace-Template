# Prompt: QA Chapter

ตรวจ QA บทแปลตอนที่ `{CHAPTER_NUMBER}`

## Files

ต้นฉบับ:

`sources/cleaned_novtales/ch{CHAPTER_NUMBER}.txt`

ไฟล์เกาหลี ถ้ามี:

`sources/raw_korean/ch{CHAPTER_NUMBER}.txt`

บทแปล:

`thai_draft/ch{CHAPTER_NUMBER}.md`

OKF:

`okf/`

## ตรวจสิ่งต่อไปนี้

1. แปลครบ ไม่มีข้ามย่อหน้า
2. ไม่มีความหมายผิด
3. ศัพท์เฉพาะตรงกับ OKF
4. ชื่อคน สำนัก วิชา วัตถุ คงเส้นคงวา
5. ไม่มีเศษอังกฤษ เกาหลี จีน markup หรือ note หลุด
6. น้ำเสียงตัวละครตรง `style-guide.md`
7. น้ำเสียงตัวละครตรง `voice-register.md`
8. ชื่อบทตรง `title-registry.md` ถ้าล็อกแล้ว
9. ภาษาไทยลื่น อ่านเป็นนวนิยาย
10. ไม่มีสลับพี่/น้อง หรือความสัมพันธ์ผิด
11. **Term extraction scan** — ถ้ามี `etc/term-extract.ps1` ให้รันก่อน:
    ```powershell
    powershell -File etc/term-extract.ps1 -TargetPath thai_draft/ch{CHAPTER_NUMBER}.md -OkfPath okf
    ```
    ตรวจสอบรายงาน `term-extract-report.md` ถ้ามี issue ระดับ CJK/Hangul/Markup ให้แจ้งใน QA report

## Output report

เขียนรายงานที่:

`qa/reports/ch{CHAPTER_NUMBER}-qa.md`

รูปแบบรายงาน:

| Severity | Location | Original/Thai issue | Recommendation |
|---|---|---|---|

Severity ใช้:

- critical
- major
- minor

ท้ายรายงานให้มีคำตัดสิน:

- Pass
- Pass with minor fixes
- Needs revision
- Re-translate required

