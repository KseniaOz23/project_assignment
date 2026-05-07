INSERT INTO DS.MD_EXCHANGE_RATE_D 
(data_actual_date, data_actual_end_date, currency_rk, reduced_cource, code_iso_num)
SELECT 
    DATA_ACTUAL_DATE, 
    DATA_ACTUAL_END_DATE, 
    CURRENCY_RK, 
    REDUCED_COURCE, 
    CODE_ISO_NUM
FROM temp_table
ON CONFLICT (data_actual_date, currency_rk) 
DO UPDATE SET 
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    reduced_cource = EXCLUDED.reduced_cource,
    code_iso_num = EXCLUDED.code_iso_num