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

def get_conn():
    return pymysql.connect(host="localhost", port=3310, user="root", password="12345", # change for your MySQL settings
                           database="healthcare", local_infile=True)

# ---------- TRANSFORM: one small function per table ----------
def clean_default(df):
    return df.apply(lambda s: s.str.strip())        # trim whitespace in every column

def clean_vist(df):
    df = clean_default(df)
    df["VIS_EN"] = pd.to_datetime(df["VIS_EN"], errors="coerce")
    df["VIS_EX"] = pd.to_datetime(df["VIS_EX"], errors="coerce")
    return df

TRANSFORMS = {"STG_EHP__VIST": clean_vist}          # add tables as you find issues

# ---------- LOAD ----------
def check_headers(jobs, conn):
    cur = conn.cursor()
    for table, paths in jobs.items():
        cur.execute(f"SHOW COLUMNS FROM `{table}`")
        expected = {r[0] for r in cur.fetchall()} - {"SRC_FILE"}
        for p in paths:
            cols = set(pd.read_csv(p, nrows=0).columns)
            if cols != expected:
                print(f"MISMATCH {p}\n  missing: {expected - cols}\n  extra: {cols - expected}")

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
            chunk.to_csv(TMP, index=False, header=False, na_rep=r"\N")
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
            for c in pd.read_csv(p, nrows=0).columns:
                c = c.strip()
                if c not in cols:
                    cols.append(c)
        col_defs = ", ".join(f"`{c}` VARCHAR(255)" for c in cols)
        cur.execute(f"DROP TABLE IF EXISTS `{table}`")
        cur.execute(f"CREATE TABLE `{table}` ({col_defs}, `SRC_FILE` VARCHAR(100))")
        print(f"created {table}: {len(cols)} columns from {len(paths)} file(s)")
    conn.commit()

# ---------- RUN ----------
if __name__ == "__main__":
    conn = get_conn()

    # map folder names to tables where they don't match exactly
    FOLDER_TO_TABLE = {
        "inventory": "STG_EHP__INVN",
        "diagnosis": "STG_EHP__DIAG",
        "payment":   "STG_EHP__PMNT",
        "treatment medicine":   "STG_EHP__TMMD",
        "vendor payment":   "STG_EHP__VPMT",
    }

    jobs = {}
    for path in sorted(DATA_DIR.rglob("*.csv")):
        if path.parent == DATA_DIR:                 # file sits at the top level
            table = path.stem
        else:                                       # file sits inside a folder
            folder = path.parent.name
            table = FOLDER_TO_TABLE.get(folder, folder)
        jobs.setdefault(table, []).append(str(path))

    for t, p in jobs.items():
        print(t, len(p), "file(s)")

    CHECK_ONLY = True                      # change to False to actually load
    CREATE_TABLES = False            # run once, then set back to False
    ONLY = None                            # e.g. ["STG_EHP__ALGY"] to test one table
    
    if ONLY:
        jobs = {t: p for t, p in jobs.items() if t in ONLY}

    if CREATE_TABLES:
        create_staging_tables(conn, jobs)

    check_headers(jobs, conn)
    print("header check done")

    if not CHECK_ONLY:
        for table, paths in jobs.items():
            load_table(conn, table, paths)
    conn.close()
