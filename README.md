# {NOVEL_NAME} — Thai Translation Workspace

พื้นที่สำหรับแปล {NOVEL_NAME} เป็นภาษาไทย

## AI Start Here

ถ้าใช้กับ AI ให้เริ่มจากไฟล์นี้ก่อน แล้วอ่านต่อเรียงตามนี้:

1. `WORKFLOW.md`
2. `prompts/00-master-instructions.md`
3. ถ้า OKF ยังว่างเปล่า → ใช้ `prompts/08-bootstrap-okf.md` สร้าง OKF จาก source ก่อน (ถ้าแปลต่อจากงานเก่าที่มี OKF แล้ว → ใช้ `prompts/09-import-okf.md` แทน)
4. `okf/index.md`
5. `okf/source-map.md`
6. ไฟล์ OKF ที่เกี่ยวกับงาน เช่น `terms.md`, `characters.md`, `factions.md`, `places.md`, `techniques.md`, `artifacts.md`, `title-registry.md`, `voice-register.md`, `human-review-needed.md`

## Source หลัก

- English รายตอน: `sources/eng_clean_chapter/`
- ต้นฉบับดิบบางตอน เกาหลี/อื่นๆ (ถ้ามี): `sources/raw_chapter/`
- English full (fallback continuity): `sources/full_text.txt`

กฎหลักคือให้ยึด `sources/eng_clean_chapter` เป็นต้นฉบับหลัก, ใช้ `sources/raw_chapter` (ต้นฉบับดิบภาษาต้นทาง) ตรวจชื่อและนัยภาษาเมื่อมีไฟล์ตรงตอน, และใช้ `sources/full_text.txt` เป็น fallback ด้าน continuity เท่านั้น

โฟลเดอร์ `sources/` เก็บสำเนาต้นฉบับไว้ในโปรเจกต์ จึงสามารถคัดลอกทั้งโฟลเดอร์โปรเจกต์ไปทำงานที่เครื่องอื่นได้โดยไม่ต้องพึ่ง path ภายนอก

## Folder Structure

| Folder | Purpose |
|---|---|
| `okf/` | ฐานองค์ความรู้กลาง (OKF) — ศัพท์, ตัวละคร, สำนัก, สถานที่, เทคนิค, นโยบายแปล |
| `prompts/` | ชุดคำสั่งมาตรฐานสำหรับ AI |
| `sources/eng_clean_chapter/` | ต้นฉบับภาษาอังกฤษรายตอน |
| `sources/raw_chapter/` | ต้นฉบับดิบภาษาต้นทาง เกาหลี/อื่นๆ (ถ้ามี) |
| `sources/full_text.txt` | ต้นฉบับรวมเล่ม สำหรับตรวจ continuity |
| `thai_draft/` | ร่างแปลรอบแรก |
| `thai_edited/` | ฉบับเกลาหลัง QA |
| `thai_final/` | ฉบับพร้อมใช้ |
| `qa/` | งานตรวจคุณภาพ + รายงาน |
| `reports/` | รายงานภาพรวม (consistency, glossary drift, batch plan) |
| `logs/` | บันทึกการตัดสินใจและสถานะ |
| `exports/` | ไฟล์ export รวมตอน |
| `workspace/` | พื้นที่ทำงานชั่วคราว |
| `etc/` | เครื่องมือประกอบ เช่น `term-extract.ps1` |

## Workflow แนะนำ

0. **(โปรเจกต์ใหม่)** ใช้ `prompts/08-bootstrap-okf.md` สร้าง OKF จาก source อัตโนมัติ — **(แปลต่อจากงานเก่า)** ใช้ `prompts/09-import-okf.md` ดึง OKF เดิมมาแทน เพื่อให้คำแปลตรงกัน
1. อ่าน `prompts/00-master-instructions.md`
2. ใช้ `prompts/01-translate-chapter.md` แปลรายตอน
3. ใช้ `prompts/02-qa-chapter.md` ตรวจเทียบต้นฉบับ
4. ใช้ `prompts/03-polish-chapter.md` เกลาสำนวน
5. ใช้ `prompts/06-finalize-chapter.md` ทำฉบับสุดท้าย
6. ใช้ `prompts/05-consistency-range.md` ทุก 5-10 ตอน
7. ถ้าเจอศัพท์ใหม่ ใช้ `prompts/04-update-okf.md`
8. ถ้า session หลุด ใช้ `prompts/07-resume-session.md` กลับมาทำต่อ

## กฎสำคัญ

- ห้ามแปลโดยไม่อ้าง OKF
- ห้ามเปลี่ยนศัพท์เฉพาะเองถ้า OKF กำหนดแล้ว
- ห้ามปล่อยเศษอังกฤษ เกาหลี จีน markup หรือ note หลุดในบทแปล
- ห้ามสลับพี่/น้อง พ่อ/ลูก อาจารย์/ศิษย์
- ห้ามเพิ่มเนื้อหาใหม่หรืออธิบายแทรกในเนื้อเรื่อง
