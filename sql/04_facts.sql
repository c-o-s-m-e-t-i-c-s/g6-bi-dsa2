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

-- fact_treatment
-- Source: stg_treatment

-- fact_treatment_medicine
-- Source: stg_treatment_med


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
