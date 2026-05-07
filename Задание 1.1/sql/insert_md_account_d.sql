INSERT INTO DS.MD_ACCOUNT_D 
(data_actual_date, data_actual_end_date, account_rk, account_number, char_type, currency_rk, currency_code)
SELECT 
    DATA_ACTUAL_DATE, 
    DATA_ACTUAL_END_DATE, 
    ACCOUNT_RK, 
    ACCOUNT_NUMBER, 
    CHAR_TYPE, 
    CURRENCY_RK, 
    CURRENCY_CODE
FROM temp_table
ON CONFLICT (data_actual_date, account_rk) 
DO UPDATE SET 
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    account_number = EXCLUDED.account_number,
    char_type = EXCLUDED.char_type,
    currency_rk = EXCLUDED.currency_rk,
    currency_code = EXCLUDED.currency_code