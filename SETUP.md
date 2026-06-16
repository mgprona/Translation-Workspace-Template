# Setup Guide — เริ่มโปรเจกต์ใหม่จาก Template

## ขั้นตอน

### 1. คัดลอก Template

คัดลอกโฟลเดอร์ `Translation-Workspace-Template` ทั้งหมดแล้วเปลี่ยนชื่อเป็นชื่อนวนิยาย

### 2. แทนที่ Placeholder

ค้นหาและแทนที่ text ต่อไปนี้ทุกไฟล์ในโปรเจกต์:

| Placeholder | แทนที่ด้วย | ตัวอย่าง |
|---|---|---|
| `{NOVEL_NAME}` | ชื่อนวนิยาย | Absolute Regression |
| `{DATE}` | วันที่เริ่มโปรเจกต์ | 2026-06-16 |

ไฟล์ที่มี Placeholder:

- `README.md` — `{NOVEL_NAME}`
- `WORKFLOW.md` — ไม่มี (generic แล้ว)
- `okf/index.md` — `{NOVEL_NAME}`, `{DATE}`
- `okf/*.md` (ทุกไฟล์ OKF) — `{DATE}` ใน frontmatter
- `prompts/00-master-instructions.md` — `{NOVEL_NAME}`

### 3. ใส่ Source Files

- วางไฟล์ต้นฉบับอังกฤษรายตอนที่ `sources/eng_clean_chapter/`
  - ตั้งชื่อ `ch001.txt`, `ch002.txt`, ...
- วางไฟล์ต้นฉบับเกาหลีที่ `sources/raw_chapter/` (ถ้ามี)
  - ตั้งชื่อ `ch001.txt`, `ch002.txt`, ...
- วางไฟล์ full text ที่ `sources/full_text.txt` (ถ้ามี เป็น fallback continuity)

### 4. Bootstrap OKF

ใช้ `prompts/08-bootstrap-okf.md` — AI จะอ่าน 5 ตอนแรกแล้วสร้าง OKF ให้อัตโนมัติ:

- `okf/terms.md` — ศัพท์สำคัญ
- `okf/characters.md` — ตัวละคร
- `okf/factions.md` — สำนัก/ฝ่าย
- `okf/places.md` — สถานที่
- `okf/techniques.md` — วิชา/ทักษะ
- `okf/artifacts.md` — วัตถุ/สมบัติ
- `okf/voice-register.md` — น้ำเสียงตัวละคร
- `okf/chapter-registry.md` — รายชื่อบท
- `okf/source-map.md` — จำนวน source files

OKF จะเติบโตเรื่อยๆ ผ่าน `prompts/04-update-okf.md` ขณะแปล

### 5. Calibration Batch (10 ตอนแรก)

10 ตอนแรกเป็น Calibration — ตรวจเข้มข้นเป็นพิเศษเพื่อ:

- ล็อก voice register ของตัวละครหลัก
- ล็อกศัพท์เฉพาะใน OKF
- ทดสอบ tone และ style
- ปรับ quality-rules ถ้าจำเป็น

หลังจบ Calibration Batch ให้ทำ consistency check (`prompts/05-consistency-range.md`) ก่อนเริ่ม batch ถัดไป

### 6. ตั้ง Batch Plan

เปิด `reports/batch-plan.md` แล้วลง batch แรก:

| Batch | Chapters | Draft | QA | Edited | Final | Last consistency check | Next check due | Notes |
|---|---|---|---|---|---|---|---|---|
| 001 | ch001-010 | | | | | | 001-010 | Calibration batch |

### 7. เริ่มแปล

เปิด `WORKFLOW.md` แล้วทำตาม pipeline:

Prepare → Translate → QA → Polish → Finalize → Log → Consistency
