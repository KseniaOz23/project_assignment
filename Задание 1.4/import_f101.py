import psycopg2
import csv
import re

DB_CONFIG = {
    'host': 'localhost',
    'port': 5433,
    'database': 'postgres',
    'user': 'postgres',
    'password': 'Pricinfa23!p'
}

def clean_number(value):
    if value is None or value == '':
        return None
    if isinstance(value, str):
        value = value.replace(',', '.')
        if 'E' in value or 'e' in value:
            try:
                return float(value)
            except:
                return None
    return value

def import_to_v2():
    print("Начало импорта в dm.dm_f101_round_f_v2...")

    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS dm.dm_f101_round_f_v2")
    cursor.execute("""
        CREATE TABLE dm.dm_f101_round_f_v2 (
            LIKE dm.dm_f101_round_f INCLUDING ALL
        )
    """)

    with open('f101_round_f.csv', 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter=';')
        headers = next(reader)

        placeholders = ','.join(['%s'] * len(headers))
        insert_query = f"INSERT INTO dm.dm_f101_round_f_v2 VALUES ({placeholders})"

        rows_loaded = 0
        for row in reader:
            cleaned_row = []
            for i, value in enumerate(row):
                if i >= 5:
                    cleaned_row.append(clean_number(value))
                else:
                    cleaned_row.append(None if value == '' else value)
            cursor.execute(insert_query, cleaned_row)
            rows_loaded += 1

    conn.commit()
    print(f"Загружено {rows_loaded} записей в dm.dm_f101_round_f_v2")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    import_to_v2()