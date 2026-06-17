# Setup Guide — เริ่มโปรเจกต์ใหม่จาก Template

## ขั้นตอน

### 1. คัดลอก Template

คัดลอกโฟลเดอร์ `Translation-Workspace-Template` ทั้งหมดแล้วเปลี่ยนชื่อเป็นชื่อนวนิยาย

**สำคัญ — รันทันทีหลังคัดลอก** เพื่อกันสคริปต์พังบน PowerShell 5.1 (บางครั้ง copy/clone ทำให้ไฟล์ `.ps1` หาย BOM ทำให้อ่านภาษาไทยในสคริปต์ผิด):

```powershell
powershell -File etc/ensure-bom.ps1
```

ถ้าขึ้น `[FIXED]` แสดงว่ามีไฟล์ BOM หายและถูกซ่อมแล้ว; `[PASS]` = ปกติดี

### 2. แทนที่ Placeholder

ค้นหาและแทนที่ text ต่อไปนี้ทุกไฟล์ในโปรเจกต์:

| Placeholder | แทนที่ด้วย | ตัวอย่าง |
|---|---|---|
| `{NOVEL_NAME}` | ชื่อนวนิยาย | Absolute Regression |
| `{DATE}` | วันที่เริ่มโปรเจกต์ | 2026-06-16 |

แทนทีละไฟล์มือก็ได้ แต่มีหลายไฟล์จึงลืมง่าย — แทนทั้งโปรเจกต์ทีเดียวด้วย PowerShell (ปรับค่า 2 บรรทัดแรก):

```powershell
$novel = "ชื่อนิยายของคุณ"; $date = "2026-06-16"
Get-ChildItem -Recurse -Include *.md | Where-Object { $_.FullName -notmatch '[\\/](\.git|prompts)[\\/]' -and $_.Name -ne 'SETUP.md' } | ForEach-Object {
  (Get-Content $_.FullName -Raw -Encoding UTF8) -replace '\{NOVEL_NAME\}', $novel -replace '\{DATE\}', $date | Set-Content $_.FullName -NoNewline -Encoding UTF8
}
powershell -File etc/check-placeholders.ps1   # ยืนยันว่าแทนครบ
```

(ข้าม `prompts/` และ `SETUP.md` เพราะมี placeholder เป็นตัวอย่างโดยตั้งใจ)

ไฟล์ที่มี Placeholder:

- `README.md` — `{NOVEL_NAME}`
- `WORKFLOW.md` — ไม่มี (generic แล้ว)
- `okf/index.md` — `{NOVEL_NAME}`, `{DATE}`
- `okf/*.md` (ทุกไฟล์ OKF) — `{DATE}` ใน frontmatter
- `prompts/00-master-instructions.md` — `{NOVEL_NAME}`

หลังแทนค่าแล้ว ตรวจว่าไม่มี placeholder ตกค้างด้วย:

```powershell
powershell -File etc/check-placeholders.ps1
```

ถ้าขึ้น `[PASS]` แสดงว่าแทนครบ; ถ้าขึ้น `[ISSUE]` ให้ไปแก้ไฟล์/บรรทัดที่ระบุ

### 3. ใส่ Source Files

- วางไฟล์ต้นฉบับอังกฤษรายตอนที่ `sources/eng_clean_chapter/`
  - ตั้งชื่อ `ch001.txt`, `ch002.txt`, ...
- วางไฟล์ต้นฉบับดิบภาษาต้นทาง เกาหลี/อื่นๆ ที่ `sources/raw_chapter/` (ถ้ามี)
  - ตั้งชื่อ `ch001.txt`, `ch002.txt`, ...
- วางไฟล์ full text ที่ `sources/full_text.txt` (ถ้ามี เป็น fallback continuity)

> **ถ้าโฟลเดอร์ source ของคุณชื่ออื่น** (เช่น `cleaned_novtales/`, `raw_korean/`) เลือกอย่างใดอย่างหนึ่ง:
> 1. **rename โฟลเดอร์/ไฟล์** ให้ตรงชื่อมาตรฐานข้างบน (แนะนำ — prompt ทุกตัวชี้ชื่อนี้) หรือ
> 2. **แก้ path** ใน `okf/source-map.md` + `okf/index.md` + prompts ที่อ้าง path ให้ตรงของจริง
>
> ถ้าชื่อไม่ตรงและไม่แก้ AI จะหา source ไม่เจอทั้งโปรเจกต์ — ตรวจด้วยการลองเปิด `sources/eng_clean_chapter/ch001.txt` ว่ามีจริง

หลังวาง source แล้ว ตรวจว่าพร้อมและชื่อโฟลเดอร์ตรงมาตรฐาน:

```powershell
powershell -File etc/verify-sources.ps1
```

ถ้าขึ้น `[PASS]` แสดงว่า source พร้อม; ถ้า `[FAIL]` ให้แก้ตามที่ระบุ (มักเป็นโฟลเดอร์ชื่อไม่ตรง — สคริปต์จะชี้ให้ว่าเจอโฟลเดอร์ไหนที่น่าจะเป็น source)

### 4. Bootstrap หรือ Import OKF

**กรณีเริ่มเรื่องใหม่** — ใช้ `prompts/08-bootstrap-okf.md` AI จะอ่าน 5 ตอนแรกแล้วสร้าง OKF ให้อัตโนมัติ:

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

**กรณีแปลต่อจากงานเก่า** (เคยแปลเรื่องนี้มาแล้วบางส่วน มี OKF หรือบทแปลเดิม) — ใช้ `prompts/09-import-okf.md` แทน เพื่อดึงคำแปลเดิมมาเป็นมาตรฐาน ไม่ให้คำแปลใหม่แกว่งจากของเก่า

### 5. Calibration (ช่วงต้น arc 1)

~10 ตอนแรกของ arc 1 เป็นช่วง Calibration — ตรวจเข้มข้นเป็นพิเศษเพื่อ:

- ล็อก voice register ของตัวละครหลัก
- ล็อกศัพท์เฉพาะใน OKF
- ทดสอบ tone และ style
- ปรับ quality-rules ถ้าจำเป็น

Calibration อยู่ใน Phase A ของ arc 1 (draft+QA รายตอน) — ทำต่อจนครบ arc แล้วจึง consistency + freeze ก่อนเข้า Phase B

### 6. ตั้ง Arc Plan

เปิด `reports/batch-plan.md` แล้วลง arc แรก (AI เสนอขอบเขตตอน bootstrap → คุณยืนยัน เป้า ~30 ตอน ตัดที่รอยต่อเนื้อเรื่อง):

| Arc | Chapters | Phase | A: Draft+QA | B: Edit | C: Final | OKF freeze | Consistency | Notes |
|---:|---|---|---|---|---|---|---|---|
| 1 | 1-30 | A | | | | | | arc แรก |

(ปรับ `1-30` ตามขอบเขตจริงที่ยืนยัน)

### 7. เริ่มแปล (Phase A ของ arc 1)

เปิด `WORKFLOW.md` แล้วทำตามเฟส:

Phase A (draft+QA รายตอนทั้ง arc) → consistency + OKF freeze → Phase B (เกลาทั้ง arc) → Phase C (final ทั้ง arc) → ส่งมอบเล่ม → arc ถัดไป
