# Batch Plan

| Batch | Chapters | Draft | QA | Edited | Final | Last consistency check | Next check due | Notes |
|---|---|---|---|---|---|---|---|---|

## Rules

- **Checkpoint ทุก 10 ตอน**: ต้องทำ consistency report (`prompts/05-consistency-range.md`) ก่อนเริ่ม Draft ของ Batch ถัดไป
- ถ้า `Last consistency check` ว่าง แสดงว่ายังไม่เคยตรวจช่วงนั้น ห้ามข้ามไป Batch ถัดไป
- ถ้า `Next check due` ถึงกำหนดแล้ว ต้องตรวจก่อนเปิดรอบ Draft ใหม่
- **Gate บังคับ**: ก่อนเปิด Batch ใหม่ ให้รัน `powershell -File etc/check-consistency-due.ps1` — ถ้า exit ≠ 0 (มี batch ที่ Final เสร็จแต่ยังไม่มีไฟล์ consistency report) **ห้ามแปลตอนใหม่** ต้องทำ consistency ที่ค้างก่อน
