USE healthcare;

/*
TABLE OF CONTENTS: (use Ctrl + F to find tables faster)
1. CORE DIMENSIONS
	- dim_patient
    - dim_role
    - dim_staff
	- dim_department
    - dim_room
2. MEDICAL DIMENSIONS
	- dim_medicine_form
    - dim_medicine_status
    - dim_unit_of_measure
    - dim_medicine
    - dim_diagnosis
    - dim_treatment_type
    - dim_treatment_status
    - dim_treatment
    - dim_allergy
3. BUSINESS DIMENSIONS
	- dim_country
    - dim_vendor
    - dim_insurance
    - dim_date
    - dim_medical_team
    - dim_inventory
4. BRIDGE TABLES
	- bridge_staff_id_resolution
	- bridge_room_id_resolution
    - bridge_medical_team_staff
    - brdige_patient_allergy

*/

-- =============================================
-- 1. CORE DIMENSIONS
-- =============================================

-- ==========================================================================================
-- dim_patient
-- ==========================================================================================
DROP TABLE IF EXISTS dim_patient;
CREATE TABLE IF NOT EXISTS dim_patient (
	patient_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_id VARCHAR(20) NOT NULL,
    
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    middle_name VARCHAR(50),
    
    gender_code INT,
    gender_desc VARCHAR(20),
    
    date_of_birth DATE,
    blood_type VARCHAR(5),
    marital_status VARCHAR(20),
    
    UNIQUE(patient_id)
);

-- Populate dimension
INSERT INTO dim_patient (
    patient_id,
    first_name,
    last_name,
    middle_name,
    gender_code,
    gender_desc,
    date_of_birth,
    blood_type,
    marital_status
)
SELECT
    PAT_ID,
    F_NAME,
    L_NAME,
    M_NAME,
    GEN_CD,
    GEN_DES,
    STR_TO_DATE(DT_BRT, '%c/%e/%Y'),
    B_TYPE,
    MAR_ST
FROM stg_patient;

-- ==========================================================================================
-- dim_role
-- ==========================================================================================
DROP TABLE IF EXISTS dim_role;
CREATE TABLE IF NOT EXISTS dim_role (
    role_key INT AUTO_INCREMENT PRIMARY KEY,
    role_code INT NOT NULL,
    role_desc VARCHAR(50),

    UNIQUE (role_code)
);

-- Populate dimension
INSERT INTO dim_role (role_code, role_desc)
SELECT DISTINCT ROLE_CD, ROLE_DES
FROM stg_staff;

-- ==========================================================================================
-- dim_staff
-- ==========================================================================================
DROP TABLE IF EXISTS dim_staff;
CREATE TABLE dim_staff (
    staff_key            INT AUTO_INCREMENT NOT NULL,
    staff_id             VARCHAR(20)  NOT NULL,
    first_name           VARCHAR(50)  NULL,
    middle_name          VARCHAR(50)  NULL,
    last_name            VARCHAR(50)  NULL,
    gender_code          VARCHAR(10)  NULL,
    gender_desc          VARCHAR(30)  NULL,
    date_of_birth        DATE         NULL,
    dept_id              VARCHAR(10)  NULL,
    role_key             INT NOT NULL,
    role_desc            VARCHAR(50)  NULL,
    stat_code            VARCHAR(10)  NULL,
    stat_desc            VARCHAR(30)  NULL,
    hire_date            DATE         NULL,
    role_date            DATE         NULL,
    staff_id_row_count   INT          NOT NULL,
    is_staff_id_shared   TINYINT(1)   NOT NULL,
    salary_yr 		     INT		  NULL,
    salary_mn			 DECIMAL(10,2) NULL,
    PRIMARY KEY (staff_key),
	FOREIGN KEY (role_key) REFERENCES dim_role(role_key)
);

-- Populate dimension
INSERT INTO dim_staff (
    staff_id, first_name, middle_name, last_name,
    gender_code, gender_desc, date_of_birth, dept_id,
    role_key, role_desc, stat_code, stat_desc,
    hire_date, role_date,
    staff_id_row_count, is_staff_id_shared,
    salary_yr, salary_mn
)
SELECT
    s.STF_ID,
    s.F_NAME,
    s.M_NAME,
    s.L_NAME,
    s.GEN_CD,
    s.GEN_DES,
    STR_TO_DATE(s.DT_BRT, '%c/%e/%Y'),
    s.DEP_ID,
    r.role_key,
    r.role_desc,
    s.STAT_CD,
    s.STAT_DES,
    STR_TO_DATE(s.HIRE_DATE, '%c/%e/%Y'),
    STR_TO_DATE(s.ROLE_DATE, '%c/%e/%Y'),
    COUNT(*) OVER (PARTITION BY s.STF_ID),
    (COUNT(*) OVER (PARTITION BY s.STF_ID) > 1),
    s.SAL_YR,
    s.SAL_MN
FROM stg_staff s
JOIN dim_role r
    ON s.ROLE_CD = r.role_code;
 
 -- Unknown member (target of unresolved references)
INSERT INTO dim_role (role_key, role_code, role_desc)
VALUES (32, -1, 'Unknown');

INSERT INTO dim_staff
    (staff_key, staff_id, first_name, last_name, role_key, stat_desc,
     staff_id_row_count, is_staff_id_shared)
VALUES
    (-1, 'UNKNOWN', 'Unknown', 'Unknown', 32, 'Unknown', 0, 0);

-- ==========================================================================================
-- dim_department
-- ==========================================================================================
DROP TABLE IF EXISTS dim_department;
CREATE TABLE IF NOT EXISTS dim_department(
	dept_key INT AUTO_INCREMENT PRIMARY KEY,
    dept_id VARCHAR(20) NOT NULL,
    dept_name VARCHAR(100),
    dept_desc VARCHAR(200),
    dept_loc VARCHAR(200),
    
    UNIQUE(dept_id)
);	

INSERT INTO dim_department (
    dept_id,
    dept_name,
    dept_desc,
    dept_loc
)
SELECT
    DEP_ID,
    DEP_NAME,
    DEP_DES,
    DEP_LOC
FROM stg_department;

-- ==========================================================================================
-- dim_room
-- ==========================================================================================
DROP TABLE IF EXISTS dim_room;
CREATE TABLE IF NOT EXISTS dim_room (
    room_key            INT NOT NULL AUTO_INCREMENT,
    room_id             VARCHAR(20) NOT NULL,
    dept_id             VARCHAR(10) NULL,
    purpose_code        VARCHAR(20) NULL,
    purpose_desc        VARCHAR(50) NULL,
    roomtype_code       VARCHAR(20) NULL,
    roomtype_desc       VARCHAR(50) NULL,
    capacity_num        INT NULL,
    room_id_row_count   INT NOT NULL DEFAULT 1,
    is_room_id_shared   TINYINT(1) NOT NULL DEFAULT 0,

    PRIMARY KEY (room_key)
);

-- Populate the table
INSERT INTO dim_room (
    room_id, dept_id,
    purpose_code, purpose_desc,
    roomtype_code, roomtype_desc,
    capacity_num, room_id_row_count, is_room_id_shared
)
SELECT
    ROM_ID,
    DEP_ID,
    PRPS_CD,
    PRPS_DES,
    RTYPE_CD,
    RTYPE_DES,
    CPCT_NO,
    COUNT(*) OVER (PARTITION BY ROM_ID),
    COUNT(*) OVER (PARTITION BY ROM_ID) > 1
FROM stg_rooms;

-- Insert Unknown room
INSERT INTO dim_room (
    room_key, room_id, dept_id,
    purpose_code, purpose_desc,
    roomtype_code, roomtype_desc,
    capacity_num, room_id_row_count, is_room_id_shared
)
VALUES (
    -1, 'UNKNOWN', 'UNKNOWN',
    'UNKNOWN', 'Unknown',
    'UNKNOWN', 'Unknown',
    NULL, 0, 0
);

-- =============================================
-- 2. MEDICAL DIMENSIONS
-- =============================================

-- ==========================================================================================
-- dim_medicine_form
-- ==========================================================================================
DROP TABLE IF EXISTS dim_medicine_form;
CREATE TABLE IF NOT EXISTS dim_medicine_form (
	form_key INT AUTO_INCREMENT PRIMARY KEY,
    form_code INT NOT NULL,
    form_desc VARCHAR(20) NOT NULL
);

-- Populate table
INSERT INTO dim_medicine_form (
	form_code, form_desc
)
SELECT 
	FORM_CD, MAX(FORM_DES)
FROM stg_medicine
WHERE FORM_CD IS NOT NULL
GROUP BY FORM_CD;
-- ==========================================================================================
-- dim_medicine_status
-- ==========================================================================================
DROP TABLE IF EXISTS dim_medicine_status;
CREATE TABLE dim_medicine_status (
    med_status_key INT AUTO_INCREMENT PRIMARY KEY,
    med_status_desc VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO dim_medicine_status (med_status_desc)
SELECT DISTINCT MSTAT_DES
FROM stg_medicine
WHERE MSTAT_DES IS NOT NULL;
-- ==========================================================================================
-- dim_unit_of_measure
-- ==========================================================================================
DROP TABLE IF EXISTS dim_unit_of_measure;
CREATE TABLE IF NOT EXISTS dim_unit_of_measure (
	unit_key INT AUTO_INCREMENT PRIMARY KEY,
    unit_code VARCHAR(20) NOT NULL,
    unit_desc VARCHAR(50)
);

-- Populate table
INSERT INTO dim_unit_of_measure (
    unit_code
)
SELECT unit_code
FROM (
    SELECT STRN_UN AS unit_code
    FROM stg_medicine

    UNION

    SELECT FMQTY_UN AS unit_code
    FROM stg_medicine
) u
WHERE unit_code IS NOT NULL;

-- Update unit_desc
UPDATE dim_unit_of_measure
SET unit_desc = CASE LOWER(unit_code)
    WHEN 'mg'      THEN 'Milligram'
    WHEN 'mcg/puff' THEN 'Microgram per puff'
    WHEN 'mg/g'    THEN 'Milligram per gram'
    WHEN 'mg/ml'   THEN 'Milligram per milliliter'
    WHEN 'ea'      THEN 'Each'
    WHEN 'puff'    THEN 'Puff'
    WHEN 'g'       THEN 'Gram'
    WHEN 'ml'      THEN 'Milliliter'
    ELSE unit_code
END
WHERE unit_key > 0;

-- ==========================================================================================
-- dim_medicine
-- ==========================================================================================
DROP TABLE IF EXISTS dim_medicine;
CREATE TABLE IF NOT EXISTS dim_medicine (
    medicine_key       INT AUTO_INCREMENT PRIMARY KEY,
    medicine_id        VARCHAR(20) NOT NULL,

    type_code          INT NULL,
    type_desc          VARCHAR(50) NULL,

    form_key           INT NULL,

    strength_num       DECIMAL(10,3) NULL,
    strength_unit_key  INT NULL,

    form_qty_num       DECIMAL(10,3) NULL,
    form_qty_unit_key  INT NULL,

    med_status_key     INT NULL,

    storage_desc       VARCHAR(100) NULL,
    expiration_months  INT NULL,
    units_per_case     INT NULL,
    unit_cost          DECIMAL(12,2) NULL,

    FOREIGN KEY (form_key)
        REFERENCES dim_medicine_form(form_key),

    FOREIGN KEY (strength_unit_key)
        REFERENCES dim_unit_of_measure(unit_key),

    FOREIGN KEY (form_qty_unit_key)
        REFERENCES dim_unit_of_measure(unit_key),

    FOREIGN KEY (med_status_key)
        REFERENCES dim_medicine_status(med_status_key)
);

-- Populate the table
INSERT INTO dim_medicine (
    medicine_id,
    type_code,
    type_desc,
    form_key,
    strength_num,
    strength_unit_key,
    form_qty_num,
    form_qty_unit_key,
    med_status_key,
    storage_desc,
    expiration_months,
    units_per_case,
    unit_cost
)
SELECT
    m.MED_ID,
    m.TYPE_CD,
    m.TYPE_DES,
    f.form_key,
    m.STRN_NO,
    su.unit_key,
    m.FMQTY_NO,
    fu.unit_key,
    ms.med_status_key,
    m.STRG_DES,
    m.EXP_MON,
    m.UN_P_CS,
    m.COST_UN
FROM stg_medicine m
LEFT JOIN dim_medicine_form f
    ON m.FORM_CD = f.form_code
LEFT JOIN dim_unit_of_measure su
    ON m.STRN_UN = su.unit_code
LEFT JOIN dim_unit_of_measure fu
    ON m.FMQTY_UN = fu.unit_code
LEFT JOIN dim_medicine_status ms
    ON m.MSTAT_DES = ms.med_status_desc;

-- ==========================================================================================
-- dim_diagnosis
-- ==========================================================================================
DROP TABLE IF EXISTS dim_diagnosis;
CREATE TABLE IF NOT EXISTS dim_diagnosis (
    diagnosis_key INT AUTO_INCREMENT PRIMARY KEY,

    diagnosis_code INT NOT NULL,
    diagnosis_desc VARCHAR(200),

    UNIQUE (diagnosis_code)
);

INSERT INTO dim_diagnosis (
    diagnosis_code,
    diagnosis_desc
)
SELECT
    DIG_CD,
    MAX(DIG_DES)
FROM stg_diagnosis
WHERE DIG_CD IS NOT NULL
GROUP BY DIG_CD;

-- ==========================================================================================
-- dim_treatment_type
-- ==========================================================================================
DROP TABLE IF EXISTS dim_treatment_type;
CREATE TABLE IF NOT EXISTS dim_treatment_type (
	treatment_type_key INT AUTO_INCREMENT PRIMARY KEY,
    treatment_type_code INT NOT NULL,
    treatment_type_desc VARCHAR(20) NOT NULL,
    UNIQUE(treatment_type_code)
);

INSERT INTO dim_treatment_type (
	treatment_type_code,
    treatment_type_desc
)
SELECT
	TTYPE_CD,
    MAX(TTYPE_DES)
FROM stg_treatment
WHERE TTYPE_CD is NOT NULL
GROUP BY TTYPE_CD;


-- ==========================================================================================
-- dim_treatment_status
-- ==========================================================================================
DROP TABLE IF EXISTS dim_treatment_status;
CREATE TABLE IF NOT EXISTS dim_treatment_status (
	treatment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    treatment_status_code INT NOT NULL,
    treatment_status_desc VARCHAR(20),
    UNIQUE(treatment_status_code)
);

INSERT INTO dim_treatment_status (
	treatment_status_code,
    treatment_status_desc
)
SELECT
	TSTAT_CD,
    MAX(TSTAT_DES)
FROM stg_treatment
WHERE TSTAT_CD is NOT NULL
GROUP BY TSTAT_CD;

-- ==========================================================================================
-- dim_treatment
-- ==========================================================================================
DROP TABLE IF EXISTS dim_treatment;
CREATE TABLE IF NOT EXISTS dim_treatment (
	treatment_key INT AUTO_INCREMENT PRIMARY KEY,
    treatment_code INT NOT NULL,
    treatment_desc VARCHAR (100) NOT NULL,
    UNIQUE(treatment_code)
);

INSERT INTO dim_treatment (
    treatment_code,
    treatment_desc
)
SELECT
    TRTM_CD,
    MAX(TRTM_DES)
FROM stg_treatment
WHERE TRTM_CD IS NOT NULL
GROUP BY TRTM_CD;

-- addtl. notes: create fact_treatment and use dim_treatment, dim_treatment_type, dim_treatment_status as connections using their surrogate keys
-- also check 02_data_quality_checks for decisions on validation 

-- ==========================================================================================
-- dim_allergy
-- ==========================================================================================
DROP TABLE IF EXISTS dim_allergy;
CREATE TABLE IF NOT EXISTS dim_allergy (
    allergy_key INT AUTO_INCREMENT PRIMARY KEY,
    allergy_id INT NOT NULL,
    allergy_name VARCHAR(255),
    UNIQUE (allergy_id)
);

INSERT INTO dim_allergy (allergy_id, allergy_name)
SELECT
    LPAD(TRIM(ALG_ID), 3, '0'),
    MAX(ALG_NAME)
FROM stg_allergy
WHERE ALG_ID IS NOT NULL
GROUP BY LPAD(TRIM(ALG_ID), 3, '0');

-- =============================================
-- 3. BUSINESS DIMENSIONS
-- =============================================

-- ==========================================================================================
-- dim_equipment
-- ==========================================================================================
DROP TABLE IF EXISTS dim_equipment;
CREATE TABLE IF NOT EXISTS dim_equipment (
    eqp_key INT AUTO_INCREMENT PRIMARY KEY,

    eqp_id VARCHAR(20) NOT NULL,
    eqp_name VARCHAR(100) NULL,
    eqp_type_code INT NULL,
    eqp_type_desc VARCHAR(50) NULL,

    eqp_cat_1 VARCHAR(50) NULL,
    eqp_cat_2 VARCHAR(50) NULL,
    eqp_cat_3 VARCHAR(50) NULL,

    eqp_model_no VARCHAR(50) NULL,
    eqp_storage_loc VARCHAR(50) NULL,

    eqp_status_code INT NULL,
    eqp_status_desc VARCHAR(50) NULL
);

INSERT INTO dim_equipment (
    eqp_id,
    eqp_name,
    eqp_type_code,
    eqp_type_desc,
    eqp_cat_1,
    eqp_cat_2,
    eqp_cat_3,
    eqp_model_no,
    eqp_storage_loc,
    eqp_status_code,
    eqp_status_desc
)
SELECT
    EQP_ID,
    EQP_NAME,
    TYPE_CD,
    TYPE_DES,
    EQP_CAT__1,
    EQP_CAT__2,
    EQP_CAT__3,
    MODL_NO,
    STRG_LOC,
    ESTAT_CD,
    ESTAT_DES
FROM stg_equipment;
-- ==========================================================================================
-- dim_country
-- ==========================================================================================
DROP TABLE IF EXISTS dim_country;
CREATE TABLE IF NOT EXISTS dim_country (
	country_key INT AUTO_INCREMENT PRIMARY KEY,
    country_code INT NOT NULL,
    country_name VARCHAR(20) NOT NULL,
    
    UNIQUE(country_code)
);

-- Populate tables
INSERT INTO dim_country (
	country_code, country_name
)
SELECT
	CTRY_CD, MAX(CTRY_NAME)
FROM stg_vendor
WHERE CTRY_CD IS NOT NULL
GROUP BY CTRY_CD;


-- ==========================================================================================
-- dim_vendor
-- ==========================================================================================
CREATE TABLE IF NOT EXISTS dim_vendor (
	vendor_key INT AUTO_INCREMENT PRIMARY KEY,
    vendor_acc VARCHAR(30) NOT NULL,
    
    vendor_name VARCHAR(50) NOT NULL,
    vendor_type VARCHAR(20),
    vendor_status_desc VARCHAR(20),
    
    license_num VARCHAR(30) NOT NULL,
    
    country_key INT,
    country_contact_num VARCHAR(20),
    
    UNIQUE(vendor_acc),
	FOREIGN KEY (country_key) REFERENCES dim_country(country_key)
);

-- Populate tables
INSERT INTO dim_vendor (
    vendor_acc,
    vendor_name,
    vendor_type,
    vendor_status_desc,
    license_num,
    country_key,
    country_contact_num
)
SELECT
    v.VEN_ACC,
    v.VEN_NAME,
    v.VEN_TYPE,
    v.VSTAT_DES,
    v.LCNS_NO,
    c.country_key,
    v.CTRY_CON_NO
FROM stg_vendor v
LEFT JOIN dim_country c
    ON v.CTRY_CD = c.country_code;
    
SELECT *
FROM stg_vendor
WHERE VEN_ACC = 'HA804814252';

SELECT
    country_code,
    COUNT(*) AS record_count
FROM dim_country
WHERE country_code = (
    SELECT CTRY_CD
    FROM stg_vendor
    WHERE VEN_ACC = 'HA804814252'
    LIMIT 1
)
GROUP BY country_code;
-- ==========================================================================================
-- dim_insurance
-- ==========================================================================================
DROP TABLE IF EXISTS dim_insurance;
CREATE TABLE dim_insurance (
    insurance_key INT AUTO_INCREMENT PRIMARY KEY,

    policy_no VARCHAR(30) NOT NULL,
    patient_key INT NULL,

    insurance_company_name VARCHAR(100),
    insurance_type_code VARCHAR(20),
    insurance_type_desc VARCHAR(100),

    policy_start_date DATE,
    policy_end_date DATE,

    insurance_status_code INT,
    insurance_status_desc VARCHAR(100),

    insurance_contact_no VARCHAR(20),

    UNIQUE KEY uq_insurance_policy_period (
        patient_key, policy_no, policy_start_date, policy_end_date
    ),

    FOREIGN KEY (patient_key)
        REFERENCES dim_patient(patient_key)
);

INSERT INTO dim_insurance (
    policy_no,
    patient_key,
    insurance_company_name,
    insurance_type_code,
    insurance_type_desc,
    policy_start_date,
    policy_end_date,
    insurance_status_code,
    insurance_status_desc,
    insurance_contact_no
)
SELECT DISTINCT
    i.POL_NO,
    p.patient_key,
    i.COM_NAME,
    i.ITYPE_CD,
    i.ITYPE_DES,
    STR_TO_DATE(i.POL_ST, '%c/%e/%Y %H:%i'),
    STR_TO_DATE(i.POL_ED, '%c/%e/%Y %H:%i'),
    i.ISTAT_CD,
    i.ISTAT_DES,
    i.CON_NO
FROM stg_insurance i
LEFT JOIN dim_patient p
    ON i.PAT_ID = p.patient_id;

-- ==========================================================================================
-- dim_date
-- ==========================================================================================
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,

    day INT NOT NULL,
    day_of_week_num INT NOT NULL,
    day_of_week_name VARCHAR(10) NOT NULL,

    month INT NOT NULL,
    month_name VARCHAR(10) NOT NULL,

    quarter INT NOT NULL,
    year INT NOT NULL,

    is_weekend TINYINT(1) NOT NULL
);

-- Populate table (2000 - 2035)
INSERT INTO dim_date (
    date_key,
    full_date,
    day,
    day_of_week_num,
    day_of_week_name,
    month,
    month_name,
    quarter,
    year,
    is_weekend
)
SELECT
    CAST(DATE_FORMAT(d.full_date, '%Y%m%d') AS UNSIGNED),
    d.full_date,
    DAY(d.full_date),
    WEEKDAY(d.full_date) + 1,
    DAYNAME(d.full_date),
    MONTH(d.full_date),
    MONTHNAME(d.full_date),
    QUARTER(d.full_date),
    YEAR(d.full_date),
    IF(WEEKDAY(d.full_date) >= 5, 1, 0)
FROM (
    SELECT DATE_ADD('2000-01-01', INTERVAL n DAY) AS full_date
    FROM (
        SELECT
            a.n + (b.n * 10) + (c.n * 100) +
            (d.n * 1000) + (e.n * 10000) AS n
        FROM
            (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
        CROSS JOIN
            (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
        CROSS JOIN
            (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
        CROSS JOIN
            (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
        CROSS JOIN
            (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) e
    ) numbers
    WHERE n <= DATEDIFF('2035-12-31', '2000-01-01')
) d;

-- ==========================================================================================
-- dim_inventory
-- Grain: one row per distinct MAT_SKU
-- ==========================================================================================
DROP TABLE IF EXISTS dim_inventory;
CREATE TABLE dim_inventory (
    inventory_key INT AUTO_INCREMENT PRIMARY KEY,
    material_sku VARCHAR(50) NOT NULL,
    UNIQUE (material_sku)
);

INSERT INTO dim_inventory (
    material_sku
)
SELECT DISTINCT
    MAT_SKU
FROM stg_inventory
WHERE MAT_SKU IS NOT NULL;

-- =============================================
-- 4. BRIDGE TABLES
-- =============================================

-- ==========================================================================================
-- bridge_staff_id_resolution
-- ==========================================================================================
DROP TABLE IF EXISTS bridge_staff_id_resolution;
CREATE TABLE IF NOT EXISTS bridge_staff_id_resolution (
    staff_id               VARCHAR(20)  NOT NULL,
    staff_id_row_count     INT          NOT NULL,
    doctor_candidates      INT          NOT NULL,
    staff_key_default      INT          NOT NULL,
    staff_key_appointment  INT          NOT NULL,
    resolution_rule        VARCHAR(40)  NOT NULL,
    PRIMARY KEY (staff_id)
);

-- Bridge: one row per staff_id
INSERT INTO bridge_staff_id_resolution
    (staff_id, staff_id_row_count, doctor_candidates,
     staff_key_default, staff_key_appointment, resolution_rule)
SELECT
    s.staff_id,
    COUNT(*),
    SUM(s.role_desc = 'Doctor'),
    CASE WHEN COUNT(*) = 1 THEN MAX(s.staff_key)
         ELSE -1
    END,
    CASE WHEN COUNT(*) = 1 THEN MAX(s.staff_key)
         WHEN SUM(s.role_desc = 'Doctor') = 1
              THEN MAX(CASE WHEN s.role_desc = 'Doctor' THEN s.staff_key END)
         ELSE -1
    END,
    CASE WHEN COUNT(*) = 1 THEN 'UNIQUE_ID'
         WHEN SUM(s.role_desc = 'Doctor') = 1 THEN 'SHARED_ID_RESOLVED_BY_DOCTOR_ROLE'
         ELSE 'SHARED_ID_UNRESOLVED'
    END
FROM dim_staff s
WHERE s.staff_key <> -1
GROUP BY s.staff_id;

-- ==========================================================================================
-- bridge_room_id_resolution
-- ==========================================================================================
DROP TABLE IF EXISTS bridge_room_id_resolution;
CREATE TABLE IF NOT EXISTS bridge_room_id_resolution (
    room_id VARCHAR(20) NOT NULL PRIMARY KEY,
    room_id_row_count INT NOT NULL,
    room_key_default INT NOT NULL,
    room_key_visit INT NOT NULL,
    resolution_rule VARCHAR(40) NOT NULL
);

-- Populate the bridge
INSERT INTO bridge_room_id_resolution (
    room_id, room_id_row_count,
    room_key_default, room_key_visit, resolution_rule
)
SELECT
    room_id,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 1 THEN MAX(room_key)
        ELSE -1
    END,
    CASE
        WHEN COUNT(*) = 1 THEN MAX(room_key)
        ELSE -1
    END,
    CASE
        WHEN COUNT(*) = 1 THEN 'UNIQUE_ID'
        ELSE 'SHARED_ID_UNRESOLVED'
    END
FROM dim_room
WHERE room_key <> -1
GROUP BY room_id;

-- ==========================================================================================
-- bridge_medical_team_staff
-- Grain: One staff member assigned to one role within one medical team.
-- ==========================================================================================
DROP TABLE IF EXISTS bridge_medical_team_staff;
CREATE TABLE bridge_medical_team_staff (
    medical_team_staff_key INT AUTO_INCREMENT PRIMARY KEY,

    medical_team_id VARCHAR(20) NOT NULL,
    team_no INT NOT NULL,

    source_staff_id VARCHAR(20) NOT NULL,
    staff_key INT NULL,

    role_code INT NOT NULL,
    role_desc VARCHAR(50) NOT NULL,

    UNIQUE KEY uq_medical_team_staff (
        medical_team_id,
        team_no,
        source_staff_id,
        role_code
    ),

    FOREIGN KEY (staff_key)
        REFERENCES dim_staff(staff_key)
);

-- Populate table
INSERT INTO bridge_medical_team_staff (
    medical_team_id,
    team_no,
    source_staff_id,
    staff_key,
    role_code,
    role_desc
)
SELECT DISTINCT
    mt.MEDT_ID,
    mt.TEAM_NO,
    mt.STF_ID,
    s.staff_key,
    mt.ROLE_CD,
    mt.ROLE_DES
FROM stg_medical_team mt
LEFT JOIN (
    SELECT
        staff_id,
        MIN(staff_key) AS staff_key
    FROM dim_staff
    WHERE staff_key <> -1
    GROUP BY staff_id
    HAVING COUNT(*) = 1
) s
    ON mt.STF_ID = s.staff_id;

-- addtl. notes: 9740 unresolved records (3.11%) of the bridge table have duplicate staff_id 
-- shared by diff. indivs in dim_staff, making reliable identification using staff_id alone
-- retained NULL in staff_key to avoid incorrect staff assignments
-- preserved for traceability

-- ==========================================================================================
-- bridge_patient_allergy
-- ==========================================================================================
DROP TABLE IF EXISTS bridge_patient_allergy;
CREATE TABLE bridge_patient_allergy (
    patient_allergy_key INT AUTO_INCREMENT PRIMARY KEY,

    source_patient_id VARCHAR(20) NOT NULL,
    patient_key INT NULL,

    source_allergy_id INT NOT NULL,
    allergy_key INT NULL,

    severity_code INT,
    severity_desc VARCHAR(20),

    reaction_code INT,
    reaction_desc VARCHAR(20),

    FOREIGN KEY (patient_key)
        REFERENCES dim_patient(patient_key),

    FOREIGN KEY (allergy_key)
        REFERENCES dim_allergy(allergy_key)
);

INSERT INTO bridge_patient_allergy (
    source_patient_id,
    patient_key,
    source_allergy_id,
    allergy_key,
    severity_code,
    severity_desc,
    reaction_code,
    reaction_desc
)
SELECT DISTINCT
    pa.PAT_ID,
    p.patient_key,
    pa.ALG_ID,
    a.allergy_key,
    pa.SVR_CD,
    pa.SVR_DES,
    pa.RCT_CD,
    pa.RCT_DES
FROM stg_patient_allergy pa
LEFT JOIN dim_patient p
    ON pa.PAT_ID = p.patient_id
LEFT JOIN dim_allergy a
    ON pa.ALG_ID = a.allergy_id;