# 03: ขยาย Manual Refresh, skeleton และ error state ไปหน้าที่เหลือ

**What to build:** ทำให้หน้า Budgets, Transactions, Statistics, Cash flow และ Recurring ทำงานแบบเดียวกับหน้า Accounts คือ
- ดึงหน้าจอลง (หรือกดปุ่ม refresh บนจอกว้าง) เพื่อโหลด module ของหน้านั้นใหม่
- แสดง skeleton ระหว่างรอข้อมูล
- แสดง error state พร้อมปุ่ม "ลองใหม่" เมื่อโหลดล้มเหลว
- ปิดปุ่ม action จนกว่าข้อมูลจะพร้อม

หน้า Category list ใน drawer ทำแค่ skeleton และ error state ไม่ต้องมี pull-to-refresh ชุด module ของแต่ละหน้าดูตารางใน `../spec.md`

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Budgets (budgets, transactions, categories) ดึงลงแล้วโหลดใหม่ มี skeleton, error state และปิดปุ่ม action ระหว่างรอ
- [ ] Transactions (transactions, accounts, categories) ทำเหมือนข้อแรก
- [ ] Statistics (transactions, accounts) ทำเหมือนข้อแรก
- [ ] Cash flow (cashFlow, accounts, budgets, transactions) ทำเหมือนข้อแรก
- [ ] Recurring (recurring, accounts, categories) ทำเหมือนข้อแรก
- [ ] Category list (categories) แสดง skeleton และ error state พร้อมปุ่ม "ลองใหม่" แต่ไม่มี `RefreshIndicator`
- [ ] บนจอกว้าง ทุกหน้าที่มี pull-to-refresh มีปุ่ม refresh ใน app bar ด้วย
- [ ] ตรวจทั้ง light/dark และมือถือ/จอกว้าง
- [ ] ไฟล์ screen ยาวไม่เกินที่ `AGENTS.md` กำหนด ถ้าเกินให้แยก widget ออกตามกติกา
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
