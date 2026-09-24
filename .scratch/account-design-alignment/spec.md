# Account design alignment

`docs/design.md` เป็น source of truth; ไฟล์นี้เป็นรายการจุดที่ source code ยังต้องตรวจหรือปรับเมื่อมีงาน UI และไม่ใช่กติกา design. การตรวจครั้งนี้อ่าน source เท่านั้น ยังไม่มี visual QA บนอุปกรณ์.

- [ ] `lib/screens/account/portfolio_analyze_screen.dart`: header ใช้สี header และปุ่ม back แบบ raw icon ต่างจาก header ของหน้า detail ใน design.
- [ ] `lib/screens/account/portfolio_investment_plan_screen.dart`: stock selection sheet ใช้ header เฉพาะหน้า แทน `AppModalBottomSheetHeader`.
- [ ] `lib/widgets/account_picker_bottom_sheet.dart`: แถวตัวเลือกเป็น `Container` สี่เหลี่ยมแยกกัน; ควรตรวจ grouped surface, มุม และ ripple เทียบกับ selection sheet contract.
- [ ] `lib/screens/account/portfolio_detail_screen.dart`: dialog แก้ cash balance และ exchange rate ต้องตรวจ contrast, keyboard และ action layout ในสอง theme.
- [ ] Account List, Form, Credit Card Bill, Portfolio Detail, holding forms และ modal ที่เกี่ยวข้อง: ตรวจ visual state บน mobile/จอกว้างและ light/dark ก่อนปิดรายการนี้.
