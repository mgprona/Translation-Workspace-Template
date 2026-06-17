# Prompt: QA Chapter

ตรวจ QA บทแปลตอนที่ `{CHAPTER_NUMBER}`

## Files

ต้นฉบับ:

`sources/eng_clean_chapter/ch{CHAPTER_NUMBER}.txt`

ต้นฉบับดิบภาษาต้นทาง เกาหลี/อื่นๆ ถ้ามี:

`sources/raw_chapter/ch{CHAPTER_NUMBER}.txt`

บทแปล:

`thai_draft/ch{CHAPTER_NUMBER}.md`

OKF:

`okf/`

## ⛔ Gate ก่อนเริ่ม (บังคับ — กัน phantom chapter)

ก่อนตรวจ QA **ต้องรัน** verify-chapter เพื่อยืนยันว่าร่างแปลมีอยู่จริง:

```powershell
powershell -File etc/verify-chapter.ps1 -Chapter {CHAPTER_NUMBER} -Stage draft
```

- ถ้า exit code = 0 (`[PASS]`) → ทำ QA ต่อได้
- ถ้า exit code ≠ 0 (`[FAIL]`) → **ห้ามเขียน QA report, ห้ามแตะ chapter-status.md** ให้รายงานผู้ใช้ว่า "ตอน {CHAPTER_NUMBER} ยังไม่มีร่างแปล (`thai_draft/ch{CHAPTER_NUMBER}.md`) — ต้องแปลก่อน" แล้วหยุด

> เหตุผล: จากงานจริง โมเดลเคยสร้าง QA report ให้ตอนที่ไม่เคยแปล (ไฟล์ไม่มีจริง) ทำให้สถานะโกหกว่าตอนเสร็จแล้ว ตอนนั้นจึงหายไปจากนิยายเงียบๆ — gate นี้กันไม่ให้เกิดอีก

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
    powershell -File etc/term-extract.ps1 -TargetPath thai_draft/ch{CHAPTER_NUMBER}.md -OkfPath okf -FailOnIssue
    ```
    ตรวจสอบรายงาน `term-extract-report.md` ถ้ามี issue ระดับ CJK/Hangul/Markup/**EnglishGloss** (วงเล็บกำกับศัพท์อังกฤษ เช่น `(Three Seals)`) ให้แจ้งใน QA report เป็น major — ถ้าสคริปต์ exit ≠ 0 ตอนนี้ต้องได้ verdict อย่างน้อย "Needs revision"

## Output report

เขียนรายงานที่:

`qa/reports/ch{CHAPTER_NUMBER}-qa.md`

รูปแบบรายงาน:

| Severity | Location | Original/Thai issue | Recommendation |
|---|---|---|---|

**กฎกัน QA ตรายาง (rubber-stamp)** — จากงานจริง โมเดลชอบออก "Pass-minor" ทุกตอนโดยไม่ได้ตรวจจริง:

- คอลัมน์ `Location` ต้องอ้าง **เลขบรรทัด/ย่อหน้าจริง** ในไฟล์ร่าง (เช่น `L37`, `ย่อหน้า 12`) ห้ามใส่ `-` หรือ "Terminology" ลอยๆ
- ต้องมีหลักฐานว่าได้ตรวจจริงอย่างน้อย: อ้างถึงเหตุการณ์/ตัวละครจริงในตอนนี้ 1 ประโยค (กันการ generate รายงานโดยไม่อ่าน)
- **ห้ามตาราง issue ว่างเปล่าแล้วตัดสิน "Pass with minor fixes"** (ขัดแย้งในตัวเอง) — ถ้าไม่มี issue เลย verdict ต้องเป็น "Pass" เท่านั้น

Severity ใช้:

- critical
- major
- minor

ท้ายรายงานให้มีคำตัดสิน:

- Pass — ไม่มี issue ในตาราง (ตารางต้องว่าง)
- Pass with minor fixes — มีเฉพาะ issue ระดับ minor (ตารางต้องมีอย่างน้อย 1 แถว)
- Needs revision
- Re-translate required

## อัปเดตสถานะ

หลังเขียนรายงานแล้ว ให้อัปเดตสถานะ **ผ่านสคริปต์** (สคริปต์ตรวจว่ารายงาน QA มีจริงก่อนเขียน + ลง timestamp จริง):

```powershell
powershell -File etc/set-status.ps1 -Chapter {CHAPTER_NUMBER} -Stage qa -Verdict <VERDICT>
```

โดย `<VERDICT>` map ตามตารางล่าง (ใช้ค่าฝั่งขวาเป็น argument):

| Verdict ในรายงาน | -Verdict argument | Status ที่ตั้ง |
|---|---|---|
| Pass | `Pass` | `QA: Pass` |
| Pass with minor fixes | `Pass-minor` | `QA: Pass-minor` |
| Needs revision | `Needs-revision` | `QA: Needs-revision` |
| Re-translate required | `Re-translate` | `QA: Re-translate` |

