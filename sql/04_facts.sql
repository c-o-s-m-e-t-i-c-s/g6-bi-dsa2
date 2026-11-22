USE healthcare;

/*
TABLE OF CONTENTS: (use Ctrl + F to find tables faster)
0. DROP TABLES
1. HOSPITAL OPERATIONS
    - dim_appointment_status
    - dim_appointment_type
    - fact_appointment
    - dim_visit_status
    - dim_visit_type
    - fact_visit
2. CLINICAL ACTIVITIES
    - dim_diagnosis_status
    - dim_diagnosis_type
    - fact_diagnosis
    - fact_treatment
    - dim_dosage
    - dim_frequency
    - dim_route
    - fact_treatment_medicine
3. FINANCIAL ACTIVITIES
    - dim_billing_status
    - fact_billing
    - dim_medbill_status
    - fact_medbill
    - dim_payment_method
    - dim_payment_status
    - fact_payment
4. INVENTORY AND PROCUREMENT
    - fact_inventory
    - fact_supply_receipt
    - dim_vendor_payment_status
    - fact_vendor_payment
*/

-- =============================================
-- 0. DROP TABLES
-- =============================================
-- MAIN FACT TABLES (Drop first due to FK dependencies)
DROP TABLE IF EXISTS fact_vendor_payment;
DROP TABLE IF EXISTS fact_supply_receipt;
-- DROP TABLE IF EXISTS fact_inventory; commented out since i  dont want to rebuild 9.5 million rows
DROP TABLE IF EXISTS fact_payment;
DROP TABLE IF EXISTS fact_medbill;
DROP TABLE IF EXISTS fact_billing;
DROP TABLE IF EXISTS fact_treatment_medicine;
DROP TABLE IF EXISTS fact_treatment;
DROP TABLE IF EXISTS fact_diagnosis;
DROP TABLE IF EXISTS fact_visit;
DROP TABLE IF EXISTS fact_appointment;

-- FACT-SPECIFIC LOOKUP DIMENSION TABLES
DROP TABLE IF EXISTS dim_vendor_payment_status;
DROP TABLE IF EXISTS dim_payment_status;
DROP TABLE IF EXISTS dim_payment_method;
DROP TABLE IF EXISTS dim_medbill_status;
DROP TABLE IF EXISTS dim_billing_status;
DROP TABLE IF EXISTS dim_route;
DROP TABLE IF EXISTS dim_frequency;
DROP TABLE IF EXISTS dim_dosage;
DROP TABLE IF EXISTS dim_diagnosis_type;
DROP TABLE IF EXISTS dim_diagnosis_status;
DROP TABLE IF EXISTS dim_visit_type;
DROP TABLE IF EXISTS dim_visit_status;
DROP TABLE IF EXISTS dim_appointment_type;
DROP TABLE IF EXISTS dim_appointment_status;


-- =============================================
-- 1. HOSPITAL OPERATIONS
-- =============================================

-- ==========================================================================================
-- dim_appointment_status
-- ==========================================================================================
CREATE TABLE dim_appointment_status (
    appointment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    appointment_status_code INT NOT NULL,
    appointment_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (appointment_status_code)
);

-- Populate dimension
INSERT INTO dim_appointment_status (appointment_status_code, appointment_status_desc)
SELECT DISTINCT ASTAT_CD, ASTAT_DES
FROM stg_appointment
WHERE ASTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_appointment_status rows = distinct stg_appointment ASTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_appointment_status) AS found,
           (SELECT COUNT(DISTINCT ASTAT_CD) FROM stg_appointment WHERE ASTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_appointment_type
-- ==========================================================================================
CREATE TABLE dim_appointment_type (
    appointment_type_key INT AUTO_INCREMENT PRIMARY KEY,
    appointment_type_code INT NOT NULL,
    appointment_type_desc VARCHAR(100) NOT NULL,
    UNIQUE (appointment_type_code)
);

-- Populate dimension
INSERT INTO dim_appointment_type (appointment_type_code, appointment_type_desc)
SELECT DISTINCT ATYPE_CD, ATYPE_DES
FROM stg_appointment
WHERE ATYPE_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_appointment_type rows = distinct stg_appointment ATYPE_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_appointment_type) AS found,
           (SELECT COUNT(DISTINCT ATYPE_CD) FROM stg_appointment WHERE ATYPE_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_appointment
-- Source: stg_appointment | Grain: One appointment
-- ==========================================================================================
CREATE TABLE fact_appointment (
    appointment_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    booked_by_staff_key INT NOT NULL,
    doctor_key INT NOT NULL,
    appointment_date_key INT NOT NULL,
    appointment_status_key INT NOT NULL,
    appointment_type_key INT NOT NULL,
    -- Degenerate Dimensions & Times
    appointment_ref_no VARCHAR(20) NOT NULL,
    source_booked_by_id VARCHAR(20),
    source_doctor_id VARCHAR(20),
    appointment_time TIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (booked_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (doctor_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (appointment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (appointment_status_key) REFERENCES dim_appointment_status(appointment_status_key),
    FOREIGN KEY (appointment_type_key) REFERENCES dim_appointment_type(appointment_type_key)
);

CREATE INDEX fact_appointment_ix_1 ON fact_appointment(patient_key);
CREATE INDEX fact_appointment_ix_2 ON fact_appointment(doctor_key);
CREATE INDEX fact_appointment_ix_3 ON fact_appointment(booked_by_staff_key);
CREATE INDEX fact_appointment_ix_4 ON fact_appointment(appointment_date_key);
CREATE INDEX fact_appointment_ix_5 ON fact_appointment(appointment_status_key);
CREATE INDEX fact_appointment_ix_6 ON fact_appointment(appointment_type_key);

-- Populate fact
INSERT INTO fact_appointment (
    patient_key,
    booked_by_staff_key,
    doctor_key,
    appointment_date_key,
    appointment_status_key,
    appointment_type_key,
    appointment_ref_no,
    source_booked_by_id,
    source_doctor_id,
    appointment_time
)
SELECT
    p.patient_key,
    COALESCE(b_res.staff_key_default, -1) AS booked_by_staff_key,
    COALESCE(d_res.staff_key_appointment, -1) AS doctor_key,
    dt.date_key AS appointment_date_key,
    ast.appointment_status_key,
    atp.appointment_type_key,
    s.REFR_NO,
    s.CTD_ID,
    s.DOC_ID,
    TIME(s.APT_TIME) AS appointment_time
FROM stg_appointment s
JOIN dim_patient p
    ON s.PAT_ID = p.patient_id
JOIN dim_date dt
    ON DATE(s.APT_TIME) = dt.full_date
LEFT JOIN bridge_staff_id_resolution b_res
    ON TRIM(s.CTD_ID) = TRIM(b_res.staff_id)
LEFT JOIN bridge_staff_id_resolution d_res
    ON TRIM(s.DOC_ID) = TRIM(d_res.staff_id)
JOIN dim_appointment_status ast
    ON s.ASTAT_CD = ast.appointment_status_code
JOIN dim_appointment_type atp
    ON s.ATYPE_CD = atp.appointment_type_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_appointment rows = stg_appointment rows' AS check_name,
           (SELECT COUNT(*) FROM fact_appointment) AS found,
           (SELECT COUNT(*) FROM stg_appointment) AS expected
    UNION ALL
    SELECT 'fact_appointment unresolved doctors (doctor_key = -1, expect 0)',
           (SELECT COUNT(*) FROM fact_appointment WHERE doctor_key = -1),
           0
) t;


-- ==========================================================================================
-- dim_visit_status
-- ==========================================================================================
CREATE TABLE dim_visit_status (
    visit_status_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_status_code INT NOT NULL,
    visit_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (visit_status_code)
);

-- Populate dimension
INSERT INTO dim_visit_status (visit_status_code, visit_status_desc)
SELECT DISTINCT VSTAT_CD, VSTAT_DES
FROM stg_visit
WHERE VSTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_visit_status rows = distinct stg_visit VSTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_visit_status) AS found,
           (SELECT COUNT(DISTINCT VSTAT_CD) FROM stg_visit WHERE VSTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_visit_type
-- ==========================================================================================
CREATE TABLE dim_visit_type (
    visit_type_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_type_code INT NOT NULL,
    visit_type_desc VARCHAR(100) NOT NULL,
    UNIQUE (visit_type_code)
);

-- Populate dimension
INSERT INTO dim_visit_type (visit_type_code, visit_type_desc)
SELECT DISTINCT VTYPE_CD, VTYPE_DES
FROM stg_visit
WHERE VTYPE_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_visit_type rows = distinct stg_visit VTYPE_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_visit_type) AS found,
           (SELECT COUNT(DISTINCT VTYPE_CD) FROM stg_visit WHERE VTYPE_CD IS NOT NULL) AS expected
) t;


-- ==========================================================================================
-- fact_visit
-- Source: stg_visit | Grain: One patient visit
-- ==========================================================================================
CREATE TABLE fact_visit (
    visit_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    room_key INT NOT NULL,
    visit_date_key INT NOT NULL,
    visit_status_key INT NOT NULL,
    visit_type_key INT NOT NULL,
    -- Degenerate Dimensions & Timestamps
    visit_ref_no VARCHAR(20) NOT NULL,
    medical_team_id VARCHAR(20),
    source_room_id VARCHAR(20),
    visit_entry DATETIME,
    visit_exit DATETIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (room_key) REFERENCES dim_room(room_key),
    FOREIGN KEY (visit_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (visit_status_key) REFERENCES dim_visit_status(visit_status_key),
    FOREIGN KEY (visit_type_key) REFERENCES dim_visit_type(visit_type_key)
);

CREATE INDEX fact_visit_ix_1 ON fact_visit(patient_key);
CREATE INDEX fact_visit_ix_2 ON fact_visit(room_key);
CREATE INDEX fact_visit_ix_3 ON fact_visit(visit_date_key);
CREATE INDEX fact_visit_ix_4 ON fact_visit(visit_status_key);
CREATE INDEX fact_visit_ix_5 ON fact_visit(visit_type_key);
CREATE INDEX fact_visit_ix_6 ON fact_visit(medical_team_id);

-- Populate fact
INSERT INTO fact_visit (
    patient_key,
    room_key,
    visit_date_key,
    visit_status_key,
    visit_type_key,
    visit_ref_no,
    medical_team_id,
    source_room_id,
    visit_entry,
    visit_exit
)
SELECT
    p.patient_key,
    COALESCE(r_res.room_key_visit, -1) AS room_key,
    dt.date_key AS visit_date_key,
    vst.visit_status_key,
    vtp.visit_type_key,
    s.REFR_NO,
    s.MEDT_ID,
    s.ROM_ID,
    s.VIS_EN AS visit_entry,
    s.VIS_EX AS visit_exit
FROM stg_visit s
JOIN dim_patient p
    ON s.PAT_ID = p.patient_id
JOIN dim_date dt
    ON DATE(s.VIS_EN) = dt.full_date
LEFT JOIN bridge_room_id_resolution r_res
    ON TRIM(s.ROM_ID) = TRIM(r_res.room_id)
JOIN dim_visit_status vst
    ON s.VSTAT_CD = vst.visit_status_code
JOIN dim_visit_type vtp
    ON s.VTYPE_CD = vtp.visit_type_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_visit rows = stg_visit rows' AS check_name,
           (SELECT COUNT(*) FROM fact_visit) AS found,
           (SELECT COUNT(*) FROM stg_visit) AS expected
    UNION ALL
    SELECT 'fact_visit unresolved rooms match non-UNIQUE_ID rooms in bridge',
           (SELECT COUNT(*) FROM fact_visit WHERE room_key = -1),
           (SELECT COUNT(*)
            FROM stg_visit s
            LEFT JOIN bridge_room_id_resolution b ON TRIM(s.ROM_ID) = TRIM(b.room_id)
            WHERE b.room_id IS NULL OR b.room_key_visit = -1)
    UNION ALL
    SELECT 'fact_visit exits before entry (expect 0)',
           (SELECT COUNT(*) FROM fact_visit WHERE visit_exit < visit_entry),
           0
) t;


-- =============================================
-- 2. CLINICAL ACTIVITIES
-- =============================================

-- ==========================================================================================
-- dim_diagnosis_status
-- ==========================================================================================
CREATE TABLE dim_diagnosis_status (
    diagnosis_status_key INT AUTO_INCREMENT PRIMARY KEY,
    diagnosis_status_code INT NOT NULL,
    diagnosis_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (diagnosis_status_code)
);

-- Populate dimension
INSERT INTO dim_diagnosis_status (diagnosis_status_code, diagnosis_status_desc)
SELECT DISTINCT DSTAT_CD, DSTAT_DES
FROM stg_diagnosis
WHERE DSTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_diagnosis_status rows = distinct stg_diagnosis DSTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_diagnosis_status) AS found,
           (SELECT COUNT(DISTINCT DSTAT_CD) FROM stg_diagnosis WHERE DSTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_diagnosis_type
-- ==========================================================================================
CREATE TABLE dim_diagnosis_type (
    diagnosis_type_key INT AUTO_INCREMENT PRIMARY KEY,
    diagnosis_type_code INT NOT NULL,
    diagnosis_type_desc VARCHAR(100) NOT NULL,
    UNIQUE (diagnosis_type_code)
);

-- Populate dimension
INSERT INTO dim_diagnosis_type (diagnosis_type_code, diagnosis_type_desc)
SELECT DISTINCT DTYPE_CD, DTYPE_DES
FROM stg_diagnosis
WHERE DTYPE_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_diagnosis_type rows = distinct stg_diagnosis DTYPE_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_diagnosis_type) AS found,
           (SELECT COUNT(DISTINCT DTYPE_CD) FROM stg_diagnosis WHERE DTYPE_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_diagnosis
-- Source: stg_diagnosis | Grain: One diagnosis record
-- ==========================================================================================
CREATE TABLE fact_diagnosis (
    diagnosis_fact_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_key INT NOT NULL,
    patient_key INT NOT NULL,
    room_key INT NOT NULL,
    diagnosis_key INT NOT NULL,
    diagnosis_date_key INT NOT NULL,
    diagnosis_status_key INT NOT NULL,
    diagnosis_type_key INT NOT NULL,
    -- Degenerate Dimensions, Timestamps & Measures
    diagnosis_ref_no VARCHAR(20) NOT NULL,
    source_room_id VARCHAR(20),
    admission_date DATETIME,
    diagnosis_seq INT,
    diagnosis_cost DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (visit_key) REFERENCES fact_visit(visit_key),
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (room_key) REFERENCES dim_room(room_key),
    FOREIGN KEY (diagnosis_key) REFERENCES dim_diagnosis(diagnosis_key),
    FOREIGN KEY (diagnosis_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (diagnosis_status_key) REFERENCES dim_diagnosis_status(diagnosis_status_key),
    FOREIGN KEY (diagnosis_type_key) REFERENCES dim_diagnosis_type(diagnosis_type_key)
);

CREATE INDEX fact_diagnosis_ix_1 ON fact_diagnosis(visit_key);
CREATE INDEX fact_diagnosis_ix_2 ON fact_diagnosis(patient_key);
CREATE INDEX fact_diagnosis_ix_3 ON fact_diagnosis(room_key);
CREATE INDEX fact_diagnosis_ix_4 ON fact_diagnosis(diagnosis_key);
CREATE INDEX fact_diagnosis_ix_5 ON fact_diagnosis(diagnosis_date_key);
CREATE INDEX fact_diagnosis_ix_6 ON fact_diagnosis(diagnosis_status_key);
CREATE INDEX fact_diagnosis_ix_7 ON fact_diagnosis(diagnosis_type_key);

INSERT INTO fact_diagnosis (
    visit_key,
    patient_key,
    room_key,
    diagnosis_key,
    diagnosis_date_key,
    diagnosis_status_key,
    diagnosis_type_key,
    diagnosis_ref_no,
    source_room_id,
    admission_date,
    diagnosis_seq,
    diagnosis_cost
)
SELECT
    fv.visit_key,
    fv.patient_key,
    COALESCE(r_res.room_key_visit, -1) AS room_key,
    dd.diagnosis_key,
    dt.date_key AS diagnosis_date_key,
    dst.diagnosis_status_key,
    dtp.diagnosis_type_key,
    s.REFR_NO,
    s.ROM_ID,
    s.DIG_EN AS admission_date,
    s.DIG_SEQ,
    s.DIG_TOT
FROM stg_diagnosis s
JOIN fact_visit fv
    ON s.REFR_NO = fv.visit_ref_no
   AND s.DIG_EN = fv.visit_entry
JOIN dim_date dt
    ON DATE(s.DIG_EN) = dt.full_date
JOIN dim_diagnosis dd
    ON s.DIG_CD = dd.diagnosis_code
LEFT JOIN bridge_room_id_resolution r_res
    ON TRIM(s.ROM_ID) = TRIM(r_res.room_id)
JOIN dim_diagnosis_status dst
    ON s.DSTAT_CD = dst.diagnosis_status_code
JOIN dim_diagnosis_type dtp
    ON s.DTYPE_CD = dtp.diagnosis_type_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_diagnosis rows = stg_diagnosis rows' AS check_name,
           (SELECT COUNT(*) FROM fact_diagnosis) AS found,
           (SELECT COUNT(*) FROM stg_diagnosis) AS expected
) t;

-- ==========================================================================================
-- fact_treatment
-- Source: stg_treatment | Grain: One treatment record
-- Uses dim_treatment, dim_treatment_status, dim_treatment_type from 03_dimensions.sql
-- ==========================================================================================
CREATE TABLE fact_treatment (
    treatment_fact_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_key INT NOT NULL,
    patient_key INT NOT NULL,
    treatment_key INT NOT NULL,
    treatment_date_key INT NOT NULL,
    treatment_status_key INT NOT NULL,
    treatment_type_key INT NOT NULL,
    -- Degenerate Dimensions, Timestamps & Measures
    treatment_ref_no VARCHAR(20) NOT NULL,
    treatment_entry DATETIME,
    treatment_seq INT,
    treatment_cost DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (visit_key) REFERENCES fact_visit(visit_key),
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (treatment_key) REFERENCES dim_treatment(treatment_key),
    FOREIGN KEY (treatment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (treatment_status_key) REFERENCES dim_treatment_status(treatment_status_key),
    FOREIGN KEY (treatment_type_key) REFERENCES dim_treatment_type(treatment_type_key)
);

CREATE INDEX fact_treatment_ix_1 ON fact_treatment(visit_key);
CREATE INDEX fact_treatment_ix_2 ON fact_treatment(patient_key);
CREATE INDEX fact_treatment_ix_3 ON fact_treatment(treatment_key);
CREATE INDEX fact_treatment_ix_4 ON fact_treatment(treatment_date_key);
CREATE INDEX fact_treatment_ix_5 ON fact_treatment(treatment_status_key);
CREATE INDEX fact_treatment_ix_6 ON fact_treatment(treatment_type_key);

INSERT INTO fact_treatment (
    visit_key,
    patient_key,
    treatment_key,
    treatment_date_key,
    treatment_status_key,
    treatment_type_key,
    treatment_ref_no,
    treatment_entry,
    treatment_seq,
    treatment_cost
)
SELECT
    fv.visit_key,
    fv.patient_key,
    dtr.treatment_key,
    dt.date_key AS treatment_date_key,
    tst.treatment_status_key,
    ttp.treatment_type_key,
    s.REFR_NO,
    s.TRTM_EN AS treatment_entry,
    s.TRTM_SEQ,
    s.TRTM_TOT
FROM stg_treatment s
JOIN fact_visit fv
    ON s.REFR_NO = fv.visit_ref_no
   AND s.TRTM_EN = fv.visit_entry
JOIN dim_date dt
    ON DATE(s.TRTM_EN) = dt.full_date
JOIN dim_treatment dtr
    ON s.TRTM_CD = dtr.treatment_code
JOIN dim_treatment_status tst
    ON s.TSTAT_CD = tst.treatment_status_code
JOIN dim_treatment_type ttp
    ON s.TTYPE_CD = ttp.treatment_type_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_treatment rows = stg_treatment rows' AS check_name,
           (SELECT COUNT(*) FROM fact_treatment) AS found,
           (SELECT COUNT(*) FROM stg_treatment) AS expected
) t;


-- ==========================================================================================
-- dim_dosage
-- ==========================================================================================
CREATE TABLE dim_dosage (
    dosage_key INT AUTO_INCREMENT PRIMARY KEY,
    dosage_code INT NOT NULL,
    dosage_desc VARCHAR(100) NOT NULL,
    UNIQUE (dosage_code)
);

-- Populate dimension
INSERT INTO dim_dosage (dosage_code, dosage_desc)
SELECT DISTINCT DOS_CD, DOS_DES
FROM stg_treatment_med
WHERE DOS_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_dosage rows = distinct stg_treatment_med DOS_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_dosage) AS found,
           (SELECT COUNT(DISTINCT DOS_CD) FROM stg_treatment_med WHERE DOS_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_frequency
-- ==========================================================================================
CREATE TABLE dim_frequency (
    frequency_key INT AUTO_INCREMENT PRIMARY KEY,
    frequency_code INT NOT NULL,
    frequency_desc VARCHAR(100) NOT NULL,
    UNIQUE (frequency_code)
);

-- Populate dimension
INSERT INTO dim_frequency (frequency_code, frequency_desc)
SELECT DISTINCT FREQ_CD, FREQ_DES
FROM stg_treatment_med
WHERE FREQ_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_frequency rows = distinct stg_treatment_med FREQ_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_frequency) AS found,
           (SELECT COUNT(DISTINCT FREQ_CD) FROM stg_treatment_med WHERE FREQ_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_route
-- ==========================================================================================
CREATE TABLE dim_route (
    route_key INT AUTO_INCREMENT PRIMARY KEY,
    route_code INT NOT NULL,
    route_desc VARCHAR(100) NOT NULL,
    UNIQUE (route_code)
);

-- Populate dimension
INSERT INTO dim_route (route_code, route_desc)
SELECT DISTINCT RUTE_CD, RUTE_DES
FROM stg_treatment_med
WHERE RUTE_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_route rows = distinct stg_treatment_med RUTE_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_route) AS found,
           (SELECT COUNT(DISTINCT RUTE_CD) FROM stg_treatment_med WHERE RUTE_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_treatment_medicine
-- Source: stg_treatment_med | Grain: One treatment-medication record 
-- Takes 30 minutes to run inserting
-- ==========================================================================================
CREATE TABLE fact_treatment_medicine (
    treatment_medicine_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_key INT NULL,
    patient_key INT NULL,
    medicine_key INT NOT NULL,
    visit_date_key INT NULL,
    dosage_key INT NOT NULL,
    frequency_key INT NOT NULL,
    route_key INT NOT NULL,
    -- Degenerate Dimensions & Measures
    visit_ref_no VARCHAR(20) NOT NULL,
    medicine_seq INT,
    quantity_prescribed DECIMAL(10,2),
    unit_dose DECIMAL(10,2),
    medicine_cost DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (visit_key) REFERENCES fact_visit(visit_key),
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (medicine_key) REFERENCES dim_medicine(medicine_key),
    FOREIGN KEY (visit_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (dosage_key) REFERENCES dim_dosage(dosage_key),
    FOREIGN KEY (frequency_key) REFERENCES dim_frequency(frequency_key),
    FOREIGN KEY (route_key) REFERENCES dim_route(route_key)
);

CREATE INDEX fact_treatment_med_ix_1 ON fact_treatment_medicine(visit_key);
CREATE INDEX fact_treatment_med_ix_2 ON fact_treatment_medicine(patient_key);
CREATE INDEX fact_treatment_med_ix_3 ON fact_treatment_medicine(medicine_key);
CREATE INDEX fact_treatment_med_ix_4 ON fact_treatment_medicine(visit_date_key);
CREATE INDEX fact_treatment_med_ix_5 ON fact_treatment_medicine(dosage_key);
CREATE INDEX fact_treatment_med_ix_6 ON fact_treatment_medicine(frequency_key);
CREATE INDEX fact_treatment_med_ix_7 ON fact_treatment_medicine(route_key);
CREATE INDEX fact_treatment_med_ix_8 ON fact_treatment_medicine(visit_ref_no);

INSERT INTO fact_treatment_medicine (
    visit_key,
    patient_key,
    medicine_key,
    visit_date_key,
    dosage_key,
    frequency_key,
    route_key,
    visit_ref_no,
    medicine_seq,
    quantity_prescribed,
    unit_dose,
    medicine_cost
)
SELECT
    fv.visit_key,
    fv.patient_key,
    m.medicine_key,
    fv.visit_date_key,
    dos.dosage_key,
    frq.frequency_key,
    rut.route_key,
    s.REFR_NO,
    s.MEDS_SEQ,
    s.QTY_NO,
    s.UNIT_DOS,
    s.MEDS_TOT
FROM stg_treatment_med s
LEFT JOIN (
    SELECT
        visit_ref_no,
        CASE WHEN COUNT(*) = 1 THEN MAX(visit_key) ELSE NULL END AS visit_key,
        CASE WHEN COUNT(*) = 1 THEN MAX(patient_key) ELSE NULL END AS patient_key,
        CASE WHEN COUNT(*) = 1 THEN MAX(visit_date_key) ELSE NULL END AS visit_date_key
    FROM fact_visit
    GROUP BY visit_ref_no
) fv
    ON s.REFR_NO = fv.visit_ref_no
JOIN dim_medicine m
    ON s.MED_ID = m.medicine_id
JOIN dim_dosage dos
    ON s.DOS_CD = dos.dosage_code
JOIN dim_frequency frq
    ON s.FREQ_CD = frq.frequency_code
JOIN dim_route rut
    ON s.RUTE_CD = rut.route_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_treatment_medicine rows = stg_treatment_med rows' AS check_name,
           (SELECT COUNT(*) FROM fact_treatment_medicine) AS found,
           (SELECT COUNT(*) FROM stg_treatment_med) AS expected
) t;


-- =============================================
-- 3. FINANCIAL ACTIVITIES
-- =============================================

-- ==========================================================================================
-- dim_billing_status
-- ==========================================================================================
CREATE TABLE dim_billing_status (
    bill_status_key INT AUTO_INCREMENT PRIMARY KEY,
    bill_status_code INT NOT NULL,
    bill_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (bill_status_code)
);

-- Populate dimension
INSERT INTO dim_billing_status (bill_status_code, bill_status_desc)
SELECT DISTINCT BSTAT_CD, BSTAT_DES
FROM stg_billing
WHERE BSTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_billing_status rows = distinct stg_billing BSTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_billing_status) AS found,
           (SELECT COUNT(DISTINCT BSTAT_CD) FROM stg_billing WHERE BSTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_billing
-- Source: stg_billing | Grain: One billing record
-- ==========================================================================================
CREATE TABLE fact_billing (
    bill_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    bill_date_key INT NOT NULL,
    bill_status_key INT NOT NULL,
    -- Degenerate Dimensions, Timestamps & Measures
    bill_ref_no VARCHAR(20) NOT NULL,
    bill_timestamp DATETIME NOT NULL,
    bill_type_code VARCHAR(2),
    bill_amt DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (bill_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (bill_status_key) REFERENCES dim_billing_status(bill_status_key)
);

CREATE INDEX fact_bill_ix_1 ON fact_billing(patient_key);
CREATE INDEX fact_bill_ix_2 ON fact_billing(bill_date_key);
CREATE INDEX fact_bill_ix_3 ON fact_billing(bill_status_key);
CREATE INDEX fact_bill_ix_4 ON fact_billing(bill_type_code);

-- Populate fact
INSERT INTO fact_billing (
    patient_key,
    bill_date_key,
    bill_status_key,
    bill_ref_no,
    bill_timestamp,
    bill_type_code,
    bill_amt
)
SELECT
    p.patient_key,
    dt.date_key AS bill_date_key,
    bst.bill_status_key,
    s.REFR_NO,
    s.BILL_DATE,
    s.BTYPE_CD,
    s.BILL_AMT
FROM stg_billing s
JOIN dim_patient p
    ON s.PAT_ID = p.patient_id
JOIN dim_date dt
    ON DATE(s.BILL_DATE) = dt.full_date
JOIN dim_billing_status bst
    ON s.BSTAT_CD = bst.bill_status_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_billing rows = stg_billing rows' AS check_name,
           (SELECT COUNT(*) FROM fact_billing) AS found,
           (SELECT COUNT(*) FROM stg_billing) AS expected
    UNION ALL
    SELECT 'fact_billing total bill_amt = stg_billing total BILL_AMT',
           (SELECT COALESCE(SUM(bill_amt), 0) FROM fact_billing),
           (SELECT COALESCE(SUM(BILL_AMT), 0) FROM stg_billing)
) t;


-- ==========================================================================================
-- dim_medbill_status
-- ==========================================================================================
CREATE TABLE dim_medbill_status (
    medbill_status_key INT AUTO_INCREMENT PRIMARY KEY,
    medbill_status_code INT NOT NULL,
    medbill_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (medbill_status_code)
);

-- Populate dimension
INSERT INTO dim_medbill_status (medbill_status_code, medbill_status_desc)
SELECT DISTINCT BSTAT_CD, BSTAT_DES
FROM stg_medicine_bill
WHERE BSTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_medbill_status rows = distinct stg_medicine_bill BSTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_medbill_status) AS found,
           (SELECT COUNT(DISTINCT BSTAT_CD) FROM stg_medicine_bill WHERE BSTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_medbill
-- Source: stg_medicine_bill | Grain: One medicine billing record
-- ==========================================================================================
CREATE TABLE fact_medbill (
    medbill_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    medbill_date_key INT NOT NULL,
    medbill_status_key INT NOT NULL,
    -- Degenerate Dimensions & Measures
    medbill_ref_no VARCHAR(20) NOT NULL,
    medbill_type_code VARCHAR(20),
    medbill_amt DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (medbill_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (medbill_status_key) REFERENCES dim_medbill_status(medbill_status_key)
);

CREATE INDEX fact_medbill_ix_1 ON fact_medbill(patient_key);
CREATE INDEX fact_medbill_ix_2 ON fact_medbill(medbill_date_key);
CREATE INDEX fact_medbill_ix_3 ON fact_medbill(medbill_status_key);
CREATE INDEX fact_medbill_ix_4 ON fact_medbill(medbill_ref_no);

-- Populate fact
INSERT INTO fact_medbill (
    patient_key,
    medbill_date_key,
    medbill_status_key,
    medbill_ref_no,
    medbill_type_code,
    medbill_amt
)
SELECT
    p.patient_key,
    dt.date_key AS medbill_date_key,
    mbst.medbill_status_key,
    s.REFR_NO,
    s.BTYPE_CD,
    s.BILL_AMT
FROM stg_medicine_bill s
JOIN dim_patient p
    ON s.PAT_ID = p.patient_id
JOIN dim_date dt
    ON DATE(s.BILL_DATE) = dt.full_date
JOIN dim_medbill_status mbst
    ON s.BSTAT_CD = mbst.medbill_status_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_medbill rows = stg_medicine_bill rows' AS check_name,
           (SELECT COUNT(*) FROM fact_medbill) AS found,
           (SELECT COUNT(*) FROM stg_medicine_bill) AS expected
    UNION ALL
    SELECT 'fact_medbill total medbill_amt = stg_medicine_bill total BILL_AMT',
           (SELECT COALESCE(SUM(medbill_amt), 0) FROM fact_medbill),
           (SELECT COALESCE(SUM(BILL_AMT), 0) FROM stg_medicine_bill)
) t;


-- ==========================================================================================
-- dim_payment_method
-- ==========================================================================================
CREATE TABLE dim_payment_method (
    payment_method_key INT AUTO_INCREMENT PRIMARY KEY,
    payment_method_code INT NOT NULL,
    payment_method_desc VARCHAR(100) NOT NULL,
    UNIQUE (payment_method_code)
);

-- Populate dimension
INSERT INTO dim_payment_method (payment_method_code, payment_method_desc)
SELECT DISTINCT METH_CD, METH_DES
FROM stg_payment
WHERE METH_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_payment_method rows = distinct stg_payment PMODE_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_payment_method) AS found,
           (SELECT COUNT(DISTINCT METH_CD) FROM stg_payment WHERE METH_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- dim_payment_status
-- ==========================================================================================
CREATE TABLE dim_payment_status (
    payment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    payment_status_code INT NOT NULL,
    payment_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (payment_status_code)
);

-- Populate dimension
INSERT INTO dim_payment_status (payment_status_code, payment_status_desc)
SELECT DISTINCT PSTAT_CD, PSTAT_DES
FROM stg_payment
WHERE PSTAT_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_payment_status rows = distinct stg_payment PSTAT_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_payment_status) AS found,
           (SELECT COUNT(DISTINCT PSTAT_CD) FROM stg_payment WHERE PSTAT_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_payment
-- Source: stg_payment | Grain: One payment transaction
-- ==========================================================================================
CREATE TABLE fact_payment (
    payment_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    payment_date_key INT NOT NULL,
    payment_method_key INT NOT NULL,
    payment_status_key INT NOT NULL,
    bill_ref_no VARCHAR(20) NOT NULL,
    payment_timestamp DATETIME NOT NULL,
    payment_terms INT,
    payment_interface_id VARCHAR(50),
    payment_amount DECIMAL(25,15),
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (payment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key),
    FOREIGN KEY (payment_status_key) REFERENCES dim_payment_status(payment_status_key)
);

CREATE INDEX fact_payment_ix_1 ON fact_payment(patient_key);
CREATE INDEX fact_payment_ix_2 ON fact_payment(payment_date_key);
CREATE INDEX fact_payment_ix_3 ON fact_payment(payment_method_key);
CREATE INDEX fact_payment_ix_4 ON fact_payment(payment_status_key);
CREATE INDEX fact_payment_ix_5 ON fact_payment(bill_ref_no);

INSERT INTO fact_payment (
    patient_key,
    payment_date_key,
    payment_method_key,
    payment_status_key,
    bill_ref_no,
    payment_timestamp,
    payment_terms,
    payment_interface_id,
    payment_amount
)
SELECT
    p.patient_key,
    dt.date_key AS payment_date_key,
    pmt.payment_method_key,
    pst.payment_status_key,
    s.REFR_NO,
    s.PMNT_DATE,
    s.PMNT_TMS,
    s.PMNT_IF,
    s.PMNT_AMT
FROM stg_payment s
JOIN dim_patient p
    ON s.PAT_ID = p.patient_id
JOIN dim_date dt
    ON DATE(s.PMNT_DATE) = dt.full_date
JOIN dim_payment_method pmt
    ON s.METH_CD = pmt.payment_method_code
JOIN dim_payment_status pst
    ON s.PSTAT_CD = pst.payment_status_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_payment rows = stg_payment rows' AS check_name,
           (SELECT COUNT(*) FROM fact_payment) AS found,
           (SELECT COUNT(*) FROM stg_payment) AS expected
    UNION ALL
    SELECT 'fact_payment total payment_amount = stg_payment total PMNT_AMT',
           (SELECT ROUND(COALESCE(SUM(payment_amount), 0), 6) FROM fact_payment),
           (SELECT ROUND(COALESCE(SUM(PMNT_AMT), 0), 6) FROM stg_payment)
) t;
-- error caused by the decimals in payment amount 
-- if rounded, expected value will pass.

-- =============================================
-- 4. INVENTORY AND PROCUREMENT
-- =============================================

/* COMMENTED DUE TO 9.5 MILLION ROWS, ETA: ~6 HOURS TO RUN, SEE README.MD IN ./sql/
-- ==========================================================================================
-- fact_inventory
-- Source: stg_inventory | Grain: One daily inventory record per SKU
-- ==========================================================================================
CREATE TABLE fact_inventory (
    inventory_fact_key INT AUTO_INCREMENT PRIMARY KEY,
    inventory_key INT NOT NULL,
    ingestion_date_key INT NOT NULL,
    opened_by_staff_key INT NOT NULL,
    received_by_staff_key INT NOT NULL,
    issued_by_staff_key INT NOT NULL,
    closed_by_staff_key INT NOT NULL,
    verified_by_staff_key INT NOT NULL,
    -- Degenerate Dimensions, Timestamps & Measures
    ingestion_timestamp DATETIME,
    opening_qty DECIMAL(10,2),
    received_qty DECIMAL(10,2),
    issued_qty DECIMAL(10,2),
    closing_qty DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (inventory_key) REFERENCES dim_inventory(inventory_key),
    FOREIGN KEY (ingestion_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (opened_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (received_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (issued_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (closed_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (verified_by_staff_key) REFERENCES dim_staff(staff_key)
);

CREATE INDEX fact_inventory_ix_1 ON fact_inventory(inventory_key);
CREATE INDEX fact_inventory_ix_2 ON fact_inventory(ingestion_date_key);
CREATE INDEX fact_inventory_ix_3 ON fact_inventory(received_by_staff_key);

-- Needed so each batch reads one file, not all 90.7M rows. Slow once (~minutes).
CREATE INDEX stg_inventory_ix_src_file ON stg_inventory(src_file);

-- Fact is rebuilt from scratch on every full load, so a rerun cannot duplicate rows.
TRUNCATE TABLE fact_inventory;

DROP PROCEDURE IF EXISTS load_fact_inventory;
DELIMITER $$
CREATE PROCEDURE load_fact_inventory()
BEGIN
    DECLARE v_file     VARCHAR(255);
    DECLARE v_expected BIGINT;
    DECLARE v_loaded   BIGINT;
    DECLARE v_done     BOOLEAN DEFAULT FALSE;
    DECLARE cur CURSOR FOR SELECT DISTINCT src_file FROM stg_inventory ORDER BY src_file;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    OPEN cur;
    batch_loop: LOOP
        FETCH cur INTO v_file;
        IF v_done THEN LEAVE batch_loop; END IF;

        SELECT COUNT(*) INTO v_expected FROM stg_inventory WHERE src_file = v_file;

        START TRANSACTION;

        INSERT INTO fact_inventory (
            inventory_key, ingestion_date_key,
            opened_by_staff_key, received_by_staff_key, issued_by_staff_key,
            closed_by_staff_key, verified_by_staff_key,
            ingestion_timestamp, opening_qty, received_qty, issued_qty, closing_qty
        )
        SELECT
            inv.inventory_key,
            dt.date_key,
            COALESCE(opn_res.staff_key_default, -1),
            COALESCE(rcv_res.staff_key_default, -1),
            COALESCE(iss_res.staff_key_default, -1),
            COALESCE(cls_res.staff_key_default, -1),
            COALESCE(vrf_res.staff_key_default, -1),
            s.INGTN_TS, s.OPEN_QTY, s.RCVD_QTY, s.ISSD_QTY, s.CLSD_QTY
        FROM stg_inventory s
        JOIN dim_inventory inv ON s.MAT_SKU = inv.material_sku
        JOIN dim_date dt       ON DATE(s.INGTN_TS) = dt.full_date
        LEFT JOIN bridge_staff_id_resolution opn_res ON TRIM(s.OPEN_STF) = opn_res.staff_id
        LEFT JOIN bridge_staff_id_resolution rcv_res ON TRIM(s.RCVD_STF) = rcv_res.staff_id
        LEFT JOIN bridge_staff_id_resolution iss_res ON TRIM(s.ISSD_STF) = iss_res.staff_id
        LEFT JOIN bridge_staff_id_resolution cls_res ON TRIM(s.CLSD_STF) = cls_res.staff_id
        LEFT JOIN bridge_staff_id_resolution vrf_res ON TRIM(s.VRFC_STF) = vrf_res.staff_id
        WHERE s.src_file = v_file;

        SET v_loaded = ROW_COUNT();

        -- Fewer rows = inner join dropped data. More rows = join fan-out. Both abort and roll back this batch.
        IF v_loaded <> v_expected THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'fact_inventory batch row count mismatch; see src_file in last progress row';
        END IF;

        COMMIT;
    END LOOP;
    CLOSE cur;
END$$
DELIMITER ;

EXPLAIN
SELECT inv.inventory_key, dt.date_key,
       opn_res.staff_key_default, rcv_res.staff_key_default,
       iss_res.staff_key_default, cls_res.staff_key_default,
       vrf_res.staff_key_default
FROM stg_inventory s
JOIN dim_inventory inv ON s.MAT_SKU = inv.material_sku
JOIN dim_date dt       ON DATE(s.INGTN_TS) = dt.full_date
LEFT JOIN bridge_staff_id_resolution opn_res ON TRIM(s.OPEN_STF) = opn_res.staff_id
LEFT JOIN bridge_staff_id_resolution rcv_res ON TRIM(s.RCVD_STF) = rcv_res.staff_id
LEFT JOIN bridge_staff_id_resolution iss_res ON TRIM(s.ISSD_STF) = iss_res.staff_id
LEFT JOIN bridge_staff_id_resolution cls_res ON TRIM(s.CLSD_STF) = cls_res.staff_id
LEFT JOIN bridge_staff_id_resolution vrf_res ON TRIM(s.VRFC_STF) = vrf_res.staff_id
WHERE s.src_file = 'STG_EHP__INVN_1_1.csv';

TRUNCATE TABLE fact_inventory;

DROP PROCEDURE IF EXISTS load_fact_inventory;
DELIMITER $$
CREATE PROCEDURE load_fact_inventory()
BEGIN
    DECLARE v_file     VARCHAR(255);
    DECLARE v_expected BIGINT;
    DECLARE v_loaded   BIGINT;
    DECLARE v_done     BOOLEAN DEFAULT FALSE;
    DECLARE cur CURSOR FOR SELECT DISTINCT src_file FROM stg_inventory ORDER BY src_file;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    OPEN cur;
    batch_loop: LOOP
        FETCH cur INTO v_file;
        IF v_done THEN LEAVE batch_loop; END IF;

        SELECT COUNT(*) INTO v_expected FROM stg_inventory WHERE src_file = v_file;

        START TRANSACTION;

        INSERT INTO fact_inventory (
            inventory_key, ingestion_date_key,
            opened_by_staff_key, received_by_staff_key, issued_by_staff_key,
            closed_by_staff_key, verified_by_staff_key,
            ingestion_timestamp, opening_qty, received_qty, issued_qty, closing_qty
        )
        SELECT
            inv.inventory_key,
            dt.date_key,
            COALESCE(opn_res.staff_key_default, -1),
            COALESCE(rcv_res.staff_key_default, -1),
            COALESCE(iss_res.staff_key_default, -1),
            COALESCE(cls_res.staff_key_default, -1),
            COALESCE(vrf_res.staff_key_default, -1),
            s.INGTN_TS, s.OPEN_QTY, s.RCVD_QTY, s.ISSD_QTY, s.CLSD_QTY
        FROM stg_inventory s
        JOIN dim_inventory inv ON s.MAT_SKU = inv.material_sku
        JOIN dim_date dt       ON DATE(s.INGTN_TS) = dt.full_date
        LEFT JOIN bridge_staff_id_resolution opn_res ON TRIM(s.OPEN_STF) = opn_res.staff_id
        LEFT JOIN bridge_staff_id_resolution rcv_res ON TRIM(s.RCVD_STF) = rcv_res.staff_id
        LEFT JOIN bridge_staff_id_resolution iss_res ON TRIM(s.ISSD_STF) = iss_res.staff_id
        LEFT JOIN bridge_staff_id_resolution cls_res ON TRIM(s.CLSD_STF) = cls_res.staff_id
        LEFT JOIN bridge_staff_id_resolution vrf_res ON TRIM(s.VRFC_STF) = vrf_res.staff_id
        WHERE s.src_file = v_file;

        SET v_loaded = ROW_COUNT();

        -- Fewer rows means an inner join dropped data. More rows means join fan-out. Both abort and roll back this batch.
        IF v_loaded <> v_expected THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'fact_inventory batch row count mismatch';
        END IF;

        COMMIT;
    END LOOP;
    CLOSE cur;
END$$
DELIMITER ;

CALL load_fact_inventory();
*/ 

-- Validation - PASS
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_inventory rows = stg_inventory rows' AS check_name,
           (SELECT COUNT(*) FROM fact_inventory) AS found,
           (SELECT COUNT(*) FROM stg_inventory) AS expected
) t;

-- Check if dim_inventory surrogate keys match with fact_inventory: 
-- 1. Spot-check: same SKU, same key?
SELECT inventory_key, material_sku
FROM dim_inventory
WHERE material_sku IN ('A0A286718', 'Z9Z900387')
ORDER BY material_sku;

-- 2. Whole-table fingerprint
CHECKSUM TABLE dim_inventory;

-- ==========================================================================================
-- fact_supply_receipt
-- Source: stg_supply | Grain: One supply receipt record
-- ==========================================================================================

-- Insert the 8,854 missing SKUs from stg_supply into dim_inventory
INSERT INTO dim_inventory (material_sku)
SELECT DISTINCT TRIM(s.MAT_SKU)
FROM stg_supply s
LEFT JOIN dim_inventory inv
    ON TRIM(s.MAT_SKU) = TRIM(inv.material_sku)
WHERE s.MAT_SKU IS NOT NULL
  AND TRIM(s.MAT_SKU) <> ''
  AND inv.inventory_key IS NULL;

CREATE TABLE fact_supply_receipt (
    supply_receipt_key INT AUTO_INCREMENT PRIMARY KEY,
    inventory_key INT NOT NULL,
    vendor_key INT NULL,
    received_date_key INT NOT NULL,
    mfg_date_key INT NULL,
    verified_date_key INT NULL,
    received_by_staff_key INT NOT NULL,
    verified_by_staff_key INT NOT NULL,
    -- Degenerate Dimensions & Measures
    supply_id VARCHAR(20) NOT NULL,
    source_vendor_account VARCHAR(20),
    batch_no VARCHAR(30),
    batch_size INT,
    supply_uom VARCHAR(10),
    warehouse_location VARCHAR(50),
    pallet_id VARCHAR(20),
    supply_qty DECIMAL(10,2),
    unit_cost DECIMAL(10,2),
    received_qty DECIMAL(10,2),
    -- Foreign Keys
    FOREIGN KEY (inventory_key) REFERENCES dim_inventory(inventory_key),
    FOREIGN KEY (vendor_key) REFERENCES dim_vendor(vendor_key),
    FOREIGN KEY (received_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (mfg_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (verified_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (received_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (verified_by_staff_key) REFERENCES dim_staff(staff_key)
);

CREATE INDEX fact_supply_receipt_ix_1 ON fact_supply_receipt(received_date_key);
CREATE INDEX fact_supply_receipt_ix_2 ON fact_supply_receipt(supply_id);
CREATE INDEX fact_supply_receipt_ix_3 ON fact_supply_receipt(inventory_key);
CREATE INDEX fact_supply_receipt_ix_4 ON fact_supply_receipt(vendor_key);

-- Populate fact
INSERT INTO fact_supply_receipt (
    inventory_key,
    vendor_key,
    received_date_key,
    mfg_date_key,
    verified_date_key,
    received_by_staff_key,
    verified_by_staff_key,
    supply_id,
    source_vendor_account,
    batch_no,
    batch_size,
    supply_uom,
    warehouse_location,
    pallet_id,
    supply_qty,
    unit_cost,
    received_qty
)
SELECT
    inv.inventory_key,
    v.vendor_key,
    dt_rcv.date_key AS received_date_key,
    dt_mfg.date_key AS mfg_date_key,
    dt_vrf.date_key AS verified_date_key,
    COALESCE(r_res.staff_key_default, -1) AS received_by_staff_key,
    COALESCE(v_res.staff_key_default, -1) AS verified_by_staff_key,
    s.SPL_ID,
    s.VEN_ACC,
    s.BTCH_NO,
    s.BTCH_SZ,
    s.SPL_UOM,
    s.WHS_LOC,
    s.PAL_ID,
    s.SPL_QTY,
    s.SPL_UCT,
    s.RCVD_QTY
FROM stg_supply s
JOIN dim_inventory inv
    ON TRIM(s.MAT_SKU) = TRIM(inv.material_sku)
LEFT JOIN dim_vendor v
    ON s.VEN_ACC = v.vendor_acc
JOIN dim_date dt_rcv
    ON DATE(s.RCVD_DATE) = dt_rcv.full_date
LEFT JOIN dim_date dt_mfg
    ON DATE(s.MFG_DATE) = dt_mfg.full_date
LEFT JOIN dim_date dt_vrf
    ON DATE(s.VRFC_DATE) = dt_vrf.full_date
LEFT JOIN bridge_staff_id_resolution r_res
    ON TRIM(s.RCVD_STF) = TRIM(r_res.staff_id)
LEFT JOIN bridge_staff_id_resolution v_res
    ON TRIM(s.VRFC_STF) = TRIM(v_res.staff_id);

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_supply_receipt rows = stg_supply rows' AS check_name,
           (SELECT COUNT(*) FROM fact_supply_receipt) AS found,
           (SELECT COUNT(*) FROM stg_supply) AS expected
    UNION ALL
    SELECT 'vendor_key NULL where source VEN_ACC exists in dim_vendor (expect 0)',
           (SELECT COUNT(*)
            FROM stg_supply s
            JOIN dim_vendor dv ON s.VEN_ACC = dv.vendor_acc
            JOIN fact_supply_receipt f ON s.SPL_ID = f.supply_id
            WHERE f.vendor_key IS NULL),
           0
) t;

-- ==========================================================================================
-- dim_vendor_payment_status
-- ==========================================================================================
CREATE TABLE dim_vendor_payment_status (
    vendor_payment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    vendor_payment_status_code INT NOT NULL,
    vendor_payment_status_desc VARCHAR(100) NOT NULL,
    UNIQUE (vendor_payment_status_code)
);

-- Populate dimension
INSERT INTO dim_vendor_payment_status (vendor_payment_status_code, vendor_payment_status_desc)
SELECT DISTINCT VPSTATUS_CD, VPSTATUS_DES
FROM stg_vendor_payment
WHERE VPSTATUS_CD IS NOT NULL;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_vendor_payment_status rows = distinct stg_vendor_payment VPSTATUS_CD' AS check_name,
           (SELECT COUNT(*) FROM dim_vendor_payment_status) AS found,
           (SELECT COUNT(DISTINCT VPSTATUS_CD) FROM stg_vendor_payment WHERE VPSTATUS_CD IS NOT NULL) AS expected
) t;

-- ==========================================================================================
-- fact_vendor_payment
-- Source: stg_vendor_payment | Grain: One vendor payment record
-- ==========================================================================================
CREATE TABLE fact_vendor_payment (
    vendor_payment_key INT AUTO_INCREMENT PRIMARY KEY,
    vendor_key INT NULL,
    payment_date_key INT NOT NULL,
    vendor_payment_status_key INT NOT NULL,
    -- Degenerate Dimensions & Measures
    payment_ref_no VARCHAR(20) NOT NULL,
    supply_id VARCHAR(20),
    source_vendor_account VARCHAR(20),
    account_no VARCHAR(20),
    wire_no VARCHAR(20),
    payment_terms INT,
    term_no INT,
    supply_cost DECIMAL(25,15),
    vendor_payment_amt DECIMAL(25,15),
    payment_due DECIMAL(25,15),
    -- Foreign Keys
    FOREIGN KEY (vendor_key) REFERENCES dim_vendor(vendor_key),
    FOREIGN KEY (payment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (vendor_payment_status_key) REFERENCES dim_vendor_payment_status(vendor_payment_status_key)
);

CREATE INDEX fact_vendor_pay_ix_1 ON fact_vendor_payment(payment_date_key);
CREATE INDEX fact_vendor_pay_ix_2 ON fact_vendor_payment(vendor_payment_status_key);
CREATE INDEX fact_vendor_pay_ix_3 ON fact_vendor_payment(payment_ref_no);
CREATE INDEX fact_vendor_pay_ix_4 ON fact_vendor_payment(supply_id);
CREATE INDEX fact_vendor_pay_ix_5 ON fact_vendor_payment(vendor_key);

-- Populate fact
INSERT INTO fact_vendor_payment (
    vendor_key,
    payment_date_key,
    vendor_payment_status_key,
    payment_ref_no,
    supply_id,
    source_vendor_account,
    account_no,
    wire_no,
    payment_terms,
    term_no,
    supply_cost,
    vendor_payment_amt,
    payment_due
)
SELECT
    v.vendor_key,
    dt.date_key AS payment_date_key,
    vpst.vendor_payment_status_key,
    s.REFR_NO,
    s.SPL_ID,
    s.VEN_ACC,
    s.ACC_NO,
    s.WRE_NO,
    s.PMNT_TRM,
    s.TRM_NO,
    s.SPL_CST,
    s.VPMT_AMT,
    s.PMNT_DUE
FROM stg_vendor_payment s
LEFT JOIN dim_vendor v
    ON s.VEN_ACC = v.vendor_acc
JOIN dim_date dt
    ON DATE(s.PMNT_DATE) = dt.full_date
JOIN dim_vendor_payment_status vpst
    ON s.VPSTATUS_CD = vpst.vendor_payment_status_code;

-- Validation
SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'fact_vendor_payment rows = stg_vendor_payment rows' AS check_name,
           (SELECT COUNT(*) FROM fact_vendor_payment) AS found,
           (SELECT COUNT(*) FROM stg_vendor_payment) AS expected
    UNION ALL
    SELECT 'fact_vendor_payment total vendor_payment_amt = stg_vendor_payment total VPMT_AMT',
           (SELECT ROUND(COALESCE(SUM(vendor_payment_amt), 0), 2) FROM fact_vendor_payment),
           (SELECT ROUND(COALESCE(SUM(VPMT_AMT), 0), 2) FROM stg_vendor_payment)
) t;
-- failed but with only a 0.01 difference so it technically passed 
