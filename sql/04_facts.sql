USE healthcare;

-- =============================================
-- 1. HOSPITAL OPERATIONS
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
    appointment_date_key INT NOT NULL,
    appointment_status_key INT NOT NULL,
    appointment_type_key INT NOT NULL,
    -- Degenerate Dimensions
    appointment_ref_no VARCHAR(20) NOT NULL,
    appointment_time DATETIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (booked_by_staff_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (doctor_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (appointment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (appointment_status_key) REFERENCES dim_appointment_status(appointment_status_key),
    FOREIGN KEY (appointment_type_key) REFERENCES dim_appointment_type(appointment_type_key)
);

-- Indexes for fact_appointment
CREATE INDEX fact_appointment_ix_1 ON fact_appointment(patient_key);
CREATE INDEX fact_appointment_ix_2 ON fact_appointment(doctor_key);
CREATE INDEX fact_appointment_ix_3 ON fact_appointment(booked_by_staff_key);
CREATE INDEX fact_appointment_ix_4 ON fact_appointment(appointment_date_key);
CREATE INDEX fact_appointment_ix_5 ON fact_appointment(appointment_status_key);
CREATE INDEX fact_appointment_ix_6 ON fact_appointment(appointment_type_key);

-- fact_visit
-- Source: stg_visit
-- Grain: One patient visit

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
    visit_date_key INT NOT NULL,
    visit_status_key INT NOT NULL,
    visit_type_key INT NOT NULL,
    -- Degenerate Dimensions
    visit_ref_no VARCHAR(20) NOT NULL,
    visit_entry DATETIME,
    visit_exit DATETIME,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (medical_team_key) REFERENCES dim_medical_team(medical_team_key),
    FOREIGN KEY (doctor_key) REFERENCES dim_staff(staff_key),
    FOREIGN KEY (visit_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (visit_status_key) REFERENCES dim_visit_status(visit_status_key),
    FOREIGN KEY (visit_type_key) REFERENCES dim_visit_type(visit_type_key)
);

-- Indexes for fact_visit
CREATE INDEX fact_visit_ix_1 ON fact_visit(patient_key);
CREATE INDEX fact_visit_ix_2 ON fact_visit(doctor_key);
CREATE INDEX fact_visit_ix_3 ON fact_visit(medical_team_key);
CREATE INDEX fact_visit_ix_4 ON fact_visit(visit_date_key);
CREATE INDEX fact_visit_ix_5 ON fact_visit(visit_status_key);
CREATE INDEX fact_visit_ix_6 ON fact_visit(visit_type_key);

-- =============================================
-- 2. CLINICAL ACTIVITIES
-- =============================================
-- fact_diagnosis
-- Source: stg_diagnosis
-- grain: one diagnosis record

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
    patient_key INT NOT NULL, -- Foreign Key
    room_key INT NOT NULL, 
    diagnosis_status_key INT NOT NULL,
    diagnosis_type_key INT NOT NULL,
    diagnosis_date_key INT NOT NULL,
    -- Degenerate Dimensions
    diagnosis_ref_no VARCHAR(20) NOT NULL,
    diagnosis_cost DECIMAL(10,2), 
    admission_date DATETIME,
    diagnosis_seq INT,
    diagnosis_code VARCHAR(20),
    diagnosis_desc VARCHAR(200),

    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (room_key) REFERENCES dim_room(room_key),
	FOREIGN KEY (date_key) REFERENCES dim_room(date_key),
    FOREIGN KEY (diagnosis_status_key) REFERENCES dim_diagnosis_status(diagnosis_status_key),
    FOREIGN KEY (diagnosis_type_key) REFERENCES dim_diagnosis_type(diagnosis_type_key)
);

-- Indexes for fact_diagnosis
CREATE INDEX fact_diagnosis_ix_1 ON fact_diagnosis(patient_key);
CREATE INDEX fact_diagnosis_ix_2 ON fact_diagnosis(room_key);
CREATE INDEX fact_diagnosis_ix_3 ON fact_diagnosis(diagnosis_date_key);
CREATE INDEX fact_diagnosis_ix_4 ON fact_diagnosis(diagnosis_status_key);
CREATE INDEX fact_diagnosis_ix_5 ON fact_diagnosis(diagnosis_type_key);

-- fact_treatment
-- Source: stg_treatment
-- one treatment record

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
    patient_key INT NOT NULL,              -- Foreign Keys
    treatment_date_key INT NOT NULL,       -- Recommended for dim_date
    -- Degenerate Dimensions
    treatment_ref_no VARCHAR (20) NOT NULL,
    treatment_cost DECIMAL(10,2), 
    treatment_entry DATETIME,
    treatment_code VARCHAR(20),
    treatment_desc VARCHAR(200),
    treatment_seq INT,
    -- Foreign Keys
    FOREIGN KEY (patient_key) REFERENCES dim_patient(patient_key),
    FOREIGN KEY (treatment_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (treatment_status_key) REFERENCES dim_treatment_status(treatment_status_key),
    FOREIGN KEY (treatment_type_key) REFERENCES dim_treatment_type(treatment_type_key)
);
-- Indexes for fact_treatment
CREATE INDEX fact_treatment_ix_1 ON fact_treatment(patient_key);
CREATE INDEX fact_treatment_ix_2 ON fact_treatment(treatment_date_key);
CREATE INDEX fact_treatment_ix_3 ON fact_treatment(treatment_status_key);
CREATE INDEX fact_treatment_ix_4 ON fact_treatment(treatment_type_key);

-- fact_treatment_medicine
-- Source: stg_treatment_med
-- grain: one treatment-medication record

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
    patient_key INT NOT NULL,  -- Foreign Keys        
    dosage_key INT NOT NULL,                
    frequency_key INT NOT NULL,             
    route_key INT NOT NULL,                 
    treatment_medicine_date_key INT,        
    -- Degenerate Dimensions & Measures
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
    FOREIGN KEY (route_key) REFERENCES dim_route(route_key),
    FOREIGN KEY (treatment_medicine_date_key) REFERENCES dim_date(date_key)
);

-- Indexes for fact_treatment_medicine
CREATE INDEX fact_treatment_med_ix_1 ON fact_treatment_medicine(patient_key);
CREATE INDEX fact_treatment_med_ix_2 ON fact_treatment_medicine(dosage_key);
CREATE INDEX fact_treatment_med_ix_3 ON fact_treatment_medicine(frequency_key);
CREATE INDEX fact_treatment_med_ix_4 ON fact_treatment_medicine(route_key);
CREATE INDEX fact_treatment_med_ix_5 ON fact_treatment_medicine(visit_ref_no);
-- CREATE INDEX fact_treatment_med_ix_6 ON dim_medicine(medicine_id);

-- =============================================
-- 3. FINANCIAL ACTIVITIES
-- =============================================

-- fact_billing
-- Source: stg_billing, stg_medicine_bill

-- fact_payment
-- Source: stg_payment


-- =============================================
-- 4. INVENTORY AND PROCUREMENT
-- =============================================

-- fact_inventory
-- Source: stg_inventory

-- fact_supply_receipt
-- Source: stg_supply

-- fact_vendor_payment
-- Source: stg_vendor_payment
