USE healthcare;

-- =============================================
-- 1. CORE DIMENSIONS
-- =============================================

-- dim_patient

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

-- dim_staff

CREATE TABLE IF NOT EXISTS dim_example (
    example_key INT AUTO_INCREMENT PRIMARY KEY,
    example_id VARCHAR(20) NOT NULL,
    example_name VARCHAR(100),

    UNIQUE (example_id)
);

-- Populate dimension
INSERT INTO dim_example (
    example_id,
    example_name
)
SELECT
    EXAMPLE_ID,
    EXAMPLE_NAME
FROM stg_example;

-- dim_department
-- dim_room

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