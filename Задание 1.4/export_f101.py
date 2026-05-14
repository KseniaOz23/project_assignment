import psycopg2
import csv
from datetime import datetime

DB_CONFIG = {
    'host': 'localhost',
    'port': 5433,
    'database': 'postgres',
    'user': 'postgres',
    'password': 'Pricinfa23!p'
}

def export_to_csv():
    print("Начало выгрузки...")

    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM dm.dm_f101_round_f ORDER BY chapter, ledger_account")
    rows = cursor.fetchall()

    col_names = [desc[0] for desc in cursor.description]

    with open('f101_round_f.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(col_names)
        
        for row in rows:
            new_row = []
            for value in row:
                if isinstance(value, float):
                    new_row.append(str(value).replace('e', 'E'))
                else:
                    new_row.append(value)
            writer.writerow(new_row)

    print(f"Выгружено {len(rows)} записей в f101_round_f.csv")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    export_to_csv()