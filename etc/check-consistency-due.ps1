<#
.SYNOPSIS
    [DEPRECATED] เลิกใช้แล้วใน arc model — ใช้ etc/check-arc-phase.ps1 แทน

.DESCRIPTION
    สคริปต์นี้เคยใช้ตอน workflow แบบ per-chapter + batch ทุก 10 ตอน เพื่อกัน consistency
    check ค้างก่อนเปิด batch ใหม่

    ตอนนี้ workflow เป็น arc-based phases แล้ว — หน้าที่กัน consistency ค้างถูกรวมเข้า
    etc/check-arc-phase.ps1 (gate เข้า Phase B จะตรวจว่าทำ consistency + OKF freeze แล้วจริง)

    เก็บไฟล์นี้ไว้เป็น pointer กันสับสนสำหรับคนที่จำคำสั่งเก่า
#>

Write-Host "[DEPRECATED] check-consistency-due.ps1 เลิกใช้แล้วใน arc model" -ForegroundColor Yellow
Write-Host "             ใช้แทนด้วย: powershell -File etc/check-arc-phase.ps1 -Arc <N> -Phase B" -ForegroundColor Cyan
Write-Host "             (gate เข้า Phase B ตรวจ consistency + OKF freeze ให้แล้ว)" -ForegroundColor Cyan
exit 0
