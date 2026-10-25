import glob, os, time, logging
from pathlib import Path
import pandas as pd
import pymysql

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("etl")

# ---------- SETTINGS: edit these ----------
DATA_DIR = Path(os.environ["DATA_DIR"])   # <- edit for your dataset folder
CHUNK = 500_000
TMP = os.path.join("tmp", "chunk.csv")
os.makedirs("tmp", exist_ok=True)

CHECK_ONLY = True                      # change to False to actually load
CREATE_TABLES = False            # run once, then set back to False
ONLY = None                            # e.g. ["STG_EHP__ALGY"] to test one table
COUNT_ROWS = True                         # count rows in CSV and MySQL tables without loading

FOLDER_TO_TABLE = {
    "inventory":          "STG_EHP__INVN",
    "diagnosis":          "STG_EHP__DIAG",
    "payment":            "STG_EHP__PMNT",
    "treatment medicine": "STG_EHP__TMMD",
    "vendor payment":     "STG_EHP__VPMT",
}


READ_KW = dict(dtype=str, keep_default_na=False, na_values=[""], encoding="utf-8-sig")

def get_conn():
    return pymysql.connect(host=os.getenv("DB_HOST", "localhost"), port=int(os.getenv("DB_PORT", 3310)), user=os.environ["DB_USER"], 
                           password=os.environ["DB_PASSWORD"], database=os.getenv("DB_NAME", "healthcare"), local_infile=True)

def read_header(path):
    return pd.read_csv(path, nrows=0, encoding="utf-8-sig").columns.str.strip()

# ---------- TRANSFORM: one small function per table ----------
def clean_default(df):
    return df.apply(lambda s: s.str.strip().mask(lambda x: x == ""))     # trim whitespace in every column

def clean_vist(df):
    df = clean_default(df)
    df["VIS_EN"] = pd.to_datetime(df["VIS_EN"], errors="coerce")
    df["VIS_EX"] = pd.to_datetime(df["VIS_EX"], errors="coerce")
    return df

TRANSFORMS = {"STG_EHP__VIST": clean_vist}          # add tables as you find issues

def parse_dates(df, cols):
    for c in cols:
        had_value = df[c].notna()
        # NOTE: ambiguous dates like 03/04/2025 are read month-first. If your source is
        # day-first, add dayfirst=True. Alternatively load dates raw and parse them in SQL.
        df[c] = pd.to_datetime(df[c], errors="coerce")
        lost = int((had_value & df[c].isna()).sum())
        if lost:
            log.warning(f"{c}: {lost:,} value(s) could not be parsed as dates and became NULL")
    return df

# ---------- CHECKS ----------
def count_csv_rows(paths, chunksize=CHUNK):
    total = 0
    for p in paths:
        for chunk in pd.read_csv(p, usecols=[0], chunksize=chunksize, **READ_KW):
            total += len(chunk)
    return total


def count_table_rows(conn, table):
    with conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM `{table}`")
        return cur.fetchone()[0]


def verify_counts(conn, jobs):
    all_ok = True
    for table, paths in jobs.items():
        csv_rows = count_csv_rows(paths)
        db_rows = count_table_rows(conn, table)
        match = csv_rows == db_rows
        all_ok = all_ok and match
        log.info(f"{table}: csv={csv_rows:,} db={db_rows:,} -> {'OK' if match else 'MISMATCH'}")
    return all_ok



# ---------- LOAD ----------
def check_headers(jobs, conn):
    ok = True
    with conn.cursor() as cur:
        for table, paths in jobs.items():
            try:
                cur.execute(f"SHOW COLUMNS FROM `{table}`")
            except pymysql.err.ProgrammingError:
                log.error(f"{table}: table not found (check FOLDER_TO_TABLE or run CREATE_TABLES)")
                ok = False
                continue
            expected = {r[0] for r in cur.fetchall()} - {"SRC_FILE"}
            for p in paths:
                cols = set(pd.read_csv(p, nrows=0).columns.str.strip())
                if cols != expected:
                    log.error(f"MISMATCH {p}\n  missing: {expected - cols}\n  extra: {cols - expected}")
                    ok = False
    return ok
    
def load_table(conn, table, paths):
    cur = conn.cursor()
    cur.execute(f"TRUNCATE TABLE `{table}`")        # re-runs start clean
    total = 0
    for path in paths:
        t0 = time.time()
        for chunk in pd.read_csv(path, dtype=str, chunksize=CHUNK,
                                 keep_default_na=False, na_values=[""]):
            chunk = TRANSFORMS.get(table, clean_default)(chunk)
            chunk["SRC_FILE"] = os.path.basename(path)
            chunk.to_csv(TMP, index=False, header=False, na_rep=r"\N", lineterminator="\n")
            cols = ",".join(f"`{c}`" for c in chunk.columns)
            cur.execute(f"""
                LOAD DATA LOCAL INFILE '{TMP.replace(os.sep, "/")}'
                INTO TABLE `{table}`
                CHARACTER SET utf8mb4
                FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
                LINES TERMINATED BY '\\n'
                ({cols})
            """)
            total += cur.rowcount
        conn.commit()
        log.info(f"{table} <- {os.path.basename(path)} ({time.time()-t0:.0f}s)")
    log.info(f"{table}: {total:,} rows loaded")
    return total

def create_staging_tables(conn, jobs):
    cur = conn.cursor()
    for table, paths in jobs.items():
        cols = []                                    # union of columns across all files
        for p in paths:
            for c in read_header(p):                 
                if c not in cols:
                    cols.append(c)
        col_defs = ", ".join(f"`{c}` VARCHAR(255)" for c in cols)
        cur.execute(f"DROP TABLE IF EXISTS `{table}`")
        cur.execute(f"CREATE TABLE `{table}` ({col_defs}, `SRC_FILE` VARCHAR(100))")
        log.info(f"created {table}: {len(cols)} columns from {len(paths)} file(s)")
    conn.commit()

    
# ---------- RUN ----------
def build_jobs():
    """Map every CSV under DATA_DIR to its staging table."""
    jobs = {}
    for path in sorted(DATA_DIR.rglob("*.csv")):
        if path.parent == DATA_DIR:                 # file sits at the top level
            table = path.stem
        else:                                       # file sits inside a folder
            folder = path.parent.name
            table = FOLDER_TO_TABLE.get(folder, folder)
        jobs.setdefault(table, []).append(str(path))
    return jobs


def main():
    jobs = build_jobs()
    if ONLY:
        jobs = {t: p for t, p in jobs.items() if t in ONLY}
    if not jobs:
        raise SystemExit("No CSV files matched. Check DATA_DIR and ONLY.")
 
    for t, p in jobs.items():
        log.info(f"{t}: {len(p)} file(s)")

    
    conn = get_conn()
    try:
        if CREATE_TABLES:
            create_staging_tables(conn, jobs)

        if not check_headers(jobs, conn):
            raise SystemExit("Header mismatch: fix the errors above before loading.")
        log.info("header check passed")

        if not CHECK_ONLY:
            for table, paths in jobs.items():
                load_table(conn, table, paths)
        if COUNT_ROWS:
            if not verify_counts(conn, jobs):
                log.warning("Row count mismatch found. Investigate before building on this data.")
    finally:
        conn.close()
 
if __name__ == "__main__":
    main()
