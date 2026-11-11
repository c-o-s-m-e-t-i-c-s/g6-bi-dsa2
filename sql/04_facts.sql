USE healthcare;

-- =============================================
-- 1. HOSPITAL OPERATIONS
-- =============================================

-- fact_appointment
-- Source: stg_appointment

-- fact_visit
-- Source: stg_visit


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