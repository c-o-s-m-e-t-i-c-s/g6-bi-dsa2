/* =============================================================================
01_setup_and_staging.sql
Prerequisite: Run src/import data.py/ first to load the data

Re-run behavior: RENAME TABLE is atomic. If any source table is missing (e.g., this script was already run), 
the whole statement fails and NO table is renamed, so the schema is never left half-renamed.
============================================================================= */

SET PERSIST local_infile = 1;

CREATE DATABASE IF NOT EXISTS healthcare;
USE healthcare;

-- rename tables for easier readability
RENAME TABLE
    stg_ehp__algy TO stg_allergy,
    stg_ehp__appt TO stg_appointment,
    stg_ehp__bill TO stg_billing,
    stg_ehp__diag TO stg_diagnosis,
    stg_ehp__dpmt TO stg_department,
    stg_ehp__eqpm TO stg_equipment,
    stg_ehp__insr TO stg_insurance,
    stg_ehp__invn TO stg_inventory,
    stg_ehp__mdbl TO stg_medicine_bill,
    stg_ehp__mdcn TO stg_medicine,
    stg_ehp__medt TO stg_medical_team,
    stg_ehp__patn TO stg_patient,
    stg_ehp__pmnt TO stg_payment,
    stg_ehp__ptal TO stg_patient_allergy,
    stg_ehp__roms TO stg_rooms,
    stg_ehp__sply TO stg_supply,
    stg_ehp__stff TO stg_staff,
    stg_ehp__tmmd TO stg_treatment_med,
    stg_ehp__trtm TO stg_treatment,
    stg_ehp__vist TO stg_visit,
    stg_ehp__vndr TO stg_vendor,
    stg_ehp__vpmt TO stg_vendor_payment;

-- sanity check: should return 22
SELECT COUNT(*) AS renamed_table_count
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'healthcare'
  AND TABLE_NAME LIKE 'stg\_%'
  AND TABLE_NAME NOT LIKE 'stg\_ehp\_\_%';
