# Manual Refresh แบบ Cupertino ด้วย wrapper กลาง แทน CupertinoSliverRefreshControl

Manual Refresh ต้องการหน้าตาแบบ iOS (เนื้อหาถูกดันลงและค้างช่อง spinner ระหว่างโหลด) แต่ `CupertinoSliverRefreshControl` ใช้ได้เฉพาะใน `CustomScrollView` ขณะที่หน้าต่าง ๆ ใช้ `ListView`, `SingleChildScrollView` และ `ReorderableListView` เป็น scroll view นอกสุด การเปลี่ยนทุกหน้าเป็น sliver (รวม `SliverReorderableList`) เสี่ยงกระทบโหมดจัดเรียง จึงเขียน `AppCupertinoRefresh` ที่ฟัง overscroll จาก scroll view ชนิดใดก็ได้ บังคับ bouncing physics ทุก platform และเลื่อนเนื้อหาลงเองระหว่างโหลด
