# Prompt: Translate Chapter (Phase A — draft ทั้ง arc)

แปลตอนที่ `{CHAPTER_NUMBER}` เป็นภาษาไทย

> **บริบท arc model**: prompt นี้คือ **Phase A** — draft + QA รายตอนไล่ไปจนครบทั้ง arc (≈30 ตอน) ก่อนจึงเข้า Phase B (เกลา) ระหว่าง Phase A ให้ OKF/logs โตไปด้วย ยัง**ไม่ต้องเกลาหรือ finalize** จนกว่าทั้ง arc จะ draft ครบ
>
> **กัน context rot**: อย่าอัด draft ทั้ง 30 ตอนในรอบเดียว — แบ่งทำทีละ ~10 ตอน/session เพราะจากงานจริง พอ context ยาวโมเดลจะเริ่มขี้เกียจ (ตอบ notes ลวกๆ)

## Source

Source หลัก (ต้นฉบับที่ยึดแปล — ภาษาตามที่ตั้งใน `okf/source-map.md`):

`sources/primary_chapter/ch{CHAPTER_NUMBER}.txt`

ถ้ามี source อ้างอิงรอง (อีกภาษาหนึ่ง ไว้ตรวจชื่อและนัย) ให้ใช้:

`sources/reference_chapter/ch{CHAPTER_NUMBER}.txt`

## OKF

ก่อนแปลให้อ่าน OKF:

`okf/`

โดยเฉพาะ:

- `terms.md`
- `characters.md`
- `factions.md`
- `places.md`
- `techniques.md`
- `artifacts.md`
- `style-guide.md`
- `voice-register.md`
- `translation-policy.md`
- `quality-rules.md`
- `title-registry.md`
- `human-review-needed.md`

ถ้าเป็นตอนแรกของ session/section ใหม่ ให้อ่าน `logs/story-recap.md` ด้วย เพื่อรู้ว่าเนื้อเรื่องดำเนินมาถึงไหน (กัน callback/สรรพนาม/ความสัมพันธ์ผิดตรงรอยต่อ)

## ข้อกำหนด

- แปลครบทุกย่อหน้า
- รักษาลำดับบทสนทนา
- **อ่าน "ปรัชญาการแปล" ใน `style-guide.md` ก่อนแปล** — เป้าคือ draft ที่**อ่านลื่นตั้งแต่แรก** (ไม่ใช่ร่างหยาบรอเกลา): แปลเอาความ ไม่แปลตรง ใช้ภาษาไทยที่คนเขียนจริง อ่านบนมือถือแล้วไม่สะดุด
- ใช้สำนวนไทยตาม genre profile ใน `style-guide.md` (tone, ระดับภาษา, คำต้องหลีก)
- คงบรรยากาศ/อรรถรสของแนวเดิม — แต่ห้ามทำให้หรูเกินต้นฉบับ และห้ามเพิ่มของที่ต้นฉบับไม่มี
- ใช้ศัพท์เฉพาะตาม OKF
- ใช้น้ำเสียงตัวละครตาม `voice-register.md`
- ถ้าชื่อบทมีคำแปลล็อกแล้ว ให้ใช้ตาม `title-registry.md`
- ถ้าต้นฉบับดิบมีอักษรจีน/Hanja ในวงเล็บหรือกำกับชื่อ ให้ตรวจเทียบก่อนถอดเสียงไทย และบันทึกใน notes ถ้ากระทบชื่อเฉพาะ
- ห้ามใส่วงเล็บอธิบายศัพท์ในเนื้อเรื่อง เว้นแต่ต้นฉบับมีจริง
- ห้ามแปลตรงแข็งแบบเครื่องมือแปล
- ห้ามเปลี่ยนความสัมพันธ์ตัวละคร เช่น พี่/น้อง พ่อ/ลูก อาจารย์/ศิษย์
- ห้ามปล่อยเศษอังกฤษ เกาหลี จีน markup หรือ note หลุด

## Output

ส่งออกเป็น Markdown ที่:

`thai_draft/ch{CHAPTER_NUMBER}.md`

## เขียน Translation Notes (บังคับ — ห้ามลักไก่)

เขียนไฟล์ `logs/ch{CHAPTER_NUMBER}-notes.md` (ใช้ template จาก `logs/chNNN-notes-template.md`)

**กฎกัน "None" ลักไก่** — จากงานจริง โมเดลชอบใส่ "None" ทุกช่องเพื่อตัดงาน ทั้งที่ตอนนั้นมีชื่อเฉพาะเพียบ:

- ก่อนเขียน ให้ไล่หา **proper noun / ชื่อเฉพาะ** ในต้นฉบับตอนนี้ก่อน (ชื่อคน สำนัก สถานที่ วิชา วัตถุ ตำแหน่ง)
- ทุกชื่อเฉพาะที่ปรากฏ ต้องลงอย่างใดอย่างหนึ่ง: ถ้ายังไม่มีใน OKF → "New ..."; ถ้ามีแล้ว → "Existing OKF Terms Used"
- **ห้ามใส่ "None" ในช่อง New Terms/Characters/Places พร้อมกันทุกช่อง** เว้นแต่ยืนยันแล้วว่าตอนนี้ไม่มีชื่อเฉพาะใหม่จริง (ตอนสั้นมากเท่านั้น) — ตอนความยาวปกติที่ตอบ "None" ทุกช่อง ถือว่ารายงาน **ไม่ผ่าน** ต้องทำใหม่
- ช่อง "Points of Uncertainty" ต้องมีอย่างน้อย 1 ข้อ หรือระบุชัดว่า "ตรวจแล้วไม่มีจุดคลุมเครือ" (ไม่ใช่แค่ "None" ลอยๆ)

## Gate และอัปเดตสถานะ

หลังบันทึกทั้งร่างและ translation notes แล้ว ให้อัปเดตสถานะ **ผ่านสคริปต์เท่านั้น**:

```powershell
powershell -File etc/complete-stage.ps1 -Chapter {CHAPTER_NUMBER} -Stage draft -Arc {ARC_NUMBER}
```

สคริปต์จะตรวจอัตโนมัติว่า:

- `thai_draft/ch{CHAPTER_NUMBER}.md` มีจริง
- `logs/ch{CHAPTER_NUMBER}-notes.md` มีจริงและไม่ใช่ notes ลวก/None ทุกช่อง
- draft ไม่มี CJK/Hangul/markup/EnglishGloss ระดับ block
- `title-registry.md` ถูกเติม/อัปเดตจากชื่อบทไทย

ถ้าสคริปต์ขึ้น `[FAIL]` ห้ามรายงานว่า Draft เสร็จ ให้แก้ไฟล์ที่ gate ระบุก่อน

## สรุปหลังแปล

หลังแปลเสร็จ ให้สรุปสั้นๆ:

- จำนวนย่อหน้าคร่าว ๆ
- ศัพท์ใหม่ที่พบแต่ยังไม่มีใน OKF (ตรงกับที่ลงใน notes)
- ชื่อบทไทยที่เสนอหรือใช้จาก `title-registry.md`
- จุดที่ไม่มั่นใจและควรตรวจเกาหลี

