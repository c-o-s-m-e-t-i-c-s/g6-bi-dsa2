USE healthcare;

-- A. GRAIN CHECK
WITH expected_source_counts AS (
    -- Single Source Files
    SELECT 'stg_allergy' AS table_name, 44 AS expected_rows UNION ALL
    SELECT 'stg_appointment', 974032 UNION ALL
    SELECT 'stg_billing', 917331 UNION ALL
    SELECT 'stg_department', 30 UNION ALL
    SELECT 'stg_equipment', 10190 UNION ALL
    SELECT 'stg_insurance', 457072 UNION ALL
    SELECT 'stg_medicine_bill', 465152 UNION ALL
    SELECT 'stg_medicine', 346302 UNION ALL
    SELECT 'stg_medical_team', 312870 UNION ALL
    SELECT 'stg_patient', 351765 UNION ALL
    SELECT 'stg_patient_allergy', 644303 UNION ALL
    SELECT 'stg_rooms', 24302 UNION ALL
    SELECT 'stg_supply', 721134 UNION ALL
    SELECT 'stg_staff', 5496 UNION ALL
    SELECT 'stg_treatment', 917191 UNION ALL
    SELECT 'stg_visit', 917331 UNION ALL
    SELECT 'stg_vendor', 13562 UNION ALL
    
    -- Multi-part / Partitioned Files (Aggregated Sums)
    SELECT 'stg_diagnosis', 1602174 UNION ALL  -- DIAG_1 + DIAG_2
    SELECT 'stg_payment', 2774514 UNION ALL    -- PMNT_1 + PMNT_2 + PMNT_3
    SELECT 'stg_vendor_payment', 1802488 UNION ALL -- VPMT_1 + VPMT_2
    SELECT 'stg_treatment_med', 4305489 UNION ALL -- TMMD file + TMMD_1 through TMMD_4
    SELECT 'stg_inventory', 90731353        -- INVN_1 through INVN_6 series files
),
actual_database_counts AS (
    SELECT 'stg_allergy' AS table_name, COUNT(*) AS fact_rows FROM healthcare.stg_allergy UNION ALL
    SELECT 'stg_appointment', COUNT(*) FROM healthcare.stg_appointment UNION ALL
    SELECT 'stg_billing', COUNT(*) FROM healthcare.stg_billing UNION ALL
    SELECT 'stg_department', COUNT(*) FROM healthcare.stg_department UNION ALL
    SELECT 'stg_equipment', COUNT(*) FROM healthcare.stg_equipment UNION ALL
    SELECT 'stg_insurance', COUNT(*) FROM healthcare.stg_insurance UNION ALL
    SELECT 'stg_medicine_bill', COUNT(*) FROM healthcare.stg_medicine_bill UNION ALL
    SELECT 'stg_medicine', COUNT(*) FROM healthcare.stg_medicine UNION ALL
    SELECT 'stg_medical_team', COUNT(*) FROM healthcare.stg_medical_team UNION ALL
    SELECT 'stg_patient', COUNT(*) FROM healthcare.stg_patient UNION ALL
    SELECT 'stg_patient_allergy', COUNT(*) FROM healthcare.stg_patient_allergy UNION ALL
    SELECT 'stg_rooms', COUNT(*) FROM healthcare.stg_rooms UNION ALL
    SELECT 'stg_supply', COUNT(*) FROM healthcare.stg_supply UNION ALL
    SELECT 'stg_staff', COUNT(*) FROM healthcare.stg_staff UNION ALL
    SELECT 'stg_treatment', COUNT(*) FROM healthcare.stg_treatment UNION ALL
    SELECT 'stg_visit', COUNT(*) FROM healthcare.stg_visit UNION ALL
    SELECT 'stg_vendor', COUNT(*) FROM healthcare.stg_vendor UNION ALL
    SELECT 'stg_diagnosis', COUNT(*) FROM healthcare.stg_diagnosis UNION ALL
    SELECT 'stg_payment', COUNT(*) FROM healthcare.stg_payment UNION ALL
    SELECT 'stg_vendor_payment', COUNT(*) FROM healthcare.stg_vendor_payment UNION ALL
    SELECT 'stg_treatment_med', COUNT(*) FROM healthcare.stg_treatment_med UNION ALL
    SELECT 'stg_inventory', COUNT(*) FROM healthcare.stg_inventory
)
SELECT 
    e.table_name,
    a.fact_rows,
    e.expected_rows AS source_rows,
    (a.fact_rows - e.expected_rows) AS row_difference,
    CASE 
        WHEN a.fact_rows = e.expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS grain_check
FROM expected_source_counts e
JOIN actual_database_counts a ON e.table_name = a.table_name
ORDER BY e.table_name;

-- B. NULL VALUES
-- 1. Patient Table (stg_patient) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(F_NAME IS NULL) AS null_F_NAME,
    SUM(L_NAME IS NULL) AS null_L_NAME,
    -- M_NAME is not part of the null check since some patients do not have one and that is still acceptable
    SUM(GEN_CD IS NULL) AS null_GEN_CD,
    SUM(GEN_DES IS NULL) AS null_GEN_DES,
    SUM(DT_BRT IS NULL) AS null_DT_BRT,
    SUM(CON_NO IS NULL) AS null_CON_NO,
    SUM(EM_ADD IS NULL) AS null_EM_ADD,
    SUM(EC_F_NAME IS NULL) AS null_EC_F_NAME,
    SUM(EC_L_NAME IS NULL) AS null_EC_L_NAME,
    -- EC_M_NAME is not part of the null check since some patients do not have one and that is still acceptable
    SUM(EC_CON_NO IS NULL) AS null_EC_CON_NO,
    SUM(B_TYPE IS NULL) AS null_B_TYPE,
    SUM(MAR_ST IS NULL) AS null_MAR_ST,
    SUM(NAT_ID_S IS NULL) AS null_NAT_ID_S,
    SUM(NAT_ID_T IS NULL) AS null_NAT_ID_T,
    SUM(NAT_ID_N IS NULL) AS null_NAT_ID_N,
    SUM(NAT_ID_E IS NULL) AS null_NAT_ID_E,
    IF(SUM(PAT_ID IS NULL) + SUM(F_NAME IS NULL) + SUM(L_NAME IS NULL) + SUM(GEN_CD IS NULL) + SUM(GEN_DES IS NULL) + SUM(DT_BRT IS NULL) + SUM(CON_NO IS NULL) + SUM(EM_ADD IS NULL) + SUM(EC_F_NAME IS NULL) + SUM(EC_L_NAME IS NULL) + SUM(EC_CON_NO IS NULL) + SUM(B_TYPE IS NULL) + SUM(MAR_ST IS NULL) + SUM(NAT_ID_S IS NULL) + SUM(NAT_ID_T IS NULL) + SUM(NAT_ID_N IS NULL) + SUM(NAT_ID_E IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_patient;


-- 2. Allergy Table (stg_allergy) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(ALG_ID IS NULL) AS null_ALG_ID,
    SUM(ALG_NAME IS NULL) AS null_ALG_NAME,
    IF(SUM(ALG_ID IS NULL) + SUM(ALG_NAME IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_allergy;


-- 3. Appointment Table (stg_appointment) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(APT_TIME IS NULL) AS null_APT_TIME,
    SUM(CTD_ID IS NULL) AS null_CTD_ID,
    SUM(DOC_ID IS NULL) AS null_DOC_ID,
    SUM(ASTAT_CD IS NULL) AS null_ASTAT_CD,
    SUM(ASTAT_DES IS NULL) AS null_ASTAT_DES,
    SUM(ATYPE_CD IS NULL) AS null_ATYPE_CD,
    SUM(ATYPE_DES IS NULL) AS null_ATYPE_DES,
    IF(SUM(REFR_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(APT_TIME IS NULL) + SUM(CTD_ID IS NULL) + SUM(DOC_ID IS NULL) + SUM(ASTAT_CD IS NULL) + SUM(ASTAT_DES IS NULL) + SUM(ATYPE_CD IS NULL) + SUM(ATYPE_DES IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_appointment;


-- 4. Bill Table (stg_billing) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(BILL_DATE IS NULL) AS null_BILL_DATE,
    SUM(BILL_AMT IS NULL) AS null_BILL_AMT,
    SUM(BSTAT_CD IS NULL) AS null_BSTAT_CD,
    SUM(BSTAT_DES IS NULL) AS null_BSTAT_DES,
    SUM(BTYPE_CD IS NULL) AS null_BTYPE_CD,
    IF(SUM(REFR_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(BILL_DATE IS NULL) + SUM(BILL_AMT IS NULL) + SUM(BSTAT_CD IS NULL) + SUM(BSTAT_DES IS NULL) + SUM(BTYPE_CD IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_billing;


-- 5. Diagnosis Table (stg_diagnosis) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(DIG_TOT IS NULL) AS null_DIG_TOT,
    SUM(DIG_EN IS NULL) AS null_DIG_EN,
    SUM(DIG_SEQ IS NULL) AS null_DIG_SEQ,
    SUM(DIG_CD IS NULL) AS null_DIG_CD,
    SUM(DIG_DES IS NULL) AS null_DIG_DES,
    SUM(DSTAT_CD IS NULL) AS null_DSTAT_CD,
    SUM(DSTAT_DES IS NULL) AS null_DSTAT_DES,
    SUM(DTYPE_CD IS NULL) AS null_DTYPE_CD,
    SUM(DTYPE_DES IS NULL) AS null_DTYPE_DES,
    SUM(ROM_ID IS NULL) AS null_ROM_ID,
    IF(SUM(REFR_NO IS NULL) + SUM(DIG_TOT IS NULL) + SUM(DIG_EN IS NULL) + SUM(DIG_SEQ IS NULL) + SUM(DIG_CD IS NULL) + SUM(DIG_DES IS NULL) + SUM(DSTAT_CD IS NULL) + SUM(DSTAT_DES IS NULL) + SUM(DTYPE_CD IS NULL) + SUM(DTYPE_DES IS NULL) + SUM(ROM_ID IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_diagnosis;


-- 6. Department Table (stg_department) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(DEP_ID IS NULL) AS null_DEP_ID,
    SUM(DEP_NAME IS NULL) AS null_DEP_NAME,
    SUM(DEP_DES IS NULL) AS null_DEP_DES,
    SUM(DEP_LOC IS NULL) AS null_DEP_LOC,
    IF(SUM(DEP_ID IS NULL) + SUM(DEP_NAME IS NULL) + SUM(DEP_DES IS NULL) + SUM(DEP_LOC IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_department;


-- 7. Equipment Table (stg_equipment) - FAIL, null_EQP_CAT__3 - 338 nulls
SELECT 
    COUNT(*) AS total_rows,
    SUM(EQP_ID IS NULL) AS null_EQP_ID,
    SUM(EQP_NAME IS NULL) AS null_EQP_NAME,
    SUM(TYPE_CD IS NULL) AS null_TYPE_CD,
    SUM(TYPE_DES IS NULL) AS null_TYPE_DES,
    SUM(EQP_CAT__1 IS NULL) AS null_EQP_CAT__1,
    SUM(EQP_CAT__2 IS NULL) AS null_EQP_CAT__2,
    SUM(EQP_CAT__3 IS NULL) AS null_EQP_CAT__3,
    SUM(MODL_NO IS NULL) AS null_MODL_NO,
    SUM(STRG_LOC IS NULL) AS null_STRG_LOC,
    SUM(ESTAT_CD IS NULL) AS null_ESTAT_CD,
    SUM(ESTAT_DES IS NULL) AS null_ESTAT_DES,
    IF(SUM(EQP_ID IS NULL) + SUM(EQP_NAME IS NULL) + SUM(TYPE_CD IS NULL) + SUM(TYPE_DES IS NULL) + SUM(EQP_CAT__1 IS NULL) + SUM(EQP_CAT__2 IS NULL) + SUM(EQP_CAT__3 IS NULL) + SUM(MODL_NO IS NULL) + SUM(STRG_LOC IS NULL) + SUM(ESTAT_CD IS NULL) + SUM(ESTAT_DES IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_equipment;


-- 8. Insurance Table (stg_insurance) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(POL_NO IS NULL) AS null_POL_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(COM_NAME IS NULL) AS null_COM_NAME,
    SUM(ITYPE_CD IS NULL) AS null_ITYPE_CD,
    SUM(ITYPE_DES IS NULL) AS null_ITYPE_DES,
    SUM(POL_ST IS NULL) AS null_POL_ST,
    SUM(POL_ED IS NULL) AS null_POL_ED,
    SUM(ISTAT_CD IS NULL) AS null_ISTAT_CD,
    SUM(ISTAT_DES IS NULL) AS null_ISTAT_DES,
    SUM(CON_NO IS NULL) AS null_CON_NO,
    IF(SUM(POL_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(COM_NAME IS NULL) + SUM(ITYPE_CD IS NULL) + SUM(ITYPE_DES IS NULL) + SUM(POL_ST IS NULL) + SUM(POL_ED IS NULL) + SUM(ISTAT_CD IS NULL) + SUM(ISTAT_DES IS NULL) + SUM(CON_NO IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_insurance;


-- 9. Medicine Bill Table (stg_medicine_bill) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(BILL_DATE IS NULL) AS null_BILL_DATE,
    SUM(BILL_AMT IS NULL) AS null_BILL_AMT,
    SUM(BSTAT_CD IS NULL) AS null_BSTAT_CD,
    SUM(BSTAT_DES IS NULL) AS null_BSTAT_DES,
    SUM(BTYPE_CD IS NULL) AS null_BTYPE_CD,
    IF(SUM(REFR_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(BILL_DATE IS NULL) + SUM(BILL_AMT IS NULL) + SUM(BSTAT_CD IS NULL) + SUM(BSTAT_DES IS NULL) + SUM(BTYPE_CD IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_medicine_bill;


-- 10. Medicine Table (stg_medicine) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(MED_ID IS NULL) AS null_MED_ID,
    SUM(MED_NAME IS NULL) AS null_MED_NAME,
    SUM(TYPE_CD IS NULL) AS null_TYPE_CD,
    SUM(TYPE_DES IS NULL) AS null_TYPE_DES,
    SUM(FORM_CD IS NULL) AS null_FORM_CD,
    SUM(FORM_DES IS NULL) AS null_FORM_DES,
    SUM(STRN_NO IS NULL) AS null_STRN_NO,
    SUM(STRN_UN IS NULL) AS null_STRN_UN,
    SUM(STRG_CD IS NULL) AS null_STRG_CD,
    SUM(STRG_DES IS NULL) AS null_STRG_DES,
    SUM(FMQTY_NO IS NULL) AS null_FMQTY_NO,
    SUM(FMQTY_UN IS NULL) AS null_FMQTY_UN,
    SUM(MSTAT_CD IS NULL) AS null_MSTAT_CD,
    SUM(MSTAT_DES IS NULL) AS null_MSTAT_DES,
    SUM(EXP_MON IS NULL) AS null_EXP_MON,
    SUM(UN_P_CS IS NULL) AS null_UN_P_CS,
    SUM(COST_UN IS NULL) AS null_COST_UN,
    IF(SUM(MED_ID IS NULL) + SUM(MED_NAME IS NULL) + SUM(TYPE_CD IS NULL) + SUM(TYPE_DES IS NULL) + SUM(FORM_CD IS NULL) + SUM(FORM_DES IS NULL) + SUM(STRN_NO IS NULL) + SUM(STRN_UN IS NULL) + SUM(STRG_CD IS NULL) + SUM(STRG_DES IS NULL) + SUM(FMQTY_NO IS NULL) + SUM(FMQTY_UN IS NULL) + SUM(MSTAT_CD IS NULL) + SUM(MSTAT_DES IS NULL) + SUM(EXP_MON IS NULL) + SUM(UN_P_CS IS NULL) + SUM(COST_UN IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_medicine;


-- 11. Medical Team Table (stg_medical_team) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(MEDT_ID IS NULL) AS null_MEDT_ID,
    SUM(TEAM_NO IS NULL) AS null_TEAM_NO,
    SUM(STF_ID IS NULL) AS null_STF_ID,
    SUM(ROLE_CD IS NULL) AS null_ROLE_CD,
    SUM(ROLE_DES IS NULL) AS null_ROLE_DES,
    IF(SUM(MEDT_ID IS NULL) + SUM(TEAM_NO IS NULL) + SUM(STF_ID IS NULL) + SUM(ROLE_CD IS NULL) + SUM(ROLE_DES IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_medical_team;


-- 12. Payment Table (stg_payment) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(BTYPE_CD IS NULL) AS null_BTYPE_CD,
    SUM(TOT_PMNT IS NULL) AS null_TOT_PMNT,
    SUM(PMNT_TMS IS NULL) AS null_PMNT_TMS,
    SUM(PMNT_NO IS NULL) AS null_PMNT_NO,
    SUM(PMNT_DATE IS NULL) AS null_PMNT_DATE,
    SUM(PMNT_AMT IS NULL) AS null_PMNT_AMT,
    SUM(METH_CD IS NULL) AS null_METH_CD,
    SUM(METH_DES IS NULL) AS null_METH_DES,
    SUM(PSTAT_CD IS NULL) AS null_PSTAT_CD,
    SUM(PSTAT_DES IS NULL) AS null_PSTAT_DES,
    SUM(PMNT_IF IS NULL) AS null_PMNT_IF,
    IF(SUM(REFR_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(BTYPE_CD IS NULL) + SUM(TOT_PMNT IS NULL) + SUM(PMNT_TMS IS NULL) + SUM(PMNT_NO IS NULL) + SUM(PMNT_DATE IS NULL) + SUM(PMNT_AMT IS NULL) + SUM(METH_CD IS NULL) + SUM(METH_DES IS NULL) + SUM(PSTAT_CD IS NULL) + SUM(PSTAT_DES IS NULL) + SUM(PMNT_IF IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_payment;


-- 13. Patient Allergy Table (stg_patient_allergy) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(ALG_ID IS NULL) AS null_ALG_ID,
    SUM(SVR_CD IS NULL) AS null_SVR_CD,
    SUM(SVR_DES IS NULL) AS null_SVR_DES,
    SUM(RCT_CD IS NULL) AS null_RCT_CD,
    SUM(RCT_DES IS NULL) AS null_RCT_DES,
    IF(SUM(PAT_ID IS NULL) + SUM(ALG_ID IS NULL) + SUM(SVR_CD IS NULL) + SUM(SVR_DES IS NULL) + SUM(RCT_CD IS NULL) + SUM(RCT_DES IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_patient_allergy;


-- 14. Rooms Table (stg_rooms) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(ROM_ID IS NULL) AS null_ROM_ID,
    SUM(DEP_ID IS NULL) AS null_DEP_ID,
    SUM(PRPS_CD IS NULL) AS null_PRPS_CD,
    SUM(PRPS_DES IS NULL) AS null_PRPS_DES,
    SUM(RTYPE_CD IS NULL) AS null_RTYPE_CD,
    SUM(RTYPE_DES IS NULL) AS null_RTYPE_DES,
    SUM(CPCT_NO IS NULL) AS null_CPCT_NO,
    IF(SUM(ROM_ID IS NULL) + SUM(DEP_ID IS NULL) + SUM(PRPS_CD IS NULL) + SUM(PRPS_DES IS NULL) + SUM(RTYPE_CD IS NULL) + SUM(RTYPE_DES IS NULL) + SUM(CPCT_NO IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_rooms;


-- 15. Supply Table (stg_supply) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(SPL_ID IS NULL) AS null_SPL_ID,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(VEN_ACC IS NULL) AS null_VEN_ACC,
    SUM(BTCH_NO IS NULL) AS null_BTCH_NO,
    SUM(BTCH_SZ IS NULL) AS null_BTCH_SZ,
    SUM(MFG_DATE IS NULL) AS null_MFG_DATE,
    SUM(SPL_QTY IS NULL) AS null_SPL_QTY,
    SUM(SPL_UOM IS NULL) AS null_SPL_UOM,
    SUM(SPL_UCT IS NULL) AS null_SPL_UCT,
    SUM(WHS_LOC IS NULL) AS null_WHS_LOC,
    SUM(PAL_ID IS NULL) AS null_PAL_ID,
    SUM(RCVD_DATE IS NULL) AS null_RCVD_DATE,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(VRFC_DATE IS NULL) AS null_VRFC_DATE,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(SPL_ID IS NULL) + SUM(MAT_SKU IS NULL) + SUM(VEN_ACC IS NULL) + SUM(BTCH_NO IS NULL) + SUM(BTCH_SZ IS NULL) + SUM(MFG_DATE IS NULL) + SUM(SPL_QTY IS NULL) + SUM(SPL_UOM IS NULL) + SUM(SPL_UCT IS NULL) + SUM(WHS_LOC IS NULL) + SUM(PAL_ID IS NULL) + SUM(RCVD_DATE IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(VRFC_DATE IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_supply;


-- 16. Staff Table (stg_staff) - PASS
SELECT 
    COUNT(*) AS total_rows,	
    SUM(STF_ID IS NULL) AS null_STF_ID,
    SUM(F_NAME IS NULL) AS null_F_NAME,
    SUM(L_NAME IS NULL) AS null_L_NAME,
    -- M_NAME is not part of the null check since some staff do not have one and that is still acceptable
    SUM(GEN_CD IS NULL) AS null_GEN_CD,
    SUM(GEN_DES IS NULL) AS null_GEN_DES,
    SUM(DT_BRT IS NULL) AS null_DT_BRT,
    SUM(DEP_ID IS NULL) AS null_DEP_ID,
    SUM(ROLE_CD IS NULL) AS null_ROLE_CD,
    SUM(ROLE_DES IS NULL) AS null_ROLE_DES,
    SUM(CON_NO IS NULL) AS null_CON_NO,
    SUM(EM_ADD IS NULL) AS null_EM_ADD,
    SUM(STAT_CD IS NULL) AS null_STAT_CD,
    SUM(STAT_DES IS NULL) AS null_STAT_DES,
    SUM(HIRE_DATE IS NULL) AS null_HIRE_DATE,
    SUM(ROLE_DATE IS NULL) AS null_ROLE_DATE,
    SUM(SAL_YR IS NULL) AS null_SAL_YR,
    SUM(SAL_MN IS NULL) AS null_SAL_MN,
    SUM(INGST_TMSTMP IS NULL) AS null_INGST_TMSTMP,
    IF(SUM(STF_ID IS NULL) + SUM(F_NAME IS NULL) + SUM(L_NAME IS NULL) + SUM(GEN_CD IS NULL) + SUM(GEN_DES IS NULL) + SUM(DT_BRT IS NULL) + SUM(DEP_ID IS NULL) + SUM(ROLE_CD IS NULL) + SUM(ROLE_DES IS NULL) + SUM(CON_NO IS NULL) + SUM(EM_ADD IS NULL) + SUM(STAT_CD IS NULL) + SUM(STAT_DES IS NULL) + SUM(HIRE_DATE IS NULL) + SUM(ROLE_DATE IS NULL) + SUM(SAL_YR IS NULL) + SUM(SAL_MN IS NULL) + SUM(INGST_TMSTMP IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_staff;


-- 17. Medicine Used in Treatment Table (stg_treatment_med) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(MEDS_TOT IS NULL) AS null_MEDS_TOT,
    SUM(MEDS_SEQ IS NULL) AS null_MEDS_SEQ,
    SUM(MED_ID IS NULL) AS null_MED_ID,
    SUM(QTY_NO IS NULL) AS null_QTY_NO,
    SUM(DOS_CD IS NULL) AS null_DOS_CD,
    SUM(DOS_DES IS NULL) AS null_DOS_DES,
    SUM(FREQ_CD IS NULL) AS null_FREQ_CD,
    SUM(FREQ_DES IS NULL) AS null_FREQ_DES,
    SUM(RUTE_CD IS NULL) AS null_RUTE_CD,
    SUM(RUTE_DES IS NULL) AS null_RUTE_DES,
    SUM(UNIT_DOS IS NULL) AS null_UNIT_DOS,
    IF(SUM(REFR_NO IS NULL) + SUM(MEDS_TOT IS NULL) + SUM(MEDS_SEQ IS NULL) + SUM(MED_ID IS NULL) + SUM(QTY_NO IS NULL) + SUM(DOS_CD IS NULL) + SUM(DOS_DES IS NULL) + SUM(FREQ_CD IS NULL) + SUM(FREQ_DES IS NULL) + SUM(RUTE_CD IS NULL) + SUM(RUTE_DES IS NULL) + SUM(UNIT_DOS IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_treatment_med;


-- 18. Treatment Table (stg_treatment) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(TRTM_TOT IS NULL) AS null_TRTM_TOT,
    SUM(TRTM_EN IS NULL) AS null_TRTM_EN,
    SUM(TTYPE_CD IS NULL) AS null_TTYPE_CD,
    SUM(TTYPE_DES IS NULL) AS null_TTYPE_DES,
    SUM(TRTM_CD IS NULL) AS null_TRTM_CD,
    SUM(TSTAT_CD IS NULL) AS null_TSTAT_CD,
    SUM(TRTM_DES IS NULL) AS null_TRTM_DES,
    SUM(TSTAT_DES IS NULL) AS null_TSTAT_DES,
    SUM(TRTM_SEQ IS NULL) AS null_TRTM_SEQ,
    IF(SUM(REFR_NO IS NULL) + SUM(TRTM_TOT IS NULL) + SUM(TRTM_EN IS NULL) + SUM(TTYPE_CD IS NULL) + SUM(TTYPE_DES IS NULL) + SUM(TRTM_CD IS NULL) + SUM(TSTAT_CD IS NULL) + SUM(TRTM_DES IS NULL) + SUM(TSTAT_DES IS NULL) + SUM(TRTM_SEQ IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_treatment;


-- 19. Visits Table (stg_visit) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(PAT_ID IS NULL) AS null_PAT_ID,
    SUM(MEDT_ID IS NULL) AS null_MEDT_ID,
    SUM(VIS_EN IS NULL) AS null_VIS_EN,
    SUM(VIS_EX IS NULL) AS null_VIS_EX,
    SUM(VSTAT_CD IS NULL) AS null_VSTAT_CD,
    SUM(VSTAT_DES IS NULL) AS null_VSTAT_DES,
    SUM(VTYPE_CD IS NULL) AS null_VTYPE_CD,
    SUM(VTYPE_DES IS NULL) AS null_VTYPE_DES,
    -- ROM_ID is not part of the null check due to outpatient visits
    IF(SUM(REFR_NO IS NULL) + SUM(PAT_ID IS NULL) + SUM(MEDT_ID IS NULL) + SUM(VIS_EN IS NULL) + SUM(VIS_EX IS NULL) + SUM(VSTAT_CD IS NULL) + SUM(VSTAT_DES IS NULL) + SUM(VTYPE_CD IS NULL) + SUM(VTYPE_DES IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_visit;


-- 20. Vendor Table (stg_vendor) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(VEN_ACC IS NULL) AS null_VEN_ACC,
    SUM(VEN_NAME IS NULL) AS null_VEN_NAME,
    SUM(VEN_TYPE IS NULL) AS null_VEN_TYPE,
    SUM(LCNS_NO IS NULL) AS null_LCNS_NO,
    SUM(CTRY_NAME IS NULL) AS null_CTRY_NAME,
    SUM(CTRY_CD IS NULL) AS null_CTRY_CD,
    SUM(CTRY_CON_NO IS NULL) AS null_CTRY_CON_NO,
    SUM(VSTAT_CD IS NULL) AS null_VSTAT_CD,
    SUM(VSTAT_DES IS NULL) AS null_VSTAT_DES,
    SUM(INGST_TMSTMP IS NULL) AS null_INGST_TMSTMP,
    IF(SUM(VEN_ACC IS NULL) + SUM(VEN_NAME IS NULL) + SUM(VEN_TYPE IS NULL) + SUM(LCNS_NO IS NULL) + SUM(CTRY_NAME IS NULL) + SUM(CTRY_CD IS NULL) + SUM(CTRY_CON_NO IS NULL) + SUM(VSTAT_CD IS NULL) + SUM(VSTAT_DES IS NULL) + SUM(INGST_TMSTMP IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_vendor;


-- 21. Vendor Payment Table (stg_vendor_payment) - PASS
SELECT 
    COUNT(*) AS total_rows,
    SUM(REFR_NO IS NULL) AS null_REFR_NO,
    SUM(SPL_ID IS NULL) AS null_SPL_ID,
    SUM(SPL_CST IS NULL) AS null_SPL_CST,
    SUM(PMNT_TRM IS NULL) AS null_PMNT_TRM,
    SUM(TRM_NO IS NULL) AS null_TRM_NO,
    SUM(VPMT_AMT IS NULL) AS null_VPMT_AMT,
    SUM(PMNT_DATE IS NULL) AS null_PMNT_DATE,
    SUM(PMNT_DUE IS NULL) AS null_PMNT_DUE,
    SUM(VPSTATUS_CD IS NULL) AS null_VPSTATUS_CD,
    SUM(VPSTATUS_DES IS NULL) AS null_VPSTATUS_DES,
    SUM(VEN_ACC IS NULL) AS null_VEN_ACC,
    SUM(ACC_NO IS NULL) AS null_ACC_NO,
    SUM(WRE_NO IS NULL) AS null_WRE_NO,
    IF(SUM(REFR_NO IS NULL) + SUM(SPL_ID IS NULL) + SUM(SPL_CST IS NULL) + SUM(PMNT_TRM IS NULL) + SUM(TRM_NO IS NULL) + SUM(VPMT_AMT IS NULL) + SUM(PMNT_DATE IS NULL) + SUM(PMNT_DUE IS NULL) + SUM(VPSTATUS_CD IS NULL) + SUM(VPSTATUS_DES IS NULL) + SUM(VEN_ACC IS NULL) + SUM(ACC_NO IS NULL) + SUM(WRE_NO IS NULL) = 0, 'PASS', 'FAIL') AS null_check
FROM healthcare.stg_vendor_payment;


-- 22. Inventory Table (stg_inventory)
-- Batch 1: Series 1 (~14 Million Rows) - PASS
SELECT 
    'INVN Series 1' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_1_%';


-- Batch 2: Series 2 (~14 Million Rows) - PASS
SELECT 
    'INVN Series 2' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_2_%';


-- Batch 3: Series 3 (~14 Million Rows) - PASS
SELECT 	
    'INVN Series 3' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_3_%';


-- Batch 4: Series 4 (~14 Million Rows) - PASS
SELECT 
    'INVN Series 4' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_4_%';


-- Batch 5: Series 5 (~17 Million Rows) - PASS
SELECT 
    'INVN Series 5' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_5_%';


-- Batch 6: Series 6 (~17 Million Rows) - Pass
SELECT 
    'INVN Series 6' AS batch_name,
    COUNT(*) AS total_rows,
    SUM(MAT_SKU IS NULL) AS null_MAT_SKU,
    SUM(INGTN_TS IS NULL) AS null_INGTN_TS,
    SUM(OPEN_QTY IS NULL) AS null_OPEN_QTY,
    SUM(OPEN_STF IS NULL) AS null_OPEN_STF,
    SUM(RCVD_QTY IS NULL) AS null_RCVD_QTY,
    SUM(RCVD_STF IS NULL) AS null_RCVD_STF,
    SUM(ISSD_QTY IS NULL) AS null_ISSD_QTY,
    SUM(ISSD_STF IS NULL) AS null_ISSD_STF,
    SUM(CLSD_QTY IS NULL) AS null_CLSD_QTY,
    SUM(CLSD_STF IS NULL) AS null_CLSD_STF,
    SUM(VRFC_STF IS NULL) AS null_VRFC_STF,
    IF(SUM(MAT_SKU IS NULL) + SUM(INGTN_TS IS NULL) + SUM(OPEN_QTY IS NULL) + SUM(OPEN_STF IS NULL) + SUM(RCVD_QTY IS NULL) + SUM(RCVD_STF IS NULL) + SUM(ISSD_QTY IS NULL) + SUM(ISSD_STF IS NULL) + SUM(CLSD_QTY IS NULL) + SUM(CLSD_STF IS NULL) + SUM(VRFC_STF IS NULL) = 0, 'PASS', 'FAIL') AS batch_null_check
FROM healthcare.stg_inventory
WHERE src_file LIKE 'STG_EHP__INVN_6_%';

 
-- C. DUPLICATES
-- CHECKS UNIQUE ID, COMPOSITE KEY, OR EXACT ROW
-- SUCCESSFUL IF RETURNS 0 ROWS

-- 1. Patients: Unique PAT_ID
SELECT PAT_ID, COUNT(*) AS dup_count
FROM stg_patient
GROUP BY PAT_ID
HAVING COUNT(*) > 1;

-- 2. Allergy Lookup: Unique ALG_ID
SELECT ALG_ID, COUNT(*) AS dup_count
FROM stg_allergy
GROUP BY ALG_ID
HAVING COUNT(*) > 1;

-- 3. Appointments: Unique REFR_NO
SELECT REFR_NO, COUNT(*) AS dup_count
FROM stg_appointment
GROUP BY REFR_NO
HAVING COUNT(*) > 1;

-- 4. Billing: Exact Row
SELECT REFR_NO, PAT_ID, BILL_DATE, BILL_AMT, BSTAT_CD, BSTAT_DES, BTYPE_CD, COUNT(*) AS exact_dup_count
FROM stg_billing
GROUP BY REFR_NO, PAT_ID, BILL_DATE, BILL_AMT, BSTAT_CD, BSTAT_DES, BTYPE_CD
HAVING COUNT(*) > 1;

-- 5. Diagnosis: Composite Key (REFR_NO + DIG_SEQ)
SELECT REFR_NO, DIG_SEQ, COUNT(*) AS dup_count
FROM stg_diagnosis
GROUP BY REFR_NO, DIG_SEQ
HAVING COUNT(*) > 1;

-- 6. Departments: Unique DEP_ID
SELECT DEP_ID, COUNT(*) AS dup_count
FROM stg_department
GROUP BY DEP_ID
HAVING COUNT(*) > 1;

-- 7. Equipment: Unique EQP_ID
SELECT EQP_ID, COUNT(*) AS dup_count
FROM stg_equipment
GROUP BY EQP_ID
HAVING COUNT(*) > 1;

-- 8. Insurance: Unique POL_NO
SELECT POL_NO, COUNT(*) AS dup_count
FROM stg_insurance
GROUP BY POL_NO
HAVING COUNT(*) > 1;

-- 9. Medicine Bills: Exact Row
SELECT REFR_NO, PAT_ID, BILL_DATE, BILL_AMT, BSTAT_CD, BSTAT_DES, BTYPE_CD,  COUNT(*) AS dup_count
FROM stg_medicine_bill
GROUP BY REFR_NO, PAT_ID, BILL_DATE, BILL_AMT, BSTAT_CD, BSTAT_DES, BTYPE_CD
HAVING COUNT(*) > 1;

-- 10. Medicine Master: Unique MED_ID
SELECT MED_ID, COUNT(*) AS dup_count
FROM stg_medicine
GROUP BY MED_ID
HAVING COUNT(*) > 1;

-- 11. Medical Team Assignment: Exact Row
SELECT MEDT_ID, TEAM_NO, STF_ID, ROLE_CD, ROLE_DES, COUNT(*) AS dup_count -- still has duplicates
FROM stg_medical_team
GROUP BY MEDT_ID, TEAM_NO, STF_ID, ROLE_CD, ROLE_DES
HAVING COUNT(*) > 1;

-- 12. Payment: Composite Key (REFR_NO + PMNT_NO)
SELECT REFR_NO, PMNT_NO, COUNT(*) AS dup_count -- lost connection error
FROM stg_payment
GROUP BY REFR_NO, PMNT_NO
HAVING COUNT(*) > 1;

-- 13. Patient Allergy: Exact Row -- has duplicates
SELECT PAT_ID, ALG_ID, SVR_CD, SVR_DES, RCT_CD, RCT_DES, COUNT(*) AS dup_count
FROM stg_patient_allergy
GROUP BY PAT_ID, ALG_ID, SVR_CD, SVR_DES, RCT_CD, RCT_DES
HAVING COUNT(*) > 1;

-- 14. Rooms: Exact Row
SELECT ROM_ID, DEP_ID, PRPS_CD, PRPS_DES, RTYPE_CD, RTYPE_DES, CPCT_NO, COUNT(*) AS dup_count
FROM stg_rooms
GROUP BY ROM_ID, DEP_ID, PRPS_CD, PRPS_DES, RTYPE_CD, RTYPE_DES, CPCT_NO 
HAVING COUNT(*) > 1;

-- 15. Supply: Unique SPL_ID
SELECT SPL_ID, COUNT(*) AS dup_count
FROM stg_supply
GROUP BY SPL_ID
HAVING COUNT(*) > 1;

-- 16. Staff: Composite Key
SELECT STF_ID, HIRE_DATE, COUNT(*) AS dup_count
FROM stg_staff
GROUP BY STF_ID, HIRE_DATE 
HAVING COUNT(*) > 1;

-- 17. Treatment Medicines: Composite Key (REFR_NO + MEDS_SEQ + MED_ID)
SELECT REFR_NO, MEDS_SEQ, MED_ID, COUNT(*) AS dup_count
FROM stg_treatment_med
GROUP BY REFR_NO, MEDS_SEQ, MED_ID
HAVING COUNT(*) > 1;

-- 18. Treatment: Composite Key (REFR_NO + TRTM_SEQ)
SELECT REFR_NO, TRTM_SEQ, COUNT(*) AS dup_count -- lost connection error
FROM stg_treatment
GROUP BY REFR_NO, TRTM_SEQ
HAVING COUNT(*) > 1;

-- 19. Visits: Composite Key
SELECT REFR_NO, VIS_EN, VIS_EX, COUNT(*) AS dup_count
FROM stg_visit
GROUP BY REFR_NO, VIS_EN, VIS_EX
HAVING COUNT(*) > 1;

-- 20. Vendor: Unique VEN_ACC
SELECT VEN_ACC, COUNT(*) AS dup_count
FROM stg_vendor
GROUP BY VEN_ACC
HAVING COUNT(*) > 1;

-- 21. Vendor Payment: Composite Key (REFR_NO + TRM_NO)
SELECT REFR_NO, TRM_NO, COUNT(*) AS dup_count -- lost connection error
FROM stg_vendor_payment
GROUP BY REFR_NO, TRM_NO
HAVING COUNT(*) > 1;

-- 22. Inventory Snapshot: Composite Key (MAT_SKU + INGTN_TS)
SELECT MAT_SKU, INGTN_TS, COUNT(*) AS dup_count -- lost connection error
FROM stg_inventory
GROUP BY MAT_SKU, INGTN_TS
HAVING COUNT(*) > 1;

-- stg_staff has duplicate rows (!!)
-- ISSUE: stg_staff.STF_ID is not unique per person
	-- 5496 duplicate rows, 5411 distinct STF_ID
	-- 83 STF_IDs are shared by different people with different names and roles
	-- 81 IDs have 2 rows, 2 IDs have 3 rows
	-- 74/83 shared IDs have no 'Doctor' candidate, 9 have exactly one Doctor candidate
-- WHY IT LIKELY HAPPENED: dataset is synthetic and has no documentation of its own
	-- likely what happened was IDs were assigned at random without a uniqueness check
	-- another likely reason is that staff files from different generation batches or sources were merged leading to duplicate batch issued IDs
	-- a less likely cause is that IDs were recycled after staff left,
    
-- 0a. Staging column types (for reference; tighten target types from this) 
SELECT COLUMN_NAME, COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'healthcare' AND TABLE_NAME = 'stg_staff'
ORDER BY ORDINAL_POSITION;
 
-- 0b. Source quality - PASS
SELECT 'stg_staff has rows' AS check_name,
       COUNT(*) AS found,
       IF(COUNT(*) > 0, 'PASS', 'FAIL') AS result
FROM stg_staff
UNION ALL
SELECT 'no NULL STF_ID',
       COALESCE(SUM(STF_ID IS NULL), 0),
       IF(COALESCE(SUM(STF_ID IS NULL), 0) = 0, 'PASS', 'FAIL')
FROM stg_staff
UNION ALL
SELECT 'STF_ID + HIRE_DATE unique (grain of dim_staff)',
       COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'FAIL')
FROM (SELECT 1 FROM stg_staff
      GROUP BY STF_ID, HIRE_DATE HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'same person repeated under one STF_ID (would get 2 keys)',
       COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'REVIEW')
FROM (SELECT 1 FROM stg_staff
      GROUP BY STF_ID, F_NAME, L_NAME, DT_BRT HAVING COUNT(*) > 1) d;
 
-- 0c. Does the data fit the target types? found must be <= allowed. - PASS, except DT_BRT, HIRE_DATE, ROLE_DATE
--     Length rows compare the longest value to the column size. Date rows
--     count values that are not in YYYY-MM-DD form (expect 0). If a date
--     column uses another format, change the INSERT in STEP 2 to
--     STR_TO_DATE(col, '<format>') and this check to match.
SELECT check_name, found, allowed,
       IF(COALESCE(found, 0) <= allowed, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'STF_ID length (staff_id VARCHAR(20))' AS check_name,
           MAX(CHAR_LENGTH(STF_ID)) AS found, 20 AS allowed FROM stg_staff
    UNION ALL SELECT 'F_NAME length (first_name VARCHAR(50))',
           MAX(CHAR_LENGTH(F_NAME)), 50 FROM stg_staff
    UNION ALL SELECT 'M_NAME length (middle_name VARCHAR(50))',
           MAX(CHAR_LENGTH(M_NAME)), 50 FROM stg_staff
    UNION ALL SELECT 'L_NAME length (last_name VARCHAR(50))',
           MAX(CHAR_LENGTH(L_NAME)), 50 FROM stg_staff
    UNION ALL SELECT 'GEN_CD length (gender_code VARCHAR(10))',
           MAX(CHAR_LENGTH(GEN_CD)), 10 FROM stg_staff
    UNION ALL SELECT 'GEN_DES length (gender_desc VARCHAR(30))',
           MAX(CHAR_LENGTH(GEN_DES)), 30 FROM stg_staff
    UNION ALL SELECT 'DEP_ID length (dept_id VARCHAR(10))',
           MAX(CHAR_LENGTH(DEP_ID)), 10 FROM stg_staff
    UNION ALL SELECT 'ROLE_CD length (role_code VARCHAR(10))',
           MAX(CHAR_LENGTH(ROLE_CD)), 10 FROM stg_staff
    UNION ALL SELECT 'ROLE_DES length (role_desc VARCHAR(50))',
           MAX(CHAR_LENGTH(ROLE_DES)), 50 FROM stg_staff
    UNION ALL SELECT 'STAT_CD length (stat_code VARCHAR(10))',
           MAX(CHAR_LENGTH(STAT_CD)), 10 FROM stg_staff
    UNION ALL SELECT 'STAT_DES length (stat_desc VARCHAR(30))',
           MAX(CHAR_LENGTH(STAT_DES)), 30 FROM stg_staff
    UNION ALL SELECT 'DT_BRT not a valid date (date_of_birth)',
           COUNT(*), 0 FROM stg_staff
           WHERE DT_BRT IS NOT NULL AND STR_TO_DATE(DT_BRT, '%Y-%m-%d') IS NULL
    UNION ALL SELECT 'HIRE_DATE not a valid date (hire_date)',
           COUNT(*), 0 FROM stg_staff
           WHERE HIRE_DATE IS NOT NULL AND STR_TO_DATE(HIRE_DATE, '%Y-%m-%d') IS NULL
    UNION ALL SELECT 'ROLE_DATE not a valid date (role_date)',
           COUNT(*), 0 FROM stg_staff
           WHERE ROLE_DATE IS NOT NULL AND STR_TO_DATE(ROLE_DATE, '%Y-%m-%d') IS NULL
) t;
 
-- 0d. Strict mode makes MySQL stop with an error instead of silently - PASS
--     cutting off values that do not fit.
SELECT @@SESSION.sql_mode AS sql_mode,
       IF(@@SESSION.sql_mode LIKE '%STRICT_TRANS_TABLES%'
          OR @@SESSION.sql_mode LIKE '%STRICT_ALL_TABLES%', 'PASS', 'FAIL') AS result;

-- stg_rooms has duplicate room IDs (!!)
-- ISSUE: stg_rooms.ROM_ID is not unique per room
    -- 4 ROM_IDs are duplicated, each appearing twice
    -- 4 shared ROM_IDs have conflicting room attributes
    -- J91861R: Laboratory (Compact, capacity 3) vs General Care (Large, capacity 11)
    -- J93049V: Intensive Care (Extra Large, capacity 19) vs Staff (Compact, capacity 3)
    -- O54049W: Critical Care (Large, capacity 14) vs Laboratory (Standard, capacity 5)
    -- J90278M: also duplicated, but not referenced in stg_visit

-- IMPACT ON VISITS:
    -- 3/4 shared ROM_IDs appear in stg_visit
    -- 185 visits reference ambiguous room IDs
    -- J91861R: 62 visits
    -- J93049V: 62 visits
    -- O54049W: 61 visits
    -- J90278M: 0 visits

-- WHY IT LIKELY HAPPENED: dataset is synthetic and has no documentation
    -- likely room IDs were assigned without a uniqueness check
    -- another possibility is that records from different generation batches
	--  or sources were merged, resulting in reused room IDs
    -- a less likely possibility is that room IDs were recycled after
	-- rooms were repurposed or reassigned

-- HANDLING:
    -- retained all source records in dim_room using surrogate room_key
    -- added room_id_row_count and is_room_id_shared for identification
    -- created bridge_room_id_resolution to handle ambiguous room IDs
    -- unique ROM_IDs resolve to their corresponding room_key
    -- shared ROM_IDs resolve to -1 (Unknown) because their correct
	-- room configuration cannot be determined from ROM_ID alone
-- ============================================================
-- 0a. Staging and dimension column types (for reference)
-- ============================================================

SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'healthcare'
  AND TABLE_NAME IN ('stg_rooms', 'dim_room')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ============================================================
-- 0b. Source quality checks
-- ============================================================

SELECT 'stg_rooms has rows' AS check_name,
       COUNT(*) AS found,
       IF(COUNT(*) > 0, 'PASS', 'FAIL') AS result
FROM stg_rooms

UNION ALL

SELECT 'no NULL ROM_ID',
       COALESCE(SUM(ROM_ID IS NULL), 0),
       IF(COALESCE(SUM(ROM_ID IS NULL), 0) = 0, 'PASS', 'FAIL')
FROM stg_rooms

UNION ALL

SELECT 'duplicate ROM_ID values (expected: REVIEW)',
       COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'REVIEW')
FROM (
    SELECT ROM_ID
    FROM stg_rooms
    GROUP BY ROM_ID
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'exact duplicate room records',
       COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'REVIEW')
FROM (
    SELECT ROM_ID, DEP_ID, PRPS_CD, PRPS_DES,
           RTYPE_CD, RTYPE_DES, CPCT_NO
    FROM stg_rooms
    GROUP BY ROM_ID, DEP_ID, PRPS_CD, PRPS_DES,
             RTYPE_CD, RTYPE_DES, CPCT_NO
    HAVING COUNT(*) > 1
) d

UNION ALL

SELECT 'conflicting attributes under same ROM_ID (expected: REVIEW)',
       COUNT(*),
       IF(COUNT(*) = 0, 'PASS', 'REVIEW')
FROM (
    SELECT ROM_ID
    FROM (
        SELECT DISTINCT
               ROM_ID, DEP_ID, PRPS_CD, PRPS_DES,
               RTYPE_CD, RTYPE_DES, CPCT_NO
        FROM stg_rooms
    ) x
    GROUP BY ROM_ID
    HAVING COUNT(*) > 1
) d;


-- ============================================================
-- 0c. Does the data fit the target types?
-- Adjust allowed lengths to match your actual dim_room DDL.
-- ============================================================

SELECT check_name, found, allowed,
       IF(COALESCE(found, 0) <= allowed, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'ROM_ID length (room_id VARCHAR(20))' AS check_name,
           MAX(CHAR_LENGTH(ROM_ID)) AS found,
           20 AS allowed
    FROM stg_rooms

    UNION ALL

    SELECT 'DEP_ID length (dept_id VARCHAR(10))',
           MAX(CHAR_LENGTH(DEP_ID)), 10
    FROM stg_rooms

    UNION ALL

    SELECT 'PRPS_CD length (purpose_code VARCHAR(20))',
           MAX(CHAR_LENGTH(PRPS_CD)), 20
    FROM stg_rooms

    UNION ALL

    SELECT 'PRPS_DES length (purpose_desc VARCHAR(50))',
           MAX(CHAR_LENGTH(PRPS_DES)), 50
    FROM stg_rooms

    UNION ALL

    SELECT 'RTYPE_CD length (roomtype_code VARCHAR(20))',
           MAX(CHAR_LENGTH(RTYPE_CD)), 20
    FROM stg_rooms

    UNION ALL

    SELECT 'RTYPE_DES length (roomtype_desc VARCHAR(50))',
           MAX(CHAR_LENGTH(RTYPE_DES)), 50
    FROM stg_rooms

    UNION ALL

    SELECT 'CPCT_NO invalid integer values (capacity_num INT)',
           COUNT(*), 0
    FROM stg_rooms
    WHERE CPCT_NO IS NOT NULL
      AND TRIM(CAST(CPCT_NO AS CHAR)) NOT REGEXP '^[0-9]+$'
) t;


-- ============================================================
-- 0d. Dimension population checks
-- ============================================================

SELECT check_name, found, expected,
       IF(found = expected, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'dim_room rows = stg_rooms rows + 1 Unknown member' AS check_name,
           (SELECT COUNT(*) FROM dim_room) AS found,
           (SELECT COUNT(*) FROM stg_rooms) + 1 AS expected

    UNION ALL

    SELECT 'room_key is unique',
           (SELECT COUNT(DISTINCT room_key) FROM dim_room),
           (SELECT COUNT(*) FROM dim_room)

    UNION ALL

    SELECT 'one Unknown room member',
           (SELECT COUNT(*) FROM dim_room WHERE room_key = -1),
           1

    UNION ALL

    SELECT 'room_id_row_count correctly identifies shared IDs',
           (
               SELECT COUNT(*)
               FROM dim_room d
               WHERE d.room_key <> -1
                 AND d.room_id_row_count = (
                     SELECT COUNT(*)
                     FROM stg_rooms s
                     WHERE s.ROM_ID = d.room_id
                 )
           ),
           (SELECT COUNT(*) FROM dim_room WHERE room_key <> -1)

    UNION ALL

    SELECT 'is_room_id_shared correctly identifies duplicates',
           (
               SELECT COUNT(*)
               FROM dim_room d
               WHERE d.room_key <> -1
                 AND d.is_room_id_shared =
                     (d.room_id_row_count > 1)
           ),
           (SELECT COUNT(*) FROM dim_room WHERE room_key <> -1)

    UNION ALL

    SELECT 'dimension records with missing room_id',
           (SELECT COUNT(*)
            FROM dim_room
            WHERE room_key <> -1 AND room_id IS NULL),
           0

    UNION ALL

    SELECT 'dimension records with missing capacity',
           (SELECT COUNT(*)
            FROM dim_room
            WHERE room_key <> -1 AND capacity_num IS NULL),
           (SELECT COUNT(*) FROM stg_rooms WHERE CPCT_NO IS NULL)
) t;


-- ============================================================
-- 0e. Strict mode
-- ============================================================

SELECT @@SESSION.sql_mode AS sql_mode,
       IF(@@SESSION.sql_mode LIKE '%STRICT_TRANS_TABLES%'
          OR @@SESSION.sql_mode LIKE '%STRICT_ALL_TABLES%',
          'PASS', 'FAIL') AS result;