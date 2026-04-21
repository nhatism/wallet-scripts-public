-- =============================================
-- 01_ledgers.sql
-- =============================================

INSERT INTO ledgers (ledger_no, ledger_type, ledger_name)
VALUES
    ('VAULT_HO',     'ASSET',     'Central Cash Vault'),
    ('POS_HN_01',    'ASSET',     'POS Terminal Hanoi 01'),
    ('POS_HCM_01',   'ASSET',     'POS Terminal Ho Chi Minh 01'),
    ('LIAB_CUSTOMER','LIABILITY', 'Customer Wallet Balances'),
    ('LIAB_MERCHANT','LIABILITY', 'Merchant Payable Balances'),
    ('FEE_POOL',     'INCOME',    'System Fee Revenue Pool'),
    ('SETTLEMENT',   'CLEARING',  'Intermediary Settlement Clearing Account')
ON CONFLICT (ledger_no) DO NOTHING;

-- Reset sequence an toàn (chạy sau insert)
SELECT setval('ledgers_ledger_id_seq', 
              COALESCE((SELECT MAX(ledger_id) FROM ledgers), 0) + 1, false);


INSERT INTO ledger_routing_rules
(acc_type, business_tx_type, direction, target_ledger_id, is_external_allowed, priority, description)
VALUES
-- CUSTOMER WALLET
('CUSTOMER', 'DEPOSIT',    'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_CUSTOMER'), true,  200, 'External deposit into customer wallet'),
('CUSTOMER', NULL,         'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_CUSTOMER'), false, 100, 'Default customer credit'),
('CUSTOMER', NULL,         'DEBIT',  (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_CUSTOMER'), false, 100, 'Default customer debit'),
-- MERCHANT PAYABLE
('MERCHANT', 'PAYMENT',    'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_MERCHANT'), false, 200, 'Customer payment to merchant'),
('MERCHANT', NULL,         'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_MERCHANT'), false, 100, 'Default merchant credit'),
('MERCHANT', NULL,         'DEBIT',  (SELECT ledger_id FROM ledgers WHERE ledger_no = 'LIAB_MERCHANT'), false, 100, 'Default merchant debit'),
-- SYSTEM / FEES
('SYSTEM',   'FEE',        'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'FEE_POOL'), true,  300, 'System fee income'),
('SYSTEM',   'SETTLEMENT', 'DEBIT',  (SELECT ledger_id FROM ledgers WHERE ledger_no = 'SETTLEMENT'), true,  300, 'External settlement out'),
('SYSTEM',   'SETTLEMENT', 'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'SETTLEMENT'), true,  300, 'External settlement in'),
-- SYSTEM DEFAULT FALLBACK (ANY RULE)
('SYSTEM',   NULL,         'CREDIT', (SELECT ledger_id FROM ledgers WHERE ledger_no = 'FEE_POOL'), true,  100, 'System default fallback credit');



-- Table: Ledgers Seed Result
SELECT 
    ledger_id,
    ledger_no,
    ledger_type,
    ledger_name
FROM ledgers 
ORDER BY ledger_id;
