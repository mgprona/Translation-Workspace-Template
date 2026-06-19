# Prompt: Consistency Check Range (จบ Phase A ก่อน OKF freeze)

ตรวจ consistency ระหว่างตอน `{START}`-`{END}`

> **บริบท arc model**: ทำ consistency **ตอนจบ Phase A ของ arc** (draft+QA ครบทั้ง arc แล้ว) ก่อน OKF freeze + ก่อนเข้า Phase B — ใช้ช่วง `{START}-{END}` = ขอบเขตตอนของ arc นั้น (เช่น 1-30) แทน cadence ทุก 10 ตอนแบบเดิม

## Files

บทแปลอยู่ที่:

`thai_draft/`

หรือถ้าเกลาแล้ว:

`thai_edited/`

OKF:

`okf/`

## ตรวจ

- ชื่อคน
- ชื่อสำนัก/ฝ่าย
- ชื่อวิชา
- ชื่อวัตถุ
- คำเรียกตำแหน่ง
- สรรพนามและระดับภาษา
- ความสัมพันธ์ตัวละคร
- คำแปลที่แกว่งระหว่างตอน
- ชื่อบทไทยที่แกว่งหรือยังไม่ล็อกใน `title-registry.md`
- รายการที่ค้างใน `human-review-needed.md`
- เศษอังกฤษ เกาหลี จีน markup หรือ note
- **Term scan**: ถ้ามี `etc/term-extract.ps1` ให้รันครอบคลุมทุกตอนในช่วงนี้ — ชี้ไปที่ทั้งโฟลเดอร์:
  ```powershell
  powershell -File etc/term-extract.ps1 -TargetPath thai_draft -OkfPath okf -FailOnIssue -ReportOnly
  ```
  (ใช้ `thai_edited` เฉพาะกรณีที่ consistency รอบนั้นทำหลังเกลาแล้วจริง; `-ReportOnly` เพื่อเขียนทับรายงานเดิม)
- **Workspace audit**: ตรวจว่าไม่มี phantom/missing chapter และ QA report มี evidence จริง:
  ```powershell
  powershell -File etc/audit-workspace.ps1 -Start {START} -End {END} -CheckText
  ```
  ถ้า audit fail ห้าม freeze OKF หรือเข้า Phase B จนกว่าจะแก้ครบ

## Output

เขียนรายงานที่:

`reports/consistency-{START}-{END}.md`

รูปแบบ:

| Term/Issue | Found forms | OKF standard | Files to fix | Severity |
|---|---|---|---|---|

ท้ายรายงานให้สรุป:

- คำที่ต้องแก้ทันที
- คำที่ควรเพิ่ม OKF
- คำที่ควรส่งให้มนุษย์ตัดสินใน `human-review-needed.md`
- ไฟล์ที่ควรตรวจซ้ำ
- **ถ้าพบ drift มากกว่า 3 จุด → แนะนำให้ QA รอบ 2 ก่อนเปิด Batch ถัดไป**

## Checkpoint enforcement (arc model)

หลังเขียนรายงานนี้แล้ว = จบ Phase A ของ arc ให้ทำตามลำดับ:

1. อัปเดต `reports/batch-plan.md` แถวของ arc นี้: เติม `Consistency` = path รายงาน, ตั้ง `A: Draft+QA` = done
2. **OKF freeze**: ตัดสินศัพท์ที่ค้างใน `human-review-needed.md` ของ arc นี้ให้จบ แล้วบันทึกใน `okf/arc-freeze-log.md` (เพิ่มแถว: arc, ช่วงตอน, วันที่ freeze, จำนวนศัพท์, path รายงานนี้)
3. ถ้าพบ drift > 3 จุด → แก้ให้เคลียร์ก่อน freeze (ใช้ `etc/replace-term.ps1` ถ้าต้องไล่แก้หลายตอน)
4. จากนั้นจึงเข้า Phase B ได้ (gate `etc/check-arc-phase.ps1 -Arc {N} -Phase B` จะตรวจว่า freeze แล้วจริง, consistency report มีไฟล์จริง, และไฟล์ draft/QA ครบทุกตอน)
