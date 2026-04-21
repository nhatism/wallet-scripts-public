-- ENUMS
CREATE TYPE account_type AS ENUM ('CUSTOMER', 'MERCHANT', 'SYSTEM');    
CREATE TYPE account_status_enum AS ENUM ('active', 'inactive', 'suspended', 'closed');
CREATE TYPE statement_status_enum AS ENUM ('open', 'closed', 'finalized');
CREATE TYPE business_tx_status_enum AS ENUM ('pending', 'completed', 'failed', 'reversed', 'cancelled');
CREATE TYPE staff_status_enum AS ENUM ('active', 'inactive');
CREATE TYPE withdrawal_status_enum AS ENUM ('pending', 'verified', 'completed', 'failed', 'expired');
CREATE TYPE cash_session_status_enum AS ENUM ('open', 'closed');
CREATE TYPE staff_role_enum AS ENUM ('cashier', 'admin');
CREATE TYPE fee_mode_enum AS ENUM ('rate', 'fixed');
CREATE TYPE auth_status_enum AS ENUM ('active', 'locked', 'disabled');
CREATE type auth_entity_enum as ENUM ('staff', 'customer', 'merchant');
CREATE TYPE recon_status_enum AS ENUM ('pending', 'running', 'completed', 'failed');
CREATE TYPE recon_scope_enum AS ENUM ('account', 'ledger', 'pos');
CREATE TYPE recon_trigger_enum AS ENUM ('manual', 'scheduled', 'auto');


-- STATIC
CREATE TABLE ledger_types (
    ledger_type VARCHAR(50) PRIMARY KEY,
    ledger_type_description VARCHAR(255) NOT NULL
);

CREATE TABLE entry_types (
    entry_type VARCHAR(10) PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE account_types (
    acc_type VARCHAR(50) PRIMARY KEY,
    acc_type_description VARCHAR(255) NOT NULL
);

CREATE TABLE transaction_types (
    business_tx_type VARCHAR(50) PRIMARY KEY,
    tx_type_description VARCHAR(255) NOT NULL
);

-- CORE
CREATE TABLE ledgers (
    ledger_id BIGSERIAL PRIMARY KEY,
    ledger_no VARCHAR(20) UNIQUE NOT NULL,
    ledger_type VARCHAR(50),
    ledger_name VARCHAR(255),
    last_seq_no BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE accounts (
    acc_id            BIGSERIAL PRIMARY KEY,
    acc_no            VARCHAR(30) UNIQUE NOT NULL,
    acc_type          account_type NOT NULL,
    customer_id       BIGINT,
    merchant_id       BIGINT,
    branch_id         BIGINT,
    current_balance   BIGINT DEFAULT 0,
    last_seq_no       BIGINT DEFAULT 0
);

-- USERS
CREATE TABLE staff (
    staff_id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    staff_id_card VARCHAR(50) UNIQUE,
    role staff_role_enum NOT NULL,
    status staff_status_enum DEFAULT 'active'
);

CREATE TABLE customers (
    customer_id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    id_card VARCHAR(50) UNIQUE
);

CREATE TABLE merchants (
    merchant_id BIGSERIAL PRIMARY KEY,
    master_acc_id BIGINT,
    tax_code VARCHAR(50) UNIQUE,
    merchant_name VARCHAR(255),
    merchant_owner_id BIGSERIAL,
    FOREIGN KEY (merchant_owner_id) REFERENCES customers(customer_id)
);

-- =============================================
-- BRANCHES
-- Each merchant can have multiple branches
-- =============================================

CREATE TABLE branches (
    branch_id BIGSERIAL PRIMARY KEY,
    merchant_id BIGINT NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    branch_address VARCHAR(255) NOT NULL,
    branch_code VARCHAR(50) UNIQUE NOT NULL,
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

CREATE TABLE auth_accounts (
    auth_id BIGSERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(60) NOT NULL,
    entity_type auth_entity_enum NOT NULL,
    entity_id BIGINT,
    last_login_at TIMESTAMPTZ,
    status auth_status_enum DEFAULT 'active'
);

CREATE TABLE pin (
    owner_id BIGINT,
    owner_type owner_type_enum,
    pin_hash VARCHAR(255),
    PRIMARY KEY (owner_id, owner_type)
);

-- POS + SESSION
CREATE TABLE pos_terminals (
    pos_id BIGSERIAL PRIMARY KEY,
    ledger_id BIGINT,
    pos_address VARCHAR(255)
);

CREATE TABLE cash_sessions (
    session_id BIGSERIAL PRIMARY KEY,
    pos_id BIGINT,
    staff_id BIGINT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    opening_balance BIGINT,
    closing_balance BIGINT,
    difference BIGINT,
    status cash_session_status_enum
);

-- TRANSACTION CORE
CREATE TABLE transaction_metadata (
    ref_id BIGSERIAL PRIMARY KEY,
    ref_code VARCHAR(30) NOT NULL UNIQUE,
    public_ref_code VARCHAR(12),
    idempotency_key VARCHAR(100) UNIQUE,            -- transaction-level idempotency
    business_tx_type VARCHAR(50),
    business_tx_status business_tx_status_enum DEFAULT 'pending',
    original_ref_code VARCHAR(30),
    user_note TEXT,
    metadata_json JSONB
);

CREATE TABLE account_transactions (
    tx_id BIGSERIAL PRIMARY KEY,
    acc_id BIGINT,
    ledger_id BIGINT,
    amount BIGINT NOT NULL CHECK (amount > 0),
    entry_type VARCHAR(20) NOT NULL,
    ref_id BIGINT NOT NULL,
    tx_datetime TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    balance_after BIGINT NOT NULL,
    seq_no BIGINT NOT NULL,
    UNIQUE (acc_id, seq_no)
);

CREATE TABLE ledger_transactions (
    ledger_tx_id BIGSERIAL PRIMARY KEY,
    ledger_id BIGINT,
    entry_type VARCHAR(20) NOT NULL,
    amount BIGINT NOT NULL CHECK (amount > 0),
    ref_id BIGINT NOT NULL,
    ledger_seq_no BIGINT NOT NULL,
    session_id BIGINT,
    tx_datetime TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (ledger_id, ledger_seq_no)
);

-- STATEMENT + FEES
CREATE TABLE account_statements (
    acc_id BIGINT,
    period VARCHAR(20),
    opening_balance BIGINT,
    total_debit BIGINT,
    total_credit BIGINT,
    closing_balance BIGINT,
    status statement_status_enum,
    PRIMARY KEY (acc_id, period)
);

CREATE TABLE fees (
    ref_id BIGINT PRIMARY KEY,
    fee_type VARCHAR(50),
    fee_mode fee_mode_enum,
    applied_rate INTEGER,
    applied_amount BIGINT NOT NULL CHECK (applied_amount > 0)
);

-- WITHDRAWAL
CREATE TABLE withdrawal_requests (
    request_id          BIGSERIAL PRIMARY KEY,
    acc_id              BIGINT NOT NULL,
    ref_id              BIGINT,                         -- NO FK (decoupled lifecycle)
    amount              BIGINT NOT NULL CHECK (amount > 0),
    public_ref_code     VARCHAR(12) NOT NULL UNIQUE,   -- staff / user dùng để tra
    idempotency_key     VARCHAR(100) NOT NULL UNIQUE,   -- request-level idempotency
    status              withdrawal_status_enum DEFAULT 'pending',
    expires_at          TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    verified_by_staff_id BIGINT,
    
    CONSTRAINT chk_ref_when_completed 
        CHECK (
            (status = 'completed' AND ref_id IS NOT NULL)
            OR (status <> 'completed')
        )
);

-- WORK + RECON
CREATE TABLE work_history (
    staff_id BIGINT,
    from_date DATE,
    to_date DATE,
    pos_id BIGINT,
    PRIMARY KEY (staff_id, from_date)
);

CREATE TABLE recon_work_batches (
    recon_id BIGSERIAL PRIMARY KEY,
    recon_type VARCHAR(50),
    scope_type recon_scope_enum,
    scope_id BIGINT,
    period_start TIMESTAMPTZ,
    period_end TIMESTAMPTZ,
    actual_amount BIGINT,
    expected_amount BIGINT,
    diff_amount BIGINT,
    status recon_status_enum,
    error_code VARCHAR(50),
    executed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    trigger_type recon_trigger_enum,
    run_by BIGINT
);

CREATE TABLE ledger_routing_rules (
    rule_id              BIGSERIAL PRIMARY KEY,
    acc_type             account_type NOT NULL,
    business_tx_type     VARCHAR(50),  -- NULL = wildcard (ANY rule) 
    direction            VARCHAR(10) NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    target_ledger_id    BIGINT NOT NULL REFERENCES ledgers(ledger_id),
    is_external_allowed BOOLEAN DEFAULT false,
    priority            INT DEFAULT 100,
    description         TEXT
);


-- CORE FK
ALTER TABLE ledgers ADD FOREIGN KEY (ledger_type) REFERENCES ledger_types(ledger_type);
ALTER TABLE accounts ADD FOREIGN KEY (acc_type) REFERENCES account_types(acc_type);

-- POS / SESSION
ALTER TABLE pos_terminals ADD FOREIGN KEY (ledger_id) REFERENCES ledgers(ledger_id);
ALTER TABLE cash_sessions ADD FOREIGN KEY (pos_id) REFERENCES pos_terminals(pos_id);
ALTER TABLE cash_sessions ADD FOREIGN KEY (staff_id) REFERENCES staff(staff_id);

-- USERS
ALTER TABLE merchants ADD FOREIGN KEY (master_acc_id) REFERENCES accounts(acc_id);
ALTER TABLE accounts 
ADD CONSTRAINT fk_acc_customer 
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE accounts 
ADD CONSTRAINT fk_acc_merchant 
FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id);

ALTER TABLE accounts 
ADD CONSTRAINT fk_acc_branch 
FOREIGN KEY (branch_id) REFERENCES branches(branch_id);

ALTER TABLE accounts ADD CONSTRAINT chk_one_owner
CHECK (
    (customer_id IS NOT NULL)::int +
    (merchant_id IS NOT NULL)::int +
    (branch_id IS NOT NULL)::int = 1
);
ALTER TABLE accounts ADD CONSTRAINT chk_acc_type_match
CHECK (
    (acc_type = 'CUSTOMER' AND customer_id IS NOT NULL AND merchant_id IS NULL AND branch_id IS NULL)
 OR (acc_type = 'MERCHANT' AND (
        (merchant_id IS NOT NULL AND customer_id IS NULL AND branch_id IS NULL)
     OR (branch_id IS NOT NULL AND customer_id IS NULL AND merchant_id IS NULL)
 ))
);


-- TRANSACTION
ALTER TABLE transaction_metadata ADD FOREIGN KEY (business_tx_type) REFERENCES transaction_types(business_tx_type);
ALTER TABLE transaction_metadata ADD FOREIGN KEY (original_ref_code) REFERENCES transaction_metadata(ref_code);

ALTER TABLE account_transactions ADD FOREIGN KEY (acc_id) REFERENCES accounts(acc_id);
ALTER TABLE account_transactions ADD FOREIGN KEY (ledger_id) REFERENCES ledgers(ledger_id);
ALTER TABLE account_transactions ADD FOREIGN KEY (entry_type) REFERENCES entry_types(entry_type);
ALTER TABLE account_transactions ADD FOREIGN KEY (ref_id) REFERENCES transaction_metadata(ref_id);

ALTER TABLE ledger_transactions ADD FOREIGN KEY (ledger_id) REFERENCES ledgers(ledger_id);
ALTER TABLE ledger_transactions ADD FOREIGN KEY (entry_type) REFERENCES entry_types(entry_type);
ALTER TABLE ledger_transactions ADD FOREIGN KEY (ref_id) REFERENCES transaction_metadata(ref_id);
ALTER TABLE ledger_transactions ADD FOREIGN KEY (session_id) REFERENCES cash_sessions(session_id);

-- STATEMENT
ALTER TABLE account_statements ADD FOREIGN KEY (acc_id) REFERENCES accounts(acc_id);

-- FEES
ALTER TABLE fees ADD FOREIGN KEY (ref_id) REFERENCES transaction_metadata(ref_id);

-- WITHDRAWAL (NO FK ref_id intentionally)
ALTER TABLE withdrawal_requests ADD FOREIGN KEY (acc_id) REFERENCES accounts(acc_id);
ALTER TABLE withdrawal_requests ADD FOREIGN KEY (verified_by_staff_id) REFERENCES staff(staff_id);

-- WORK
ALTER TABLE work_history ADD FOREIGN KEY (staff_id) REFERENCES staff(staff_id);
ALTER TABLE work_history ADD FOREIGN KEY (pos_id) REFERENCES pos_terminals(pos_id);

-- RECON
ALTER TABLE recon_work_batches ADD FOREIGN KEY (run_by) REFERENCES staff(staff_id);


CREATE INDEX idx_account_tx_acc_seq ON account_transactions(acc_id, seq_no DESC);
CREATE INDEX idx_account_tx_ref ON account_transactions(ref_id);

CREATE INDEX idx_ledger_tx_ledger_seq ON ledger_transactions(ledger_id, ledger_seq_no DESC);
CREATE INDEX idx_ledger_tx_ref ON ledger_transactions(ref_id);
CREATE INDEX idx_ledger_tx_session ON ledger_transactions(session_id);
CREATE INDEX idx_ledger_tx_ledger_session  ON ledger_transactions(ledger_id, session_id);

CREATE INDEX idx_cash_sessions_pos_time ON cash_sessions(pos_id, start_time);

CREATE INDEX idx_withdraw_acc ON withdrawal_requests(acc_id);

CREATE INDEX idx_merchants_master_acc ON merchants(master_acc_id);

CREATE INDEX idx_auth_entity ON auth_accounts(entity_type, entity_id);

CREATE INDEX idx_recon_scope ON recon_work_batches(scope_type, scope_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_transaction_metadata_public_ref ON transaction_metadata(public_ref_code);
