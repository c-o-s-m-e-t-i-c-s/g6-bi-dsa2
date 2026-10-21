SET GLOBAL local_infile = 1;

CREATE DATABASE IF NOT EXISTS healthcare;
USE healthcare;

-- rename tables for easier readability
ALTER TABLE stg_ehp__algy
RENAME TO stg_allergy;

ALTER TABLE stg_ehp__appt
RENAME TO stg_appointment;

ALTER TABLE stg_ehp__bill
RENAME TO stg_billing;

ALTER TABLE stg_ehp__diag
RENAME TO stg_diagnosis;

ALTER TABLE stg_ehp__dpmt
RENAME TO stg_department;

ALTER TABLE stg_ehp__eqpm
RENAME TO stg_equipment;

ALTER TABLE stg_ehp__insr
RENAME TO stg_insurance;

ALTER TABLE stg_ehp__invn
RENAME TO stg_inventory;

ALTER TABLE stg_ehp__mdbl
RENAME TO stg_medicinebill;

ALTER TABLE stg_ehp__mdcn
RENAME TO stg_medicine;

ALTER TABLE stg_ehp__medt
RENAME TO stg_medicalteam;

ALTER TABLE stg_ehp__patn
RENAME TO stg_patient;

ALTER TABLE stg_ehp__pmnt
RENAME TO stg_payment;

ALTER TABLE stg_ehp__ptal
RENAME TO stg_patientalgy;

ALTER TABLE stg_ehp__roms
RENAME TO stg_rooms;

ALTER TABLE stg_ehp__sply
RENAME TO stg_supply;

ALTER TABLE stg_ehp__stff
RENAME TO stg_staff;

ALTER TABLE stg_ehp__tmmd
RENAME TO stg_treatmentmed;

ALTER TABLE stg_ehp__trtm
RENAME TO stg_treatment;

ALTER TABLE stg_ehp__vist
RENAME TO stg_visit;

ALTER TABLE stg_ehp__vndr
RENAME TO stg_vendor;

ALTER TABLE stg_ehp__vpmt
RENAME TO stg_vendorpayment;