# Prompt: Translate Chapter

แปลตอนที่ `{CHAPTER_NUMBER}` เป็นภาษาไทย

## Source

Source หลัก:

`sources/eng_clean_chapter/ch{CHAPTER_NUMBER}.txt`

ถ้ามีต้นฉบับดิบภาษาต้นทาง (เกาหลี/อื่นๆ) ให้ใช้ตรวจชื่อและนัย:

`sources/raw_chapter/ch{CHAPTER_NUMBER}.txt`

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
- ใช้สำนวนไทยตาม genre profile ใน `style-guide.md` (tone, ระดับภาษา, คำต้องหลีก)
- ใช้ศัพท์เฉพาะตาม OKF
- ใช้น้ำเสียงตัวละครตาม `voice-register.md`
- ถ้าชื่อบทมีคำแปลล็อกแล้ว ให้ใช้ตาม `title-registry.md`
- ห้ามใส่วงเล็บอธิบายศัพท์ในเนื้อเรื่อง เว้นแต่ต้นฉบับมีจริง
- ห้ามแปลตรงแข็งแบบเครื่องมือแปล
- ห้ามเปลี่ยนความสัมพันธ์ตัวละคร เช่น พี่/น้อง พ่อ/ลูก อาจารย์/ศิษย์
- ห้ามปล่อยเศษอังกฤษ เกาหลี จีน markup หรือ note หลุด

## Output

ส่งออกเป็น Markdown ที่:

`thai_draft/ch{CHAPTER_NUMBER}.md`

## อัปเดตสถานะ

หลังบันทึกร่างแล้ว ให้อัปเดตสถานะ **ผ่านสคริปต์** (ไม่ต้องแก้ `logs/chapter-status.md` ด้วยมือ — สคริปต์จะตรวจว่าไฟล์ร่างมีจริงก่อนเขียน และลง timestamp จริงให้):

```powershell
powershell -File etc/set-status.ps1 -Chapter {CHAPTER_NUMBER} -Stage draft
```

ถ้าสคริปต์ขึ้น `[FAIL]` แปลว่าไฟล์ร่างยังไม่มีจริง — ห้ามรายงานว่าตอนนี้เสร็จ ให้กลับไปบันทึกร่างก่อน

## เขียน Translation Notes (บังคับ — ห้ามลักไก่)

เขียนไฟล์ `reports/ch{CHAPTER_NUMBER}-translation-notes.md` (ใช้ template จาก `reports/chNNN-translation-notes-template.md`)

**กฎกัน "None" ลักไก่** — จากงานจริง โมเดลชอบใส่ "None" ทุกช่องเพื่อตัดงาน ทั้งที่ตอนนั้นมีชื่อเฉพาะเพียบ:

- ก่อนเขียน ให้ไล่หา **proper noun / ชื่อเฉพาะ** ในต้นฉบับตอนนี้ก่อน (ชื่อคน สำนัก สถานที่ วิชา วัตถุ ตำแหน่ง)
- ทุกชื่อเฉพาะที่ปรากฏ ต้องลงอย่างใดอย่างหนึ่ง: ถ้ายังไม่มีใน OKF → "New ..."; ถ้ามีแล้ว → "Existing OKF Terms Used"
- **ห้ามใส่ "None" ในช่อง New Terms/Characters/Places พร้อมกันทุกช่อง** เว้นแต่ยืนยันแล้วว่าตอนนี้ไม่มีชื่อเฉพาะใหม่จริง (ตอนสั้นมากเท่านั้น) — ตอนความยาวปกติที่ตอบ "None" ทุกช่อง ถือว่ารายงาน **ไม่ผ่าน** ต้องทำใหม่
- ช่อง "Points of Uncertainty" ต้องมีอย่างน้อย 1 ข้อ หรือระบุชัดว่า "ตรวจแล้วไม่มีจุดคลุมเครือ" (ไม่ใช่แค่ "None" ลอยๆ)

## สรุปหลังแปล

หลังแปลเสร็จ ให้สรุปสั้นๆ:

- จำนวนย่อหน้าคร่าว ๆ
- ศัพท์ใหม่ที่พบแต่ยังไม่มีใน OKF (ตรงกับที่ลงใน notes)
- ชื่อบทไทยที่เสนอหรือใช้จาก `title-registry.md`
- จุดที่ไม่มั่นใจและควรตรวจเกาหลี

