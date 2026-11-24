"""
NOTE: There is no need to run this file unless you want to export fact_inventory from the healthcare database.
"""

import csv, gzip, os, sys
import mysql.connector  # swap for your existing connector

OUT_DIR = r"C:\Users\marc\OneDrive\UST Homework\3rd year\Business Intelligence"   # a drive with space
ROWS_PER_FILE = 5_000_000
FETCH = 100_000
NULL = r"\N"

conn = cur = f = None
part = rows_total = rows_in_part = 0
try:
    os.makedirs(OUT_DIR, exist_ok=True)
    conn = mysql.connector.connect(
        host="localhost", port=3310, user="root", password="12345", database="healthcare",
        connection_timeout=3600,
    )
    cur = conn.cursor(buffered=False)   # streams, doesn't fill RAM
    cur.execute("SELECT * FROM fact_inventory ORDER BY inventory_key")  # see note below
    header = [d[0] for d in cur.description]

    def open_part(n):
        path = os.path.join(OUT_DIR, f"fact_inventory_part{n:03d}.csv.gz")
        fh = gzip.open(path, "wt", newline="", encoding="utf-8")
        wr = csv.writer(fh)
        wr.writerow(header)
        return fh, wr

    part = 1
    f, w = open_part(part)
    while True:
        batch = cur.fetchmany(FETCH)
        if not batch:
            break
        for row in batch:
            if rows_in_part >= ROWS_PER_FILE:
                f.close()
                part += 1
                rows_in_part = 0
                f, w = open_part(part)
            w.writerow([NULL if v is None else v for v in row])
            rows_in_part += 1
            rows_total += 1
    print(f"Done: {rows_total:,} rows in {part} files -> {OUT_DIR}")
except Exception as e:
    print(f"Export failed after {rows_total:,} rows (part {part}): {e}", file=sys.stderr)
    raise
finally:
    if f: f.close()
    if cur: cur.close()
    if conn: conn.close()