USE healthcare;

-- =============================================
-- 1. CORE DIMENSIONS
-- =============================================

--
-- dim_patient
--
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

--
-- dim_role
--
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
--
-- dim_department
--
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

--
-- dim_room
--
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

-- dim_vendor
-- dim_insurance
-- dim_medical_team
-- dim_inventory_item

-- =============================================
-- 4. BRIDGE TABLES
-- =============================================

-- bridge_patient_allergy
-- bridge_medical_team_staff