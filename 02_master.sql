-- =============================================
-- 02_master_data.sql
-- Master Data Seed - Clean & Re-runnable
-- 3 Customers | 1 Merchant (Milo Coffee) | 2 Branches | 5 Accounts
-- All IDs resolved via subquery, no hard-coded IDs
-- =============================================

-- =============================================
-- 1. STAFF
-- =============================================
INSERT INTO staff (full_name, staff_id_card, role, status)
VALUES
    ('Nguyen Van Admin',     'ST099', 'admin',   'active'),
    ('Tran Kim Anh',         'ST001', 'cashier', 'active'),
    ('Doan Vinh Phat',       'ST002', 'cashier', 'active')
ON CONFLICT (staff_id_card) DO NOTHING;

-- =============================================
-- 2. CUSTOMERS
-- =============================================
INSERT INTO customers (full_name, id_card)
VALUES
    ('Huynh Cong Thu',    'CC123456789'),
    ('Bui Minh Nhat',     'CC987654321'),
    ('Nguyen Ha Trang',   'CC777777777')   -- Owner of Milo Coffee
ON CONFLICT (id_card) DO NOTHING;

-- =============================================
-- 3. MERCHANTS
-- =============================================
INSERT INTO merchants (tax_code, merchant_name, merchant_owner_id)
SELECT 
    '0101234567',
    'Milo Coffee',
    customer_id
FROM customers 
WHERE id_card = 'CC777777777'
ON CONFLICT (tax_code) 
DO UPDATE SET
    merchant_name = EXCLUDED.merchant_name,
    merchant_owner_id = EXCLUDED.merchant_owner_id;

-- =============================================
-- 4. BRANCHES
-- =============================================
INSERT INTO branches (merchant_id, branch_name, branch_address, branch_code)
SELECT
    m.merchant_id,
    b.branch_name,
    b.branch_address,
    b.branch_code
FROM merchants m
CROSS JOIN (VALUES
    ('Milo Coffee - Hanoi Branch',      '10 Phan Dinh Phung, Ba Dinh, Ha Noi',      'MILO-HN-01'),
    ('Milo Coffee - Ho Chi Minh Branch', '07 Le Loi, District 1, Ho Chi Minh',      'MILO-HCM-01')
) AS b(branch_name, branch_address, branch_code)
WHERE m.tax_code = '0101234567'
ON CONFLICT (branch_code) DO NOTHING;

-- =============================================
-- 5. POS TERMINALS
-- =============================================
INSERT INTO pos_terminals (ledger_id, pos_address)
VALUES
    (2, '30 Nguyen Trai, Ha Noi'),      -- POS_HN_01
    (3, '67 Nguyen Du, Ho Chi Minh')    -- POS_HCM_01
ON CONFLICT DO NOTHING;

-- =============================================
-- 6. WORK HISTORY SEED
-- Mỗi staff làm việc tại 1 POS từ đầu tháng 3/2026
-- =============================================

INSERT INTO work_history (staff_id, from_date, to_date, pos_id)
VALUES
    -- Staff 2 (Tran Kim Anh) làm tại POS_HN_01
    ((SELECT staff_id FROM staff WHERE staff_id_card = 'ST001'),
     '2026-03-01'::DATE,
     NULL,
     (SELECT pos_id FROM pos_terminals WHERE ledger_id = 2)),   -- POS_HN_01

    -- Staff 3 (Doan Vinh Phat) làm tại POS_HCM_01
    ((SELECT staff_id FROM staff WHERE staff_id_card = 'ST002'),
     '2026-03-01'::DATE,
     NULL,
     (SELECT pos_id FROM pos_terminals WHERE ledger_id = 3))    -- POS_HCM_01
ON CONFLICT (staff_id, from_date) DO NOTHING;


-- =============================================
-- 7. ACCOUNTS (All start with zero balance)
-- =============================================
INSERT INTO accounts 
    (acc_no, acc_type, customer_id)
VALUES
    ('10123456789', 'CUSTOMER',
        (SELECT customer_id FROM customers WHERE id_card = 'CC123456789')),

    ('10987654321', 'CUSTOMER',
        (SELECT customer_id FROM customers WHERE id_card = 'CC987654321'));
    
    INSERT INTO accounts 
    (acc_no, acc_type, merchant_id)
VALUES
    ('09686868686', 'MERCHANT',
        (SELECT merchant_id FROM merchants WHERE tax_code = '0101234567'));
    
    INSERT INTO accounts 
    (acc_no, acc_type, branch_id)
VALUES
    ('05246813579', 'MERCHANT',
        (SELECT branch_id FROM branches WHERE branch_code = 'MILO-HN-01')),

    ('05789789789', 'MERCHANT',
        (SELECT branch_id FROM branches WHERE branch_code = 'MILO-HCM-01'))    
ON CONFLICT (acc_no) DO NOTHING;


-- =============================================
-- 8. LINK MASTER ACCOUNT TO MERCHANT
-- =============================================
UPDATE merchants m
SET master_acc_id = a.acc_id
FROM accounts a
WHERE m.tax_code = '0101234567'
  AND a.acc_no = '09686868686';


-- =============================================
-- 8. SEQUENCE SAFETY RESET
-- =============================================
SELECT setval('staff_staff_id_seq',          COALESCE((SELECT MAX(staff_id) FROM staff), 0) + 1, false);
SELECT setval('customers_customer_id_seq',  COALESCE((SELECT MAX(customer_id) FROM customers), 0) + 1, false);
SELECT setval('merchants_merchant_id_seq',  COALESCE((SELECT MAX(merchant_id) FROM merchants), 0) + 1, false);
SELECT setval('branches_branch_id_seq',     COALESCE((SELECT MAX(branch_id) FROM branches), 0) + 1, false);
SELECT setval('pos_terminals_pos_id_seq',   COALESCE((SELECT MAX(pos_id) FROM pos_terminals), 0) + 1, false);
SELECT setval('accounts_acc_id_seq',        COALESCE((SELECT MAX(acc_id) FROM accounts), 0) + 1, false);

-- =============================================
-- VERIFICATION SUMMARY
-- =============================================
-- Table: Master Data Summary
SELECT 'staff'      AS table_name, COUNT(*) AS row_count FROM staff
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'merchants', COUNT(*) FROM merchants
UNION ALL
SELECT 'branches',  COUNT(*) FROM branches
UNION ALL
SELECT 'pos_terminals', COUNT(*) FROM pos_terminals
UNION ALL
SELECT 'accounts',  COUNT(*) FROM accounts;
