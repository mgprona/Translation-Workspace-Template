# Translation Workflow (Arc-based)

หน่วยงานของโปรเจกต์นี้คือ **arc** (≈ 30 ตอน ≈ หนึ่งเล่ม) แต่ละ arc เดิน 3 เฟส แล้วส่งมอบ:

```
ARC N (≈30 ตอน — ขอบเขต AI เสนอ + คนยืนยัน)
├─ Phase A: Draft + QA รายตอน (loop ไปจนครบทั้ง arc) + OKF/logs โตไปด้วย
│   └─ gate A→B: ทุกตอน QA ผ่าน + consistency ระดับ arc + OKF freeze
├─ Phase B: Edit ทั้ง arc (เกลาทีละตอนด้วย OKF ที่ freeze แล้ว)
│   └─ gate B→C: ทุกตอน Edited
├─ Phase C: Final ทั้ง arc
│   └─ gate ship: ทุกตอน Final → ส่งมอบเล่ม
└─ OKF ยกไป arc ถัดไป (one-term-one-form; แก้ย้อนได้ถ้ามีเหตุผล)
```

**ทำไมเป็น arc**: ให้ OKF อิ่มตัวก่อนเกลา — เกลาตอน OKF นิ่งแล้ว คำแปลไม่แกว่ง (drift) และได้ผลงานจับต้องได้ทุก ~30 ตอน

> **กัน context rot**: แต่ละเฟสอย่าทำรวด 30 ตอนใน session เดียว — แบ่งทีละ ~10 ตอน จากงานจริง พอ context ยาวโมเดลจะขี้เกียจ (notes ลวก, QA ตรายาง)

---

## 0. Bootstrap หรือ Import OKF (โปรเจกต์ใหม่เท่านั้น)

ถ้า OKF ยังว่างเปล่า เตรียมฐานข้อมูลก่อน:

- **เริ่มเรื่องใหม่** → `prompts/08-bootstrap-okf.md` (อ่าน 5 ตอนแรก → สกัด OKF → **เสนอขอบเขต arc 1**)
- **แปลต่อจากงานเก่า** → `prompts/09-import-okf.md` (ดึง OKF เดิม → เสนอ arc ที่จะแปลต่อ)

ตั้งขอบเขต arc 1 ใน `reports/batch-plan.md` (คนยืนยัน) ก่อนเริ่ม Phase A

---

## Phase A — Draft + QA รายตอน (ทั้ง arc)

ก่อนเริ่ม/หลัง resume ให้รัน:

```powershell
powershell -File etc/next-task.ps1
```

ทำตาม `[NEXT]` ที่สคริปต์บอก แล้วหลังสร้าง artifact ให้ใช้ `etc/complete-stage.ps1` เท่านั้น

ทำซ้ำต่อตอน จนครบทุกตอนใน arc:

### A.1 Prepare
อ่าน OKF ทั้งหมด (ดู `prompts/00-master-instructions.md`) + `logs/story-recap.md` ถ้าเปิด section ใหม่

### A.2 Translate (`prompts/01-translate-chapter.md`)
- source หลัก `sources/eng_clean_chapter/ch{NNN}.txt` (+ `sources/raw_chapter/ch{NNN}.txt` ถ้ามี)
- ร่างแรก → `thai_draft/ch{NNN}.md`
- เขียน `reports/ch{NNN}-translation-notes.md` (ห้าม "None" ลักไก่ — ดูกฎใน prompt 01)
- `powershell -File etc/complete-stage.ps1 -Chapter {NNN} -Stage draft -Arc {N}` — hard gate ตรวจ draft + notes + term scan + title registry

### A.3 QA (`prompts/02-qa-chapter.md`)
- gate: `verify-chapter.ps1 -Chapter {NNN} -Stage draft` ต้องผ่าน
- term scan: `term-extract.ps1 -TargetPath thai_draft/ch{NNN}.md -OkfPath okf -FailOnIssue -ReportOnly`
- เขียน `qa/reports/ch{NNN}-qa.md` (อ้าง line จริง — ดูกฎกัน rubber-stamp)
- `complete-stage.ps1 -Chapter {NNN} -Stage qa -Verdict <verdict>` — hard gate ตรวจ QA evidence + audit ตอนนั้น
- ถ้า Needs-revision → แก้ด้วย polish แล้ว QA ซ้ำ; Re-translate → แปลใหม่

### A.4 จบ Phase A → consistency + freeze
เมื่อทุกตอนใน arc ถึง `QA: Pass`/`Pass-minor`:
1. consistency ระดับ arc (`prompts/05-consistency-range.md` ช่วง = ทั้ง arc)
2. OKF coverage gate: `verify-okf.ps1 -Start {START} -End {END} -CheckAllFiles -RequireRangeMetadata`
3. ตัดสินศัพท์ค้างใน `human-review-needed.md` → **OKF freeze** (ลง `okf/arc-freeze-log.md`)
4. audit ทั้ง arc: `audit-workspace.ps1 -Start {START} -End {END} -CheckText`
5. gate รวม: `complete-stage.ps1 -Arc {N} -Stage phase-b-ready` ต้องผ่านก่อนเข้า Phase B

---

## Phase B — Edit ทั้ง arc (`prompts/03-polish-chapter.md`)

- gate เปิดเฟส: `check-arc-phase.ps1 -Arc {N} -Phase B`
- เกลาทีละตอนด้วย OKF ที่ freeze แล้ว → `thai_edited/ch{NNN}.md`
- โฟกัส: ลบ translation-ese, ยกระดับคำ, จังหวะ (ความถูกต้อง/OKF จัดการใน Phase A แล้ว)
- ถ้าต้องเปลี่ยนคำมาตรฐาน (freeze อ่อน) → `etc/replace-term.ps1` + บันทึก `arc-freeze-log.md`
- `complete-stage.ps1 -Chapter {NNN} -Stage edited`
- จบเมื่อทุกตอน `Edited` → gate `complete-stage.ps1 -Arc {N} -Stage phase-c-ready`

---

## Phase C — Final ทั้ง arc (`prompts/06-finalize-chapter.md`)

- gate เปิดเฟส: `check-arc-phase.ps1 -Arc {N} -Phase C`
- ตรวจ stage gate รายตอน (ดู prompt 06) → `thai_final/ch{NNN}.md`
- gate encoding: `check-encoding.ps1 -TargetPath thai_edited/ch{NNN}.md` ต้องผ่าน
- `complete-stage.ps1 -Chapter {NNN} -Stage final`
- จบเมื่อทุกตอน `Final` → `complete-stage.ps1 -Arc {N} -Stage ship` → **ส่งมอบเล่ม**

## Batch helper

ถ้าต้องตั้งสถานะหลายตอนหลังสร้างไฟล์ครบแล้ว ใช้:

```powershell
powershell -File etc/status-arc.ps1 -Start {START} -End {END} -Stage draft -Arc {N}
powershell -File etc/status-arc.ps1 -Start {START} -End {END} -Stage qa -Verdict Pass
```

ตัวช่วยนี้เรียก `set-status.ps1` ทีละตอนและหยุดทันทีเมื่อ gate fail จึงใช้ลดงานมือได้โดยไม่ลดความปลอดภัย

## Pipeline verifier

ก่อนส่งมอบหรือหลัง batch ใหญ่ ใช้:

```powershell
powershell -File etc/verify-pipeline.ps1 -Arc {N} -Target phase-b-ready
powershell -File etc/verify-pipeline.ps1 -Arc {N} -Target ship
```

สคริปต์นี้รวม audit + OKF gate + phase gate เพื่อจับช่องว่างที่โมเดลอาจมองข้าม

---

## Log (ทำตลอดทุกเฟส)

- ศัพท์ใหม่/แก้ OKF → `logs/translation-decisions.md`
- สถานะตอน → ผ่าน `etc/set-status.ps1` เท่านั้น (อย่าแก้ chapter-status.md ด้วยมือ)
- เหตุการณ์กระทบตอนถัดไป (ตัวละครตาย/ปมใหม่) → `logs/story-recap.md` (เขียนทับ กระชับ)

## ส่งมอบ arc → เริ่ม arc ถัดไป

หลัง ship: เสนอขอบเขต arc ถัดไป → คนยืนยัน → ลง `batch-plan.md` (Phase=A) → กลับไป Phase A

## สถานะตอน (vocabulary)

ดูนิยามเต็มใน `logs/chapter-status.md`: `Draft` → `QA: Pass`/`Pass-minor`/`Needs-revision`/`Re-translate` → `Edited` → `Final`

หมายเหตุ: ตอนหนึ่งอาจค้างที่ `QA: Pass` จนกว่าทั้ง arc จะ draft ครบแล้วเข้า Phase B พร้อมกัน — เป็นพฤติกรรมปกติของ arc model

## หมายเหตุ: ไฟล์ที่ชื่อคล้ายกัน

- `logs/chapter-status.md` — สถานะ production รายตอน (Draft/QA/Edited/Final) + คอลัมน์ Arc
- `reports/batch-plan.md` — แผนระดับ arc + Phase (A/B/C/Shipped)
- `okf/chapter-registry.md` — metadata ของ source (ชื่อบท, coverage)
- `okf/arc-freeze-log.md` — บันทึก OKF freeze รายอาร์ค + การแก้ย้อน
