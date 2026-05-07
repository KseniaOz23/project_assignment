# -*- coding: utf-8 -*-
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
from airflow.exceptions import AirflowFailException

import pandas as pd
import time
from datetime import datetime

def log_etl_start(table_name, file_name, hook):
    sql = """
        INSERT INTO LOGS.ETL_LOG (table_name, start_time, status, file_name)
        VALUES (%s, %s, 'STARTED', %s)
        RETURNING log_id
    """
    with hook.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (table_name, datetime.now(), file_name))
            log_id = cur.fetchone()[0]
            conn.commit()
            return log_id


def log_etl_end(log_id, rows_loaded, status, error_msg, hook):
    sql = """
        UPDATE LOGS.ETL_LOG 
        SET end_time = %s, rows_loaded = %s, status = %s, error_message = %s
        WHERE log_id = %s
    """
    with hook.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (datetime.now(), rows_loaded, status, error_msg, log_id))
            conn.commit()

def load_csv_to_table(table_name, csv_file, sql_file, truncate_first=False):
    hook = PostgresHook("postgres-db")
    log_id = None
    
    try:
        # Пробуем разные кодировки
        encodings_to_try = ['utf-8', 'cp1251', 'latin1', 'iso-8859-5']
        df = None
        
        for encoding in encodings_to_try:
            try:
                df = pd.read_csv(
                    f"/files/{csv_file}", 
                    delimiter=";", 
                    encoding=encoding,
                    encoding_errors='replace'  # Заменяет битые символы
                )
                print(f"Файл {csv_file} успешно прочитан в кодировке {encoding}")
                break
            except UnicodeDecodeError:
                print(f"Кодировка {encoding} не подходит для {csv_file}, пробуем следующую")
                continue
        
        if df is None:
            raise Exception(f"Не удалось прочитать файл {csv_file} ни в одной кодировке")
        
        log_id = log_etl_start(table_name, csv_file, hook)
        
        # Загружаем во временную таблицу
        engine = hook.get_sqlalchemy_engine()
        df.to_sql('temp_table', engine, if_exists='replace', index=False)
        
        # Читаем SQL из файла
        with open(sql_file, 'r', encoding='utf-8') as f:
            sql_query = f.read()
        
        # Выполняем SQL
        with hook.get_conn() as conn:
            with conn.cursor() as cur:
                if truncate_first:
                    cur.execute(f"TRUNCATE TABLE {table_name}")
                cur.execute(sql_query)
                conn.commit()
                
                # Получаем количество записей
                cur.execute(f"SELECT COUNT(*) FROM {table_name}")
                rows_loaded = cur.fetchone()[0]
        
        log_etl_end(log_id, rows_loaded, "SUCCESS", None, hook)
        time.sleep(5)
        
    except Exception as e:
        error_msg = str(e)
        if log_id:
            log_etl_end(log_id, 0, "FAILED", error_msg, hook)
        raise AirflowFailException(f"Ошибка загрузки {table_name}: {error_msg}")

def load_md_account_d():
    load_csv_to_table(
        table_name="ds.md_account_d",
        csv_file="md_account_d.csv",
        sql_file="/sql/insert_md_account_d.sql"
    )

def load_md_currency_d():
    load_csv_to_table(
        table_name="ds.md_currency_d",
        csv_file="md_currency_d.csv",
        sql_file="/sql/insert_md_currency_d.sql"
    )

def load_md_exchange_rate_d():
    load_csv_to_table(
        table_name="ds.md_exchange_rate_d",
        csv_file="md_exchange_rate_d.csv",
        sql_file="/sql/insert_md_exchange_rate_d.sql"
    )

def load_md_ledger_account_s():
    load_csv_to_table(
        table_name="ds.md_ledger_account_s",
        csv_file="md_ledger_account_s.csv",
        sql_file="/sql/insert_md_ledger_account_s.sql"
    )

def load_ft_balance_f():
    load_csv_to_table(
        table_name="ds.ft_balance_f",
        csv_file="ft_balance_f.csv",
        sql_file="/sql/insert_ft_balance_f.sql"
    )

def load_ft_posting_f():
    load_csv_to_table(
        table_name="ds.ft_posting_f",
        csv_file="ft_posting_f.csv",
        sql_file="/sql/insert_ft_posting_f.sql",
        truncate_first=True
    )

default_args = {
    "owner": "ozerovak",
    "start_date": datetime(2026, 5, 7),
    "retries": 2,
}

with DAG(
    "bank_etl_load_tables",
    default_args=default_args,
    description="Загрузка данных из CSV в DS слой",
    catchup=False,
    schedule="0 0 * * *",
) as dag:

    start = EmptyOperator(task_id="start")
    
    # Загрузка справочников
    load_account = PythonOperator(
        task_id="load_md_account_d",
        python_callable=load_md_account_d
    )
    
    load_currency = PythonOperator(
        task_id="load_md_currency_d",
        python_callable=load_md_currency_d
    )
    
    load_exchange = PythonOperator(
        task_id="load_md_exchange_rate_d",
        python_callable=load_md_exchange_rate_d
    )
    
    load_ledger = PythonOperator(
        task_id="load_md_ledger_account_s",
        python_callable=load_md_ledger_account_s
    )
    
    split = EmptyOperator(task_id="split")

    # Загрузка фактов
    load_balance = PythonOperator(
        task_id="load_ft_balance_f",
        python_callable=load_ft_balance_f
    )
    
    load_posting = PythonOperator(
        task_id="load_ft_posting_f",
        python_callable=load_ft_posting_f
    )
    
    end = EmptyOperator(task_id="end")
    
    start >> [load_account, load_currency, load_exchange, load_ledger] >> split >> [load_balance, load_posting] >> end