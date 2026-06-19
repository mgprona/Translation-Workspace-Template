# Prompt: Update OKF

ระหว่างแปลตอนที่ `{CHAPTER_NUMBER}` หากพบชื่อเฉพาะ วิชา สำนัก ตำแหน่ง วัตถุ หรือแนวคิดใหม่ที่ยังไม่มีใน OKF ให้ทำตามขั้นตอนนี้

## ขั้นตอน

1. ตรวจใน OKF เดิมก่อน:
   - `terms.md`
   - `characters.md`
   - `factions.md`
   - `places.md`
   - `techniques.md`
   - `artifacts.md`
   - `voice-register.md` (ถ้าเป็นตัวละครที่มีบทพูด/น้ำเสียงชัด)
   - `chapter-registry.md`, `title-registry.md`, `source-map.md` (metadata/source coverage)

2. ถ้าไม่มีจริง ให้เสนอรายการใหม่ในรูปแบบ:

   - English:
   - Korean ถ้ามี:
   - Thai ที่เสนอ:
   - Category:
   - เหตุผล:
   - ไฟล์ OKF ที่ควรเพิ่ม:

3. เพิ่มรายการลงไฟล์ OKF ที่เกี่ยวข้อง และอย่าลืมไฟล์ metadata:
   - ชื่อบท/สถานะชื่อบท → `title-registry.md`
   - source coverage รายตอน → `chapter-registry.md`
   - จำนวนไฟล์/coverage source → `source-map.md`
   - ตัวละครที่มีน้ำเสียงชัด → `voice-register.md`

4. บันทึกการตัดสินใจที่:

   `logs/translation-decisions.md`

5. ก่อน freeze/เข้า Phase B ให้รัน OKF gate:

   ```powershell
   powershell -File etc/verify-okf.ps1 -Start {START} -End {END} -CheckAllFiles -RequireRangeMetadata
   ```

   ถ้า `[FAIL]` ต้องอัปเดต OKF ให้ครบก่อน ห้าม freeze

## ข้อห้าม

- ห้ามเพิ่มคำซ้ำกับคำที่มีอยู่แล้ว
- ห้ามเปลี่ยนคำมาตรฐานเดิมโดยไม่บันทึกเหตุผล
- ห้ามใส่ศัพท์ใหม่ในบทแปลโดยไม่อัปเดต OKF ถ้าเป็นศัพท์สำคัญ
