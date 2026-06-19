# {NOVEL_NAME} — Thai Translation Workspace

พื้นที่สำหรับแปล {NOVEL_NAME} เป็นภาษาไทย

## AI Start Here

ถ้าใช้กับ AI ให้เริ่มจากไฟล์นี้ก่อน แล้วอ่านต่อเรียงตามนี้:

1. `WORKFLOW.md`
2. `prompts/00-master-instructions.md`
3. ถ้า OKF ยังว่างเปล่า → ใช้ `prompts/08-bootstrap-okf.md` สร้าง OKF จาก source ก่อน (ถ้าแปลต่อจากงานเก่าที่มี OKF แล้ว → ใช้ `prompts/09-import-okf.md` แทน)
4. `okf/index.md`
5. `okf/source-map.md`
6. ไฟล์ OKF ที่เกี่ยวกับงาน เช่น `terms.md`, `characters.md`, `factions.md`, `places.md`, `techniques.md`, `artifacts.md`, `title-registry.md`, `voice-register.md`, `human-review-needed.md`, `arc-freeze-log.md`
7. `reports/batch-plan.md` — ดู arc ปัจจุบันและ Phase (A/B/C) เพื่อรู้ว่ากำลังทำเฟสไหน

## Source หลัก

template นี้เป็นกลางเรื่องภาษา — ต้นฉบับหลักจะเป็นภาษาอะไรก็ได้ (เกาหลี/อังกฤษ/จีน/ฯลฯ) ภาษาหลักตั้งตอน setup และบันทึกใน `okf/source-map.md`

- ต้นฉบับหลักรายตอน (ยึดแปล): `sources/primary_chapter/`
- source อ้างอิงรองรายตอน (อีกภาษาหนึ่ง ถ้ามี ไว้ตรวจชื่อ/นัย): `sources/reference_chapter/`

กฎหลักคือให้ยึด `sources/primary_chapter` เป็นต้นฉบับหลัก และใช้ `sources/reference_chapter` (อีกภาษาหนึ่ง) ตรวจชื่อและนัยภาษาเมื่อมีไฟล์ตรงตอน

โฟลเดอร์ `sources/` เก็บสำเนาต้นฉบับไว้ในโปรเจกต์ จึงสามารถคัดลอกทั้งโฟลเดอร์โปรเจกต์ไปทำงานที่เครื่องอื่นได้โดยไม่ต้องพึ่ง path ภายนอก

## Folder Structure

| Folder | Purpose |
|---|---|
| `okf/` | ฐานองค์ความรู้กลาง (OKF) — ศัพท์, ตัวละคร, สำนัก, สถานที่, เทคนิค, นโยบายแปล |
| `prompts/` | ชุดคำสั่งมาตรฐานสำหรับ AI |
| `sources/primary_chapter/` | ต้นฉบับหลักรายตอน (ยึดแปล — ภาษาอะไรก็ได้) |
| `sources/reference_chapter/` | source อ้างอิงรองรายตอน อีกภาษาหนึ่ง (ถ้ามี) |
| `thai_draft/` | ร่างแปลรอบแรก |
| `thai_edited/` | ฉบับเกลาหลัง QA |
| `thai_final/` | ฉบับพร้อมใช้ |
| `qa/` | งานตรวจคุณภาพ + รายงาน |
| `reports/` | รายงานภาพรวม (consistency, glossary drift, **arc plan**) |
| `logs/` | บันทึกการตัดสินใจ สถานะ และ translation notes รายตอน (chapter-status + คอลัมน์ Arc, `chNNN-notes.md`) |
| `exports/` | ไฟล์ export รวมตอน |
| `workspace/` | พื้นที่ทำงานชั่วคราว |
| `etc/` | เครื่องมือประกอบ: `next-task`, `complete-stage`, `verify-pipeline`, `term-extract`, `verify-chapter`, `verify-notes`, `verify-okf`, `set-status`, `status-arc`, `check-encoding`, `check-arc-phase`, `audit-workspace`, `replace-term`, `verify-sources` (.ps1) |

## Workflow แนะนำ (Arc-based — ทำงานเป็นก้อน ≈30 ตอน/เล่ม)

ดูรายละเอียดเต็มใน `WORKFLOW.md` — สรุป:

0. **(โปรเจกต์ใหม่)** `prompts/08-bootstrap-okf.md` สร้าง OKF + เสนอขอบเขต arc 1 — **(แปลต่อ)** `prompts/09-import-okf.md`
1. อ่าน `prompts/00-master-instructions.md`
2. **Phase A** (draft+QA รายตอนทั้ง arc): `01-translate-chapter.md` → `02-qa-chapter.md` ไล่จนครบ arc
3. จบ Phase A → `05-consistency-range.md` (ทั้ง arc) → `verify-okf.ps1` → **OKF freeze** (`okf/arc-freeze-log.md`)
4. **Phase B** (เกลาทั้ง arc): `03-polish-chapter.md` — gate `etc/check-arc-phase.ps1 -Arc N -Phase B`
5. **Phase C** (final ทั้ง arc): `06-finalize-chapter.md` — gate `-Phase C` → ส่งมอบเล่ม → arc ถัดไป
6. ถ้าเจอศัพท์ใหม่ระหว่างทาง: `prompts/04-update-okf.md`
7. ถ้า session หลุด: `prompts/07-resume-session.md` (รู้ arc/phase ปัจจุบันแล้วทำต่อ)

## Command Layer

ให้ AI ใช้คำสั่งกลางก่อน/หลังงานเสมอ:

- หางานถัดไป: `powershell -File etc/next-task.ps1`
- ปิด stage หลังสร้างไฟล์: `powershell -File etc/complete-stage.ps1 ...`
- ตรวจทั้ง arc: `powershell -File etc/verify-pipeline.ps1 -Arc N -Target phase-b-ready|ship`

`set-status.ps1` ยังใช้ได้ แต่ถือเป็น internal gate; prompt หลักควรเรียก `complete-stage.ps1` เพื่อไม่ให้โมเดลลืม audit/title/OKF gate ย่อย

## กฎสำคัญ

- ห้ามแปลโดยไม่อ้าง OKF
- ห้ามเปลี่ยนศัพท์เฉพาะเองถ้า OKF กำหนดแล้ว
- ห้ามปล่อยเศษอังกฤษ เกาหลี จีน markup หรือ note หลุดในบทแปล (รวมวงเล็บกำกับอังกฤษ เช่น `(Three Seals)`)
- ห้ามสลับพี่/น้อง พ่อ/ลูก อาจารย์/ศิษย์
- ห้ามเพิ่มเนื้อหาใหม่หรืออธิบายแทรกในเนื้อเรื่อง
- ห้ามสร้าง/รันสคริปต์ที่เขียนทับไฟล์ `thai_*` ด้วย find-replace อัตโนมัติ (ทำไฟล์พังด้วย encoding เพี้ยน)
- ห้ามรายงานว่าตอนเสร็จ stage ใดถ้าไฟล์ไม่มีจริง — ใช้ `etc/verify-chapter.ps1` + `etc/set-status.ps1` เป็นด่านบังคับ
- ห้ามข้าม translation notes — `etc/set-status.ps1 -Stage draft` จะเรียก `verify-notes.ps1` และบล็อก notes ที่หาย/ลวก/None ทุกช่อง
- ก่อน freeze/เข้า Phase B ต้องให้ `etc/verify-okf.ps1 -Start N -End M -CheckAllFiles -RequireRangeMetadata` ผ่าน เพื่อกัน OKF 16 ไฟล์อัปเดตไม่ครบ
- หลังทำหลายตอนหรือก่อนเปลี่ยนเฟส ให้รัน `etc/audit-workspace.ps1 -Start N -End M -CheckText` เพื่อจับ phantom chapter, QA report ที่ไม่มีหลักฐานจริง, และเศษภาษา/markup ที่หลุดถึงไฟล์บทแปล
