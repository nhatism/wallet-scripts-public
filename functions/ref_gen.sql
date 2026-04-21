-- Tạo sequence cho ref_code và public_ref_code
CREATE SEQUENCE IF NOT EXISTS ref_code_seq START 1000;
CREATE SEQUENCE IF NOT EXISTS public_ref_seq START 100000;
-----
CREATE OR REPLACE FUNCTION generate_ref_code()
RETURNS VARCHAR(30) AS $$
BEGIN
    RETURN 'TXN-' || 
           TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
           LPAD(nextval('ref_code_seq')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

----

CREATE OR REPLACE FUNCTION generate_public_ref_code()
RETURNS VARCHAR(12) AS $$
BEGIN
    RETURN 'TRX' || LPAD(nextval('public_ref_seq')::TEXT, 7, '0');
END;
$$ LANGUAGE plpgsql;

----------------------
-- Tra ngược:
SELECT 
    ref_id,
    ref_code,
    public_ref_code,
    business_tx_type,
    business_tx_status
FROM transaction_metadata
WHERE public_ref_code = 'TRX0012345';   -- user nhập vào
