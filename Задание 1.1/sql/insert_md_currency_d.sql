INSERT INTO DS.MD_CURRENCY_D 
(currency_rk, data_actual_date, data_actual_end_date, currency_code, code_iso_char)
SELECT 
    CURRENCY_RK, 
    DATA_ACTUAL_DATE, 
    DATA_ACTUAL_END_DATE, 
    CURRENCY_CODE, 
    CODE_ISO_CHAR
FROM temp_table
ON CONFLICT (currency_rk, data_actual_date) 
DO UPDATE SET 
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    currency_code = EXCLUDED.currency_code,
    code_iso_char = EXCLUDED.code_iso_char