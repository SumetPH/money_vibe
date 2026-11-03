-- ยอดเดิมในสกุลต่างประเทศของรายรับ/รายจ่าย (เช่น รูดบัตร THB ที่ญี่ปุ่น)
-- amount ยังเป็นสกุลของบัญชีเสมอ คอลัมน์นี้เป็นข้อมูลประกอบสำหรับแสดงผลและดู rate จริง
ALTER TABLE public.transactions
    ADD COLUMN foreign_amount numeric NULL,
    ADD COLUMN foreign_currency text NULL;

ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_foreign_amount_check CHECK (
        (foreign_amount IS NULL AND foreign_currency IS NULL)
        OR (foreign_amount > 0 AND foreign_currency IS NOT NULL)
    );
