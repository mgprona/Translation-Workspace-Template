# Translation Workflow

## รอบการทำงานมาตรฐาน

### 0. Bootstrap OKF (โปรเจกต์ใหม่เท่านั้น)

ถ้า OKF ยังว่างเปล่า ให้สร้างฐานข้อมูลจาก source ก่อน:

ใช้ `prompts/08-bootstrap-okf.md` — อ่าน 5 ตอนแรก → สกัดตัวละคร ศัพท์ สำนัก สถานที่ วิชา → เติม OKF อัตโนมัติ

ถ้า OKF มีข้อมูลอยู่แล้ว (เช่น กลับมาทำต่อ) ให้ข้ามไปขั้น 1

### 1. Prepare

อ่าน OKF ก่อนทุกครั้ง:

- `okf/index.md`
- `okf/source-map.md`
- `okf/terms.md`
- `okf/characters.md`
- `okf/factions.md`
- `okf/places.md`
- `okf/techniques.md`
- `okf/artifacts.md`
- `okf/style-guide.md`
- `okf/voice-register.md`
- `okf/translation-policy.md`
- `okf/quality-rules.md`
- `okf/chapter-registry.md`
- `okf/title-registry.md`
- `okf/human-review-needed.md`

### 2. Translate

ใช้ source หลัก:

`sources/eng_clean_chapter/ch{NNN}.txt`

ถ้ามี Korean:

`sources/raw_chapter/ch{NNN}.txt`

ผลลัพธ์ร่างแรก:

`thai_draft/ch{NNN}.md`

หลังแปลเสร็จให้เขียน translation notes:

`reports/ch{NNN}-translation-notes.md` (ใช้ template จาก `reports/chNNN-translation-notes-template.md`)

### 3. QA

ตรวจเทียบกับต้นฉบับและ OKF แล้วเขียนรายงานที่:

`qa/reports/ch{NNN}-qa.md`

ถ้ามี `etc/term-extract.ps1` ให้รัน scan ก่อน:

```powershell
powershell -File etc/term-extract.ps1 -TargetPath thai_draft/ch{NNN}.md -OkfPath okf
```

### 4. Polish

เกลาสำนวนและแก้ความผิดตามรายงาน QA แล้วบันทึกที่:

`thai_edited/ch{NNN}.md`

### 5. Finalize

เมื่อผ่าน QA ซ้ำแล้ว ตรวจ stage gate checklist (ดู `prompts/06-finalize-chapter.md`) แล้วบันทึกเป็น:

`thai_final/ch{NNN}.md`

### 6. Log

ถ้ามีการตัดสินใจศัพท์ใหม่หรือแก้ OKF ให้บันทึกที่:

`logs/translation-decisions.md`

อัปเดตสถานะตอนที่:

`logs/chapter-status.md`

### 7. Consistency

ทุก 5-10 ตอน ให้ตรวจ consistency และเขียนรายงานที่:

`reports/consistency-{START}-{END}.md`

ถ้าพบคำที่ยังไม่มั่นใจ ให้เพิ่มใน:

`okf/human-review-needed.md`

หลังตรวจ ให้อัปเดต `reports/batch-plan.md`:

- ตั้ง `Last consistency check` สำหรับ Batch นี้
- ตั้ง `Next check due` สำหรับ Batch ถัดไป
- ถ้าพบ drift มากกว่า 3 จุด → QA รอบ 2 ก่อนเปิด Batch ถัดไป

## สถานะไฟล์

- **Draft**: แปลครบแต่ยังไม่ตรวจ
- **QA Required**: ต้องตรวจเทียบต้นฉบับ
- **Needs Revision**: มีจุดแก้
- **Edited**: เกลาแล้ว
- **Final**: ผ่าน QA และพร้อมใช้งาน
- **Review Needed**: มีศัพท์/ชื่อ/น้ำเสียงที่ต้องให้มนุษย์ยืนยัน

## หมายเหตุ: ไฟล์ที่ชื่อคล้ายกัน

- `logs/chapter-status.md` — ติดตาม **สถานะ production** (Draft/QA/Edited/Final)
- `okf/chapter-registry.md` — เก็บ **metadata ของ source** (ชื่อบทอังกฤษ/เกาหลี, coverage)

ทั้งสองไฟล์ต่างหน้าที่กัน ไม่ซ้ำซ้อน
