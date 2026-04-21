-- =============================================
-- 00_static.sql
-- Closed-Loop Financial System
-- Axioms Layer (Immutable domain definitions)
--
-- Ledger     = accounting classification only
-- Entry      = mathematical sign system
-- Account    = entity identity layer
-- Transaction= event layer
-- =============================================


-- =============================================
-- 1. LEDGER TYPES (ACCOUNTING AXIOMS ONLY)
-- =============================================

INSERT INTO ledger_types (ledger_type, ledger_type_description) VALUES
('ASSET',     'Economic resources controlled by the system'),
('LIABILITY', 'Obligations owed to external entities'),
('EQUITY',    'System net value and retained earnings'),
('CLEARING',  'Temporary balancing and reconciliation accounts')
ON CONFLICT (ledger_type) DO NOTHING;


-- =============================================
-- 2. ENTRY TYPES (DOUBLE ENTRY CORE MODEL)
-- =============================================

INSERT INTO entry_types (entry_type, description)
VALUES
('DEBIT',  'Debit entry (accounting standard)'),
('CREDIT', 'Credit entry (accounting standard)');
ON CONFLICT (entry_type) DO NOTHING;


-- =============================================
-- 3. ACCOUNT TYPES (ENTITY ONLY)
-- =============================================

INSERT INTO account_types (acc_type, acc_type_description) VALUES
('CUSTOMER', 'End user financial account'),
('MERCHANT', 'Merchant financial account'),
('SYSTEM',   'Internal system operational account')
ON CONFLICT (acc_type) DO NOTHING;


-- =============================================
-- 4. BUSINESS TRANSACTION TYPES (EVENT LAYER)
-- =============================================

INSERT INTO transaction_types (business_tx_type, tx_type_description) VALUES
('DEPOSIT',           'Funds added into the system by customer'),
('WITHDRAWAL',        'Funds removed from the system by customer'),
('PAYMENT',           'Customer payment to merchant'),
('FEE',               'System fee charged on transactions'),
('ADJUSTMENT',        'Manual correction of balances'),
('REVERSAL',          'Reversal of a previous transaction'),
('INTERNAL_TRANSFER', 'Transfer between internal le


-- =============================================
-- SANITY CHECK (OPTIONAL)
-- =============================================
SELECT 'ledger_types' AS table_name, COUNT(*) AS row_count FROM ledger_types
UNION ALL
SELECT 'entry_types', COUNT(*) FROM entry_types
UNION ALL
SELECT 'account_types', COUNT(*) FROM account_types
UNION ALL
SELECT 'transaction_types', COUNT(*) FROM transaction_types;
UNION ALL
SELECT 'transaction_types', COUNT(*) FROM ledgers;
