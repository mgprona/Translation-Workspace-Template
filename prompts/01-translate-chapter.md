# Prompt: Translate Chapter

แปลตอนที่ `{CHAPTER_NUMBER}` เป็นภาษาไทย

## Source

Source หลัก:

`sources/eng_clean_chapter/ch{CHAPTER_NUMBER}.txt`

ถ้ามีไฟล์เกาหลี ให้ใช้ตรวจชื่อและนัย:

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

## ข้อกำหนด

- แปลครบทุกย่อหน้า
- รักษาลำดับบทสนทนา
- ใช้สำนวนไทยแนวนวนิยายกำลังภายในร่วมสมัย
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

หลังแปลเสร็จ ให้สรุป:

- จำนวนย่อหน้าคร่าว ๆ
- ศัพท์ใหม่ที่พบแต่ยังไม่มีใน OKF
- ชื่อบทไทยที่เสนอหรือใช้จาก `title-registry.md`
- จุดที่ไม่มั่นใจและควรตรวจเกาหลี

