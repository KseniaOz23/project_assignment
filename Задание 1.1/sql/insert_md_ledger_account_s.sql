INSERT INTO DS.MD_LEDGER_ACCOUNT_S 
(chapter, chapter_name, section_number, section_name, subsection_name, 
 ledger1_account, ledger1_account_name, ledger_account, ledger_account_name, 
 characteristic, start_date, end_date)
SELECT 
    CHAPTER, 
    CHAPTER_NAME, 
    SECTION_NUMBER, 
    SECTION_NAME, 
    SUBSECTION_NAME, 
    LEDGER1_ACCOUNT, 
    LEDGER1_ACCOUNT_NAME, 
    LEDGER_ACCOUNT, 
    LEDGER_ACCOUNT_NAME, 
    CHARACTERISTIC, 
    START_DATE, 
    END_DATE
FROM temp_table
ON CONFLICT (ledger_account, start_date) 
DO UPDATE SET 
    chapter = EXCLUDED.chapter,
    chapter_name = EXCLUDED.chapter_name,
    section_number = EXCLUDED.section_number,
    section_name = EXCLUDED.section_name,
    subsection_name = EXCLUDED.subsection_name,
    ledger1_account = EXCLUDED.ledger1_account,
    ledger1_account_name = EXCLUDED.ledger1_account_name,
    ledger_account_name = EXCLUDED.ledger_account_name,
    characteristic = EXCLUDED.characteristic,
    end_date = EXCLUDED.end_date