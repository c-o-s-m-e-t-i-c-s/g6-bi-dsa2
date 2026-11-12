USE healthcare;

-- =============================================
-- 1. HOSPITAL OPERATIONS
-- =============================================

-- =============================================
-- A. fact_appointment
-- Source: stg_appointment
-- grain: one appointment
-- =============================================
-- Lookup Dimension: Appointment Status
CREATE TABLE dim_appointment_status (
    appointment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    appointment_status_code INT NOT NULL,
    appointment_status_desc VARCHAR(100) NOT NULL
);

-- Lookup Dimension: Appointment Type
CREATE TABLE dim_appointment_type (
    appointment_type_key INT AUTO_INCREMENT PRIMARY KEY,
    appointment_type_code INT NOT NULL,
    appointment_type_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_appointment (
    appointment_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    booked_by_staff_key INT NOT NULL,
    doctor_key INT NOT NULL,
    appointment_status_key INT NOT NULL,
    appointment_type_key INT NOT NULL,
    -- Degenerate Dimensions & Dates
    appointment_ref_no VARCHAR(20) NOT NULL,
    appointment_date DATE NOT NULL,
    appointment_time DATETIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (booked_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (doctor_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (appointment_status_key) REFERENCES dim_appointment_status(appointment_status_key),
    FOREIGN KEY (appointment_type_key) REFERENCES dim_appointment_type(appointment_type_key)
);

-- Indexes for fact_appointment
CREATE INDEX fact_appointment_ix_1 ON fact_appointment(patient_key);
CREATE INDEX fact_appointment_ix_2 ON fact_appointment(doctor_key);
CREATE INDEX fact_appointment_ix_3 ON fact_appointment(booked_by_staff_key);
CREATE INDEX fact_appointment_ix_4 ON fact_appointment(appointment_date);
CREATE INDEX fact_appointment_ix_5 ON fact_appointment(appointment_status_key);
CREATE INDEX fact_appointment_ix_6 ON fact_appointment(appointment_type_key);

-- 1. Appointment Status
INSERT INTO dim_appointment_status (appointment_status_code, appointment_status_desc)
SELECT DISTINCT ASTAT_CD, ASTAT_DES 
FROM stg_appointment 
WHERE ASTAT_CD IS NOT NULL;
SELECT * FROM dim_appointment_status;

-- 2. Appointment Type
INSERT INTO dim_appointment_type (appointment_type_code, appointment_type_desc)
SELECT DISTINCT ATYPE_CD, ATYPE_DES 
FROM stg_appointment 
WHERE ATYPE_CD IS NOT NULL;
SELECT * FROM dim_appointment_type;

-- fact_appointment
INSERT INTO fact_appointment (
    patient_key,
    booked_by_staff_key,
    doctor_key,
    appointment_status_key,
    appointment_type_key,
    appointment_ref_no,
    appointment_date,
    appointment_time
)
SELECT 
    p.patient_key,
    COALESCE(b_stf.staff_key, -1) AS booked_by_staff_key,
    COALESCE(d_stf.staff_key, -1) AS doctor_key,
    ast.appointment_status_key,
    atp.appointment_type_key,
    s.REFR_NO,
    DATE(s.APT_TIME) AS appointment_date,
    TIME(s.APT_TIME) AS appointment_time
FROM stg_appointment s
JOIN dim_patient p 
    ON s.PAT_ID = p.patient_id
LEFT JOIN (
    SELECT staff_id, MIN(staff_key) AS staff_key
    FROM dim_staff
    WHERE staff_key <> -1
    GROUP BY staff_id
) b_stf 
    ON TRIM(s.CTD_ID) = TRIM(b_stf.staff_id)
LEFT JOIN (
    SELECT staff_id, MIN(staff_key) AS staff_key
    FROM dim_staff
    WHERE staff_key <> -1
    GROUP BY staff_id
) d_stf 
    ON TRIM(s.DOC_ID) = TRIM(d_stf.staff_id)
JOIN dim_appointment_status ast 
    ON s.ASTAT_CD = ast.appointment_status_code
JOIN dim_appointment_type atp 
    ON s.ATYPE_CD = atp.appointment_type_code;

-- =============================================
--  B. fact_visit
-- Source: stg_visit
-- Grain: One patient visit
-- =============================================

-- Lookup Dimension: Visit Status
CREATE TABLE dim_visit_status (
    visit_status_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_status_code INT NOT NULL,
    visit_status_desc VARCHAR(100) NOT NULL
);

-- Lookup Dimension: Visit Type
CREATE TABLE dim_visit_type (
    visit_type_key INT AUTO_INCREMENT PRIMARY KEY,
    visit_type_code INT NOT NULL,
    visit_type_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_visit (
    visit_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    medical_team_key INT NOT NULL,
    doctor_key INT NOT NULL,
    visit_status_key INT NOT NULL,
    visit_type_key INT NOT NULL,
    -- Degenerate Dimensions & Dates
    visit_ref_no VARCHAR(20) NOT NULL,
    visit_date DATE NOT NULL,
    visit_entry DATETIME,
    visit_exit DATETIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (medical_team_key) REFERENCES dim_medical_team(medical_team_key),
    FOREIGN KEY (doctor_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (visit_status_key) REFERENCES dim_visit_status(visit_status_key),
    FOREIGN KEY (visit_type_key) REFERENCES dim_visit_type(visit_type_key)
);

-- Indexes for fact_visit
CREATE INDEX fact_visit_ix_1 ON fact_visit(patient_key);
CREATE INDEX fact_visit_ix_2 ON fact_visit(doctor_key);
CREATE INDEX fact_visit_ix_3 ON fact_visit(medical_team_key);
CREATE INDEX fact_visit_ix_4 ON fact_visit(visit_date);
CREATE INDEX fact_visit_ix_5 ON fact_visit(visit_status_key);
CREATE INDEX fact_visit_ix_6 ON fact_visit(visit_type_key);

-- 3. Visit Status
INSERT INTO dim_visit_status (visit_status_code, visit_status_desc)
SELECT DISTINCT VSTAT_CD, VSTAT_DES 
FROM stg_visit 
WHERE VSTAT_CD IS NOT NULL;

-- 4. Visit Type
INSERT INTO dim_visit_type (visit_type_code, visit_type_desc)
SELECT DISTINCT VTYPE_CD, VTYPE_DES 
FROM stg_visit 
WHERE VTYPE_CD IS NOT NULL;

-- fact_visit
INSERT INTO fact_visit ( -- haven't run because of fk in medical team
    patient_key,
    medical_team_key,
    doctor_key,
    visit_status_key,
    visit_type_key,
    visit_ref_no,
    visit_date,
    visit_entry,
    visit_exit
)
SELECT 
    p.patient_key,
    mt.medical_team_key,
    stf.staff_key AS doctor_key,
    vst.visit_status_key,
    vtp.visit_type_key,
    s.REFR_NO,
    DATE(s.VST_EN) AS visit_date,
    s.VST_EN AS visit_entry,
    s.VST_EX AS visit_exit
FROM stg_visit s
JOIN dim_patient p ON s.PAT_ID = p.patient_id
JOIN dim_medical_team mt ON s.TEAM_ID = mt.medical_team_id
JOIN dim_staff stf ON s.DOC_ID = stf.staff_id
JOIN dim_visit_status vst ON s.VSTAT_CD = vst.visit_status_code
JOIN dim_visit_type vtp ON s.VTYPE_CD = vtp.visit_type_code;

-- =============================================
-- 2. CLINICAL ACTIVITIES
-- =============================================
-- =============================================
--  A. fact_diagnosis
-- Source: stg_diagnosis
-- grain: one diagnosis record
-- =============================================

-- Lookup Dimension: Diagnosis Status
CREATE TABLE dim_diagnosis_status (
    diagnosis_status_key INT AUTO_INCREMENT PRIMARY KEY,
    diagnosis_status_code INT NOT NULL,
    diagnosis_status_desc VARCHAR(100) NOT NULL
);

-- Lookup Dimension: Diagnosis Treatment Type
CREATE TABLE dim_diagnosis_type (
    diagnosis_type_key INT AUTO_INCREMENT PRIMARY KEY,
    diagnosis_type_code INT NOT NULL,
    diagnosis_type_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_diagnosis (
    diagnosis_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    room_key INT NOT NULL, 
    diagnosis_status_key INT NOT NULL,
    diagnosis_type_key INT NOT NULL,
    -- Degenerate Dimensions & Dates
    diagnosis_ref_no VARCHAR(20) NOT NULL,
    diagnosis_date DATE NOT NULL,
    admission_date DATETIME,
    diagnosis_cost DECIMAL(10,2), 
    diagnosis_seq INT,
    diagnosis_code VARCHAR(20),
    diagnosis_desc VARCHAR(200),
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (room_key) REFERENCES dim_room(room_key),
    FOREIGN KEY (diagnosis_status_key) REFERENCES dim_diagnosis_status(diagnosis_status_key),
    FOREIGN KEY (diagnosis_type_key) REFERENCES dim_diagnosis_type(diagnosis_type_key)
);

-- Indexes for fact_diagnosis
CREATE INDEX fact_diagnosis_ix_1 ON fact_diagnosis(patient_key);
CREATE INDEX fact_diagnosis_ix_2 ON fact_diagnosis(room_key);
CREATE INDEX fact_diagnosis_ix_3 ON fact_diagnosis(diagnosis_date);
CREATE INDEX fact_diagnosis_ix_4 ON fact_diagnosis(diagnosis_status_key);
CREATE INDEX fact_diagnosis_ix_5 ON fact_diagnosis(diagnosis_type_key);


-- 5. Diagnosis Status
INSERT INTO dim_diagnosis_status (diagnosis_status_code, diagnosis_status_desc)
SELECT DISTINCT DSTAT_CD, DSTAT_DES 
FROM stg_diagnosis 
WHERE DSTAT_CD IS NOT NULL;

-- 6. Diagnosis Recommended Treatment Type
INSERT INTO dim_diagnosis_type (diagnosis_type_code, diagnosis_type_desc)
SELECT DISTINCT DTYPE_CD, DTYPE_DES 
FROM stg_diagnosis 
WHERE DTYPE_CD IS NOT NULL;

INSERT INTO fact_diagnosis (
    patient_key,
    room_key,
    diagnosis_status_key,
    diagnosis_type_key,
    diagnosis_ref_no,
    diagnosis_date,
    admission_date,
    diagnosis_cost,
    diagnosis_seq,
    diagnosis_code,
    diagnosis_desc
)
SELECT 
    p.patient_key,
    r.room_key,
    dst.diagnosis_status_key,
    dtp.diagnosis_type_key,
    s.REFR_NO,
    DATE(s.DIG_EN) AS diagnosis_date,
    s.DIG_EN AS admission_date,
    s.DIG_TOT,
    s.DIG_SEQ,
    s.DIG_CD,
    s.DIG_DES
FROM stg_diagnosis s
JOIN stg_visit v ON s.REFR_NO = v.REFR_NO -- Lookup Patient ID via Visit FK
JOIN dim_patient p ON v.PAT_ID = p.patient_id
JOIN dim_room r ON s.ROM_ID = r.room_id
JOIN dim_diagnosis_status dst ON s.DSTAT_CD = dst.diagnosis_status_code
JOIN dim_diagnosis_type dtp ON s.DTYPE_CD = dtp.diagnosis_type_code;

-- =============================================
-- B. fact_treatment
-- Source: stg_treatment
-- grain: one treatment record
-- =============================================

-- Lookup Dimension: Treatment Status
CREATE TABLE dim_treatment_status (
    treatment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    treatment_status_code INT NOT NULL,
    treatment_status_desc VARCHAR(100) NOT NULL
);

-- Lookup Dimension: Treatment Type
CREATE TABLE dim_treatment_type (
    treatment_type_key INT AUTO_INCREMENT PRIMARY KEY,
    treatment_type_code INT NOT NULL,
    treatment_type_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_treatment (
    treatment_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    treatment_status_key INT NOT NULL,
    treatment_type_key INT NOT NULL,
    -- Degenerate Dimensions & Dates
    treatment_ref_no VARCHAR(20) NOT NULL,
    treatment_date DATE NOT NULL,
    treatment_entry DATETIME,
    treatment_cost DECIMAL(10,2), 
    treatment_code VARCHAR(20),
    treatment_desc VARCHAR(200),
    treatment_seq INT,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (treatment_status_key) REFERENCES dim_treatment_status(treatment_status_key),
    FOREIGN KEY (treatment_type_key) REFERENCES dim_treatment_type(treatment_type_key)
);

-- Indexes for fact_treatment
CREATE INDEX fact_treatment_ix_1 ON fact_treatment(patient_key);
CREATE INDEX fact_treatment_ix_2 ON fact_treatment(treatment_date);
CREATE INDEX fact_treatment_ix_3 ON fact_treatment(treatment_status_key);
CREATE INDEX fact_treatment_ix_4 ON fact_treatment(treatment_type_key);

-- 7. Treatment Status
INSERT INTO dim_treatment_status (treatment_status_code, treatment_status_desc)
SELECT DISTINCT TSTAT_CD, TSTAT_DES 
FROM stg_treatment 
WHERE TSTAT_CD IS NOT NULL;

-- 8. Treatment Executed Type
INSERT INTO dim_treatment_type (treatment_type_code, treatment_type_desc)
SELECT DISTINCT TTYPE_CD, TTYPE_DES 
FROM stg_treatment 
WHERE TTYPE_CD IS NOT NULL;
INSERT INTO fact_treatment (
    patient_key,
    treatment_status_key,
    treatment_type_key,
    treatment_ref_no,
    treatment_date,
    treatment_entry,
    treatment_cost,
    treatment_code,
    treatment_desc,
    treatment_seq
)
SELECT 
    p.patient_key,
    tst.treatment_status_key,
    ttp.treatment_type_key,
    s.REFR_NO,
    DATE(s.TRTM_EN) AS treatment_date,
    s.TRTM_EN AS treatment_entry,
    s.TRTM_TOT,
    s.TRTM_CD,
    s.TRTM_DES,
    s.TRTM_SEQ
FROM stg_treatment s
JOIN stg_visit v ON s.REFR_NO = v.REFR_NO -- Lookup Patient ID via Visit FK
JOIN dim_patient p ON v.PAT_ID = p.patient_id
JOIN dim_treatment_status tst ON s.TSTAT_CD = tst.treatment_status_code
JOIN dim_treatment_type ttp ON s.TTYPE_CD = ttp.treatment_type_code;


-- =============================================
-- C. fact_treatment_medicine
-- Source: stg_treatment_med
-- grain: one treatment-medication record
-- =============================================

CREATE TABLE dim_dosage (
    dosage_key INT AUTO_INCREMENT PRIMARY KEY,
    dosage_code INT NOT NULL,
    dosage_desc VARCHAR(100) NOT NULL
);

CREATE TABLE dim_frequency (
    frequency_key INT AUTO_INCREMENT PRIMARY KEY,
    frequency_code INT NOT NULL,
    frequency_desc VARCHAR(100) NOT NULL
);

CREATE TABLE dim_route (
    route_key INT AUTO_INCREMENT PRIMARY KEY,
    route_code INT NOT NULL,
    route_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_treatment_medicine (
    treatment_medicine_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    dosage_key INT NOT NULL,
    frequency_key INT NOT NULL,
    route_key INT NOT NULL,
    -- Degenerate Dimensions, Dates & Measures
    visit_ref_no VARCHAR(20) NOT NULL,
    medicine_id VARCHAR(20) NOT NULL,
    medicine_seq INT,
    quantity_prescribed DECIMAL(10,2),
    unit_dose DECIMAL(10,2),
    medicine_cost DECIMAL(10,2),
    -- Foreign Key Constraints
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (dosage_key) REFERENCES dim_dosage(dosage_key),
    FOREIGN KEY (frequency_key) REFERENCES dim_frequency(frequency_key),
    FOREIGN KEY (route_key) REFERENCES dim_route(route_key)
);

-- Indexes for fact_treatment_medicine
CREATE INDEX fact_treatment_med_ix_1 ON fact_treatment_medicine(patient_key);
CREATE INDEX fact_treatment_med_ix_2 ON fact_treatment_medicine(dosage_key);
CREATE INDEX fact_treatment_med_ix_3 ON fact_treatment_medicine(frequency_key);
CREATE INDEX fact_treatment_med_ix_4 ON fact_treatment_medicine(route_key);
CREATE INDEX fact_treatment_med_ix_5 ON fact_treatment_medicine(visit_ref_no);

-- 9. Medicine Dosage
INSERT INTO dim_dosage (dosage_code, dosage_desc)
SELECT DISTINCT DOS_CD, DOS_DES 
FROM stg_treatment_med 
WHERE DOS_CD IS NOT NULL;

-- 10. Medicine Frequency
INSERT INTO dim_frequency (frequency_code, frequency_desc)
SELECT DISTINCT FREQ_CD, FREQ_DES 
FROM stg_treatment_med 
WHERE FREQ_CD IS NOT NULL;

-- 11. Medicine Route
INSERT INTO dim_route (route_code, route_desc)
SELECT DISTINCT RUTE_CD, RUTE_DES 
FROM stg_treatment_med 
WHERE RUTE_CD IS NOT NULL;

-- fact_treatment_medicine
INSERT INTO fact_treatment_medicine (
    patient_key,
    dosage_key,
    frequency_key,
    route_key,
    visit_ref_no,
    medicine_id,
    treatment_medicine_date,
    medicine_seq,
    quantity_prescribed,
    unit_dose,
    medicine_cost
)
SELECT 
    p.patient_key,
    dos.dosage_key,
    frq.frequency_key,
    rut.route_key,
    s.REFR_NO,
    s.MED_ID,
    DATE(s.MED_DT) AS treatment_medicine_date,
    s.MEDS_SEQ,
    s.QTY_NO,
    s.UNIT_DOS,
    s.MEDS_TOT
FROM stg_treatment_med s
JOIN stg_visit v ON s.REFR_NO = v.REFR_NO -- Lookup Patient ID via Visit FK
JOIN dim_patient p ON v.PAT_ID = p.patient_id
JOIN dim_dosage dos ON s.DOS_CD = dos.dosage_code
JOIN dim_frequency frq ON s.FREQ_CD = frq.frequency_code
JOIN dim_route rut ON s.RUTE_CD = rut.route_code;
-- =============================================
-- 3. FINANCIAL ACTIVITIES
-- =============================================
-- =============================================
-- A. fact_billing
-- Source: stg_billing
-- grain: one billing record
-- =============================================
-- Lookup Dimension: Billing Status
CREATE TABLE dim_billing_status (
    bill_status_key INT AUTO_INCREMENT PRIMARY KEY,
    bill_status_code INT NOT NULL,
    bill_status_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_billing (
    bill_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    bill_status_key INT NOT NULL,
    -- Degenerate Dimensions & Dates
    bill_ref_no VARCHAR(20) NOT NULL,
    bill_date DATETIME NOT NULL,
    bill_amt DECIMAL(10,2),
    bill_type_code VARCHAR(2), 
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (bill_status_key) REFERENCES dim_billing_status(bill_status_key)
);


-- Indexes for fact_billing
CREATE INDEX fact_bill_ix_1 ON fact_billing(patient_key);
CREATE INDEX fact_bill_ix_2 ON fact_billing(bill_date);
CREATE INDEX fact_bill_ix_3 ON fact_billing(bill_status_key);
CREATE INDEX fact_billing_ix_4 ON fact_billing(bill_type_code);

-- 12. Billing Status
INSERT INTO dim_billing_status (bill_status_code, bill_status_desc)
SELECT DISTINCT BSTAT_CD, BSTAT_DES 
FROM stg_billing 
WHERE BSTAT_CD IS NOT NULL;

-- fact_billing
INSERT INTO fact_billing (
    patient_key,
    bill_status_key,
    bill_ref_no,
    bill_date,
    bill_amt,
    bill_type_code
)
SELECT 
    p.patient_key,
    bst.bill_status_key,
    s.REFR_NO,
    s.BILL_DATE,
    s.BILL_AMT,
    s.BTYPE_CD
FROM stg_billing s
JOIN dim_patient p ON s.PAT_ID = p.patient_id
JOIN dim_billing_status bst ON s.BSTAT_CD = bst.bill_status_code;

-- =============================================
-- B. fact_medbill
-- Source: stg_medicine_billing
-- grain: one billing record
-- =============================================

-- Lookup Dimension: Medicine Bill Status
CREATE TABLE dim_medbill_status (
    medbill_status_key INT AUTO_INCREMENT PRIMARY KEY,
    medbill_status_code INT NOT NULL,        
    medbill_status_desc VARCHAR(100) NOT NULL 
);

CREATE TABLE fact_medbill (
    medbill_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,                  
    medbill_status_key INT NOT NULL,           
    -- Degenerate Dimensions, Dates & Measures
    medbill_ref_no VARCHAR(20) NOT NULL,      
    medbill_type_code VARCHAR(20),                  
    medbill_date DATE NOT NULL,                
    medbill_amt DECIMAL(10,2),               
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (medbill_status_key) REFERENCES dim_medbill_status(medbill_status_key)
);

-- Indexes for fact_medbill
CREATE INDEX fact_medbill_ix_1 ON fact_medbill(patient_key);
CREATE INDEX fact_medbill_ix_2 ON fact_medbill(medbill_date);
CREATE INDEX fact_medbill_ix_3 ON fact_medbill(medbill_status_key);
CREATE INDEX fact_medbill_ix_4 ON fact_medbill(medbill_ref_no);

-- 13. Medicine Bill Status
INSERT INTO dim_medbill_status (medbill_status_code, medbill_status_desc)
SELECT DISTINCT BSTAT_CD, BSTAT_DES 
FROM stg_medicine_bill 
WHERE BSTAT_CD IS NOT NULL;

INSERT INTO fact_medbill (
    patient_key,
    medbill_status_key,
    medbill_ref_no,
    medbill_type_code,
    medbill_date,
    medbill_amt
)
SELECT 
    p.patient_key,
    mbst.medbill_status_key,
    s.REFR_NO,
    s.BTYPE_CD,
    DATE(s.BILL_DATE) AS medbill_date,
    s.BILL_AMT
FROM stg_medicine_bill s
JOIN dim_patient p ON s.PAT_ID = p.patient_id
JOIN dim_medbill_status mbst ON s.BSTAT_CD = mbst.medbill_status_code;

-- =============================================
-- C. fact_payment
-- Source: stg_payment
-- grain: one payment transaction
-- =============================================

-- Lookup Dimension: Payment Method / Mode
CREATE TABLE dim_payment_method (
    payment_method_key INT AUTO_INCREMENT PRIMARY KEY,
    payment_method_code INT NOT NULL,
    payment_method_desc VARCHAR(100) NOT NULL
);

-- Lookup Dimension: Payment Status
CREATE TABLE dim_payment_status (
    payment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    payment_status_code INT NOT NULL,
    payment_status_desc VARCHAR(100) NOT NULL
);

CREATE TABLE fact_payment (
    payment_key INT AUTO_INCREMENT PRIMARY KEY,
    patient_key INT NOT NULL,
    payment_method_key INT NOT NULL,
    payment_status_key INT NOT NULL,
    -- Degenerate Dimensions, Dates & Measures
    bill_ref_no VARCHAR(20) NOT NULL,
    payment_date DATETIME NOT NULL,
    payment_amount DECIMAL(10,2),
    payment_terms INT,
    payment_interface_id VARCHAR(50),
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key),
    FOREIGN KEY (payment_status_key) REFERENCES dim_payment_status(payment_status_key)
);

-- Indexes for fact_payment
CREATE INDEX fact_payment_ix_1 ON fact_payment(patient_key);
CREATE INDEX fact_payment_ix_2 ON fact_payment(payment_date);
CREATE INDEX fact_payment_ix_3 ON fact_payment(payment_method_key);
CREATE INDEX fact_payment_ix_4 ON fact_payment(payment_status_key);
CREATE INDEX fact_payment_ix_5 ON fact_payment(bill_ref_no);

-- 14. Payment Method
INSERT INTO dim_payment_method (payment_method_code, payment_method_desc)
SELECT DISTINCT PMODE_CD, PMODE_DES 
FROM stg_payment 
WHERE PMODE_CD IS NOT NULL;

-- 15. Payment Status
INSERT INTO dim_payment_status (payment_status_code, payment_status_desc)
SELECT DISTINCT PSTAT_CD, PSTAT_DES 
FROM stg_payment 
WHERE PSTAT_CD IS NOT NULL;
-- =============================================
-- 4. INVENTORY AND PROCUREMENT
-- =============================================

-- =============================================
-- A. fact_inventory
-- Source: stg_inventory
-- grain: one inventory record
-- =============================================
CREATE TABLE fact_inventory ( 
    inventory_key INT AUTO_INCREMENT PRIMARY KEY,
    opened_by_staff_key INT,                     
    received_by_staff_key INT,                    
    issued_by_staff_key INT,                      
    closed_by_staff_key INT,                      
    verified_by_staff_key INT,                    
    -- Degenerate Dimensions, Dates & Measures
    material_sku VARCHAR(20) NOT NULL,            
    ingestion_date DATE NOT NULL,                
    ingestion_timestamp DATETIME,                 
    opening_qty DECIMAL(10,2),                    
    received_qty DECIMAL(10,2),                   
    issued_qty DECIMAL(10,2),                     
    closing_qty DECIMAL(10,2),                   
    -- Foreign Keys
    FOREIGN KEY (opened_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (received_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (issued_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (closed_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (verified_by_staff_key) REFERENCES dim_staff(staff_key)
);

-- Indexes for fact_inventory
CREATE INDEX fact_inventory_ix_1 ON fact_inventory(ingestion_date);
CREATE INDEX fact_inventory_ix_2 ON fact_inventory(material_sku);
CREATE INDEX fact_inventory_ix_3 ON fact_inventory(received_by_staff_key);
CREATE INDEX idx_dim_staff_id ON dim_staff(staff_id);

-- will insert a run per batch

-- =============================================
-- B. fact_supply_receipt
-- Source: stg_supply
-- grain: one supply record
-- =============================================
CREATE TABLE fact_supply_receipt (
    supply_receipt_key INT AUTO_INCREMENT PRIMARY KEY,
    received_by_staff_key INT,                    
    verified_by_staff_key INT,                   
    -- Degenerate Dimensions, Dates & Measures
    supply_id VARCHAR(20) NOT NULL,               
    material_sku VARCHAR(20) NOT NULL,            
    received_date DATE NOT NULL,                  
    mfg_date DATE,                            
    verified_date DATE,                          
    vendor_account VARCHAR(20),             
    batch_no VARCHAR(30),                         
    batch_size INT,
    supply_qty DECIMAL(10,2),                    
    supply_uom VARCHAR(10),                      
    unit_cost DECIMAL(10,2),                  
    warehouse_location VARCHAR(50),            
    pallet_id VARCHAR(20),                       
    received_qty DECIMAL(10,2),                   
    -- Foreign Keys
    FOREIGN KEY (received_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (verified_by_staff_key) REFERENCES dim_staff(staff_key)
);

-- Indexes for fact_supply_receipt
CREATE INDEX fact_supply_receipt_ix_1 ON fact_supply_receipt(received_date);
CREATE INDEX fact_supply_receipt_ix_2 ON fact_supply_receipt(supply_id);
CREATE INDEX fact_supply_receipt_ix_3 ON fact_supply_receipt(material_sku);
CREATE INDEX fact_supply_receipt_ix_4 ON fact_supply_receipt(vendor_account);

-- fact_supply_receipt
INSERT INTO fact_supply_receipt (
    received_by_staff_key,
    verified_by_staff_key,
    supply_id,
    material_sku,
    received_date,
    mfg_date,
    verified_date,
    vendor_account,
    batch_no,
    batch_size,
    supply_qty,
    supply_uom,
    unit_cost,
    warehouse_location,
    pallet_id,
    received_qty
)
SELECT 
    r_stf.staff_key AS received_by_staff_key,
    v_stf.staff_key AS verified_by_staff_key,
    s.SPL_ID,
    s.MAT_SKU,
    DATE(s.RCVD_DATE) AS received_date,
    DATE(s.MFG_DATE) AS mfg_date,
    DATE(s.VRFC_DATE) AS verified_date,
    s.VEN_ACC,
    s.BTCH_NO,
    s.BTCH_SZ,
    s.SPL_QTY,
    s.SPL_UOM,
    s.SPL_UCT,
    s.WHS_LOC,
    s.PAL_ID,
    s.RCVD_QTY
FROM stg_supply s
LEFT JOIN dim_staff r_stf ON s.RCVD_STF = r_stf.staff_id
LEFT JOIN dim_staff v_stf ON s.VRFC_STF = v_stf.staff_id;

-- =============================================
-- C. fact_vendor_payment
-- Source: stg_vendor_payment
-- grain: one vendor payment record
-- =============================================

-- Lookup Dimension: Vendor Payment Status
CREATE TABLE dim_vendor_payment_status (
    vendor_payment_status_key INT AUTO_INCREMENT PRIMARY KEY,
    vendor_payment_status_code INT NOT NULL,       
    vendor_payment_status_desc VARCHAR(100) NOT NULL 
);

CREATE TABLE fact_vendor_payment (
    vendor_payment_key INT AUTO_INCREMENT PRIMARY KEY,
    vendor_payment_status_key INT NOT NULL,       
    -- Degenerate Dimensions, Dates & Measures
    payment_ref_no VARCHAR(20) NOT NULL,           
    payment_date DATE NOT NULL,                    
    supply_id VARCHAR(20),                         
    vendor_account VARCHAR(20),                    
    account_no VARCHAR(20),                        
    wire_no VARCHAR(20),                          
    payment_terms INT,                           
    term_no INT,                               
    supply_cost DECIMAL(10,2),              
    vendor_payment_amt DECIMAL(10,2),              
    payment_due DECIMAL(10,2),                     
    -- Foreign Keys
    FOREIGN KEY (vendor_payment_status_key) REFERENCES dim_vendor_payment_status(vendor_payment_status_key)
);

-- Indexes for fact_vendor_payment
CREATE INDEX fact_vendor_pay_ix_1 ON fact_vendor_payment(payment_date);
CREATE INDEX fact_vendor_pay_ix_2 ON fact_vendor_payment(vendor_payment_status_key);
CREATE INDEX fact_vendor_pay_ix_3 ON fact_vendor_payment(payment_ref_no);
CREATE INDEX fact_vendor_pay_ix_4 ON fact_vendor_payment(supply_id);
CREATE INDEX fact_vendor_pay_ix_5 ON fact_vendor_payment(vendor_account);

-- 16. Vendor Payment Status
INSERT INTO dim_vendor_payment_status (vendor_payment_status_code, vendor_payment_status_desc)
SELECT DISTINCT VPSTATUS_CD, VPSTATUS_DES 
FROM stg_vendor_payment 
WHERE VPSTATUS_CD IS NOT NULL;

-- fact_vendor_payment
INSERT INTO fact_vendor_payment (
    vendor_payment_status_key,
    payment_ref_no,
    payment_date,
    supply_id,
    vendor_account,
    account_no,
    wire_no,
    payment_terms,
    term_no,
    supply_cost,
    vendor_payment_amt,
    payment_due
)
SELECT 
    vpst.vendor_payment_status_key,
    s.REFR_NO,
    DATE(s.PMNT_DATE) AS payment_date,
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
JOIN dim_vendor_payment_status vpst ON s.VPSTATUS_CD = vpst.vendor_payment_status_code;
