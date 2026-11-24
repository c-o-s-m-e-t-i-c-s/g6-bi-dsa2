## **NOTE FOR 04_facts.sql:**

Running fact_inventory's ``INSERT`` block will take anywhere from ~3-8 hours to run. Instead, load ``fact_inventory`` as an exported CSV file for use in dashboarding.

90,731,353 rows in 19 files. 2 GB zipped, ~3 GB when extracted <br>
**Download Link**: https://drive.google.com/drive/folders/165Xg6Qx6p6vhKI3FIGr5j-pVhpol5_Gr?usp=sharing

### **Before you start (read this):**
1. If you ran 03 before the change, run the ``ALTER`` block for ``dim_inventory`` in ``03_dimensions.sql`` to match each SKU to dim_medicine.
2. Ensure the ``fact_inventory`` surrogate keys match with ``dim_inventory``. Run this query or check in ``dim_inventory``'s validation in 03_dimensions.sql and match with mine:
```sql
-- 1. Spot-check: same SKU, same key?
SELECT inventory_key, material_sku
FROM dim_inventory
WHERE material_sku IN ('A0A286718', 'Z9Z900387')
ORDER BY material_sku;

-- 2. Whole-table fingerprint
CHECKSUM TABLE dim_inventory;
```


| Check | Expected |
|---|---|
| key for A0A286718 | 1 |
| key for Z9Z900387 | 346302 |
| CHECKSUM TABLE dim_inventory | 2080410278 |
3. Ensure that you have at least **10 GB** of free space.

### **Step 1: Download and unzip**
1. Download all parts into one folder, e.g. ``C:\Users\User\Downloads\exports\fact_inventory\``
2. Unzip .gz files by using 7ZIP or by running this in PowerShell:

```powershell
cd C:\Users\User\Downloads\exports\fact_inventory\ # change this
Get-ChildItem *.csv.gz | ForEach-Object {
    $out = $_.FullName -replace '\.gz$',''
    $in  = [IO.File]::OpenRead($_.FullName)
    $gz  = New-Object IO.Compression.GzipStream($in, [IO.Compression.CompressionMode]::Decompress)
    $dst = [IO.File]::Create($out)
    $gz.CopyTo($dst); $dst.Close(); $gz.Close(); $in.Close()
    Write-Host "Unzipped $out"
```

### **Step 2: Ensure ``LOCAL INFILE`` is set to 1**
1. Server side, in a MySQL session with admin rights:
```sql
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';   -- expect ON
```
2. Client side, in Workbench: Manage Server Connections > your connection > Advanced > Others, add ``OPT_LOCAL_INFILE=1``, then reconnect.

### **Step 3: Create the tables**
1. Run only the ``CREATE TABLE fact_inventory`` statement from ``04_facts.sql``. **Do not run the INSERT that follows it.**


### **Step 4: Load the tables in order**
1. Run ``src/load_fact_inventory.py`` and ensure that ``PARTS_DIR`` in .env is set to the correct path of the extracted fact tables.

```python
pip install --upgrade mysql-connector-python
$env:PARTS_DIR = "C:\Users\User\Downloads\exports\fact_inventory"
$env:MYSQL_PORT = "3306"     # your port
python src/load_fact_inventory.py     # asks for the password
```

### **Step 5: Verify the tables (NECESSARY):**
1. Run this query in a new file:
```sql
SELECT
    COUNT(*)                                                      AS total_rows,
    CEILING(COUNT(*) / 5000000)                                   AS expected_parts,
    COUNT(*) - (CEILING(COUNT(*) / 5000000) - 1) * 5000000        AS last_part_rows,
    MIN(inventory_fact_key)                                            AS min_key,
    MAX(inventory_fact_key)                                            AS max_key
FROM fact_inventory;
```
Expected:
|total_rows| expected_parts| last_part_rows| min_key| max_key |
|---|---|---|---|---|
|90731353| 19|731353| 1| 93944165|

**Note**: max_key is larger than total_rows because auto-increment skipped values during the original build. This is expected. Compare the numbers exactly as listed

2. Orphan check (expect 0).
```sql
SELECT COUNT(*) AS orphan_rows
FROM fact_inventory f
LEFT JOIN dim_inventory d ON d.inventory_key = f.inventory_key
WHERE d.inventory_key IS NULL;
```