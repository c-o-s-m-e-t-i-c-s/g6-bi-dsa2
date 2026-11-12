USE healthcare;

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
--
-- dim_staff
--
DROP TABLE IF EXISTS bridge_staff_id_resolution;
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

CREATE TABLE bridge_staff_id_resolution (
    staff_id               VARCHAR(20)  NOT NULL,
    staff_id_row_count     INT          NOT NULL,
    doctor_candidates      INT          NOT NULL,
    staff_key_default      INT          NOT NULL,
    staff_key_appointment  INT          NOT NULL,
    resolution_rule        VARCHAR(40)  NOT NULL,
    PRIMARY KEY (staff_id)
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

-- SANITY CHECK FOR VALIDATION
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_staff rows = stg_staff rows + 1 Unknown member' AS check_name,
           (SELECT COUNT(*) FROM dim_staff) AS found,
           (SELECT COUNT(*) FROM stg_staff) + 1 AS expected
    UNION ALL
    SELECT 'staff_key is unique',
           (SELECT COUNT(DISTINCT staff_key) FROM dim_staff),
           (SELECT COUNT(*) FROM dim_staff)
    UNION ALL
    SELECT 'bridge rows = distinct STF_ID in stg_staff',
           (SELECT COUNT(*) FROM bridge_staff_id_resolution),
           (SELECT COUNT(DISTINCT STF_ID) FROM stg_staff)
    UNION ALL
    SELECT 'dates loaded: stg_staff rows with HIRE_DATE vs dim_staff hire_date',
           (SELECT COUNT(hire_date) FROM dim_staff WHERE staff_key <> -1),
           (SELECT COUNT(HIRE_DATE) FROM stg_staff)
    UNION ALL
    SELECT 'appointments with missing or unresolved doctor (expect 0)',
           (SELECT COUNT(*)
            FROM stg_appointment a
            LEFT JOIN bridge_staff_id_resolution b ON a.DOC_ID = b.staff_id
            WHERE b.staff_id IS NULL OR b.staff_key_appointment = -1),
           0
) t;
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

-- Create resolution bridge
CREATE TABLE bridge_room_id_resolution (
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

-- =============================================
-- 3. BUSINESS DIMENSIONS
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
-- dim_diagnosis
-- ==========================================================================================
DROP TABLE IF EXISTS dim_diagnosis;
CREATE TABLE IF NOT EXISTS dim_diagnosis (
    diagnosis_key INT AUTO_INCREMENT PRIMARY KEY,

    diagnosis_code VARCHAR(20) NOT NULL,
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
-- dim_treatment
-- ==========================================================================================

-- ==========================================================================================
-- dim_date
-- ==========================================================================================

-- ==========================================================================================
-- dim_medical_team
-- ==========================================================================================

-- ==========================================================================================
-- dim_inventory
-- ==========================================================================================

-- =============================================
-- 4. BRIDGE TABLES
-- =============================================

-- bridge_patient_allergy
-- bridge_medical_team_staff