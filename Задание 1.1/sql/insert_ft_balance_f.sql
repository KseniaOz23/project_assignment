INSERT INTO DS.FT_BALANCE_F 
(on_date, account_rk, currency_rk, balance_out)
SELECT 
    ON_DATE, 
    ACCOUNT_RK, 
    CURRENCY_RK, 
    BALANCE_OUT
FROM temp_table
WHERE ACCOUNT_RK IS NOT NULL
ON CONFLICT (on_date, account_rk) 
DO UPDATE SET 
    currency_rk = EXCLUDED.currency_rk,
    balance_out = EXCLUDED.balance_out