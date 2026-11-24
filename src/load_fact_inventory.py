"""Load all fact_inventory CSV parts into MySQL, in order, with checks.

Before running:
  1. Unzip the .csv.gz parts so you have fact_inventory_partNNN.csv files.
  2. Run only the CREATE TABLE fact_inventory from 04_facts.sql (no INSERT).
  3. local_infile must be ON on the server: SET GLOBAL local_infile = 1;

Settings come from environment variables (nothing is hardcoded):
  MYSQL_HOST (default localhost), MYSQL_PORT (default 3306),
  MYSQL_USER (default root), MYSQL_PASSWORD (asked if missing),
  MYSQL_DATABASE (default healthcare), PARTS_DIR (folder with the CSV parts)

Safe by design: it refuses to run if fact_inventory already has rows, and it
stops at the first warning or short part. If it stops partway, run
TRUNCATE TABLE fact_inventory; and start again. Do not rerun a failed part.
"""
import getpass
import os
import re
import sys
from pathlib import Path

import mysql.connector

PARTS_DIR = Path(os.environ.get("PARTS_DIR", r"C:\Users\User\Downloads\exports\fact_inventory\"))
TABLE = "fact_inventory"
ROWS_PER_PART = 5_000_000   # every part except the last
EXPECTED_PARTS = 19       
EXPECTED_TOTAL = 90731353       


def find_parts():
    files = sorted(PARTS_DIR.glob("fact_inventory_part*.csv"))
    if not files:
        sys.exit(f"No fact_inventory_part*.csv files in {PARTS_DIR}. Did you unzip them?")
    numbers = []
    for p in files:
        m = re.search(r"part(\d+)\.csv$", p.name)
        if not m:
            sys.exit(f"Unexpected file name: {p.name}")
        numbers.append(int(m.group(1)))
    if numbers != list(range(1, len(numbers) + 1)):
        sys.exit(f"Parts are not contiguous from 1: {numbers}. A part is missing.")
    if EXPECTED_PARTS is not None and len(files) != EXPECTED_PARTS:
        sys.exit(f"Found {len(files)} parts, expected {EXPECTED_PARTS}.")
    return files


def main():
    files = find_parts()
    password = os.environ.get("MYSQL_PASSWORD") or getpass.getpass("MySQL password: ")

    conn = cur = None
    loaded_total = 0
    current = None
    try:
        conn = mysql.connector.connect(
            host=os.environ.get("MYSQL_HOST", "localhost"),
            port=int(os.environ.get("MYSQL_PORT", "3306")),
            user=os.environ.get("MYSQL_USER", "root"),
            password=password,
            database=os.environ.get("MYSQL_DATABASE", "healthcare"),
            connection_timeout=3600,
            allow_local_infile=True,
        )
        cur = conn.cursor()
        cur.execute("SET SESSION net_read_timeout = 3600")
        cur.execute("SET SESSION net_write_timeout = 3600")

        cur.execute(f"SELECT 1 FROM {TABLE} LIMIT 1")
        if cur.fetchone():
            sys.exit(f"{TABLE} already has rows. TRUNCATE TABLE {TABLE}; first, "
                     "then rerun. Loading on top would create duplicates.")

        for i, path in enumerate(files, start=1):
            current = path.name
            sql_path = path.resolve().as_posix()   # forward slashes: safe in MySQL strings
            if "'" in sql_path:
                sys.exit(f"Remove the apostrophe from the path: {sql_path}")
            sql = (
                f"LOAD DATA LOCAL INFILE '{sql_path}' INTO TABLE {TABLE} "
                "FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' "
                "LINES TERMINATED BY '\\r\\n' IGNORE 1 LINES"
            )
            cur.execute(sql)
            loaded = cur.rowcount
            warnings = cur.fetchwarnings()
            conn.commit()

            if warnings:
                sys.exit(f"{current}: MySQL reported warnings, stopping. First few: {warnings[:5]}")
            is_last = (i == len(files))
            if not is_last and loaded != ROWS_PER_PART:
                sys.exit(f"{current}: loaded {loaded:,} rows, expected {ROWS_PER_PART:,}. Stopping.")

            loaded_total += loaded
            print(f"[{i}/{len(files)}] {current}: {loaded:,} rows (running total {loaded_total:,})", flush=True)

        cur.execute(f"SELECT COUNT(*) FROM {TABLE}")
        table_count = cur.fetchone()[0]
        print(f"Table row count: {table_count:,}")
        if table_count != loaded_total:
            sys.exit(f"MISMATCH: loaded {loaded_total:,} but table has {table_count:,}.")
        if EXPECTED_TOTAL is not None and table_count != EXPECTED_TOTAL:
            sys.exit(f"MISMATCH: table has {table_count:,}, README says {EXPECTED_TOTAL:,}.")
        if EXPECTED_TOTAL is None:
            print("NOTE: set EXPECTED_TOTAL to the README value so the total is checked too.")
        print("Done. Now run the Step 5 verification queries from the README.")
    except mysql.connector.Error as e:
        print(f"MySQL error while loading {current}: {e}", file=sys.stderr)
        print(f"Loaded so far: {loaded_total:,} rows. Run TRUNCATE TABLE {TABLE}; and restart.",
              file=sys.stderr)
        raise
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


if __name__ == "__main__":
    main()