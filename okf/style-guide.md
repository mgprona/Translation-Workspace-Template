---
type: Style Guide
title: Thai Novel Style Guide
status: draft
updated: {DATE}
---

# Style Guide

## ปรัชญาการแปล (อ่านก่อนทุกครั้ง — ใช้ได้ทุก genre)

กลุ่มผู้อ่านคือคนที่อ่านนิยายยาวหลายร้อยตอน**บนมือถือ ในเวลาสั้นๆ** — บนรถ ที่ทำงาน ตอนพัก เป้าหมายคือ **อ่านไหลลื่น เข้าใจทันที ไม่ต้องหยุดแกะ** แต่ยังได้อรรถรสของเรื่องเดิม

หลักการ 5 ข้อ:

1. **"แปล" ไม่ใช่ "แปลตรง"** — ถ่ายทอด*ความหมายและอารมณ์* เป็นภาษาไทยที่คนไทยเขียนจริง ไม่ใช่ลอกโครงประโยคอังกฤษ/เกาหลีมาเรียงคำไทย
2. **ไหลลื่นเป็นอันดับแรก** — ถ้าประโยคไหนอ่านแล้วสะดุด ต้องแก้ แม้จะ "ตรงต้นฉบับ" แค่ไหนก็ตาม
3. **คงบรรยากาศเดิม ไม่ทำให้หรูขึ้นหรือจืดลง** — ห้ามยกระดับคำให้อลังการเกินต้นฉบับ (อ่านเหนื่อย) และห้ามตัดอารมณ์จนแบน — เกลาให้ "ลื่น" ไม่ใช่ "หรู"
4. **อย่าเล่นคำซ้อนจนอ่านยาก** — เลี่ยงคำประสมยืดยาว/สำนวนโบราณที่ต้องตีความ เลือกคำที่เห็นปุ๊บเข้าใจปั๊บ
5. **ห้ามเพิ่มของที่ต้นฉบับไม่มี** — ไหลลื่น ≠ แต่งเติม ห้ามเพิ่มประโยคบรรยาย/รายละเอียดประสาทสัมผัสที่ต้นฉบับไม่ได้เขียน

> สมดุลที่ต้องการ: **อ่านลื่นเหมือนนิยายไทยที่เขียนดี + คงกลิ่นอายของแนว (เช่น ศัพท์วิชา/สำนัก/ปราณ ของกำลังภายใน)** — ลื่นแต่ไม่ทิ้งรากของเรื่อง



ตั้งค่า genre profile ตอนเริ่มโปรเจกต์ (bootstrap จะตั้งให้อัตโนมัติ หรือตั้งเอง)

| ด้าน | ค่าที่ตั้ง |
|------|----------|
| ประเภท | {ระบุ: กำลังภายใน / แฟนตาซี / โรแมนซ์ / Sci-fi / Thriller / สมจริง} |
| Tone | {ระบุ: ขลังจริงจัง / สนุกตื่นเต้น / มืดหม่น / อบอุ่น / ตึงเครียด / เบาสนุก} |
| ระดับภาษา | {ระบุ: โบราณสูง / กึ่งโบราณ-ทางการ / ร่วมสมัย / วัยรุ่น-ปากเปล่า} |
| คำต้องหลีก | {ระบุคำที่ไม่เข้ากับบรรยากาศเรื่อง เช่น คำแสลงสมัยใหม่ในเรื่องโบราณ} |
| ระดับการบรรยาย | {ระบุ: ละเอียดเน้นอารมณ์ / สมดุล / กระชับเน้น action} |

### ตัวอย่าง Genre Profile สำเร็จรูป

| แนว | Tone | ระดับภาษา | คำต้องหลีก | ระดับการบรรยาย |
|-----|------|-----------|-----------|---------------|
| กำลังภายใน (Wuxia/Xianxia) | ขลัง จริงจัง มีพลัง | กึ่งโบราณ-ทางการ | คำแสลงสมัยใหม่, ศัพท์เทคโนโลยี, คำทับศัพท์อังกฤษที่มีคำไทยใช้ได้ | ละเอียด เน้นอารมณ์และบรรยากาศ |
| แฟนตาซีร่วมสมัย | สนุก ตื่นเต้น | ร่วมสมัย | ภาษาราชการแข็ง, คำโบราณที่ผู้อ่านไม่คุ้น | สมดุล action-description |
| โรแมนซ์ | อบอุ่น ละเอียดอ่อน | ร่วมสมัย-ปากเปล่า | ศัพท์เทคนิคหนัก, คำแข็งทื่อ | ละเอียดด้านอารมณ์-ความรู้สึก |
| Sci-fi | cool, precise | ร่วมสมัย-เทคนิค | ภาษาโบราณ, สำนวนกำลังภายใน | กระชับ เน้นแนวคิดและระบบ |
| Thriller/สืบสวน | ตึงเครียด คมคาย | ร่วมสมัย | คำฟุ่มเฟือย, คำบรรยายยืดยาว | สั้น กระชับ จังหวะเร็ว |

## Rules

| Rule | What it means |
|---|---|
| Primary source order | Use the primary source as main authority; use the reference source (a second language, when available) to confirm names, titles, and nuance. Primary language is set in source-map.md. |
| No annotation leakage | Do not leave translator notes, bracketed explanations, or correction marks in the prose. |
| One term, one form | Choose one Thai rendering for each canonical term and keep it stable across the whole series. |
| No mixed-script noise | Do not allow stray English, Korean, Chinese, or edit marks in the final prose. |
| Honorific consistency | Use the same Thai voice for father, brother, master, and formal addresses throughout. |
| Sibling safety | Do not swap older/younger brother if the story depends on rank/succession. |
| Chapter title cleanup | Strip raw BBCode/markup from titles when presenting in registry or translation output. |

## Voice targets

(Define character voice targets here as the story develops.)

## Word choice mapping (per genre)

ตารางคำที่ช่วยให้ `03-polish-chapter` เลือกคำตรงแนว — **เติมของเรื่องคุณเอง** ให้ตรง genre profile ด้านบน ตัวอย่างด้านล่างเป็นแนวกำลังภายใน (ลบ/แทนได้ถ้าเป็นแนวอื่น):

| English | คำที่เลี่ยง (แข็ง/แปล) | คำที่เลือก (เข้าแนว) |
|---|---|---|
| Martial World | โลกศิลปะการต่อสู้ | ยุทธจักร / ยุทธภพ |
| Sect | กลุ่ม/องค์กร | สำนัก / พรรค / ลัทธิ |
| Bodyguard | การ์ด | องครักษ์ / ผู้คุ้มกัน |
| Madman | คนสติไม่ดี | วิปลาส / คนบ้า |

> เรื่องร่วมสมัย/Sci-fi ให้ทำตารางกลับด้าน — เลี่ยงคำโบราณ เลือกคำร่วมสมัยแทน

## Formatting

- Keep dialogue natural in Thai.
- Do not insert translator comments into the story.
- Avoid overusing parenthetical explanations in prose.
- Strip source markup from titles before publishing them in the registry.
