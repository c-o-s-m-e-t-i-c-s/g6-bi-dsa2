-- Read-only column contract; selected schema is asserted by the runner.
SELECT id,name FROM department WHERE 1=0;
SELECT id,full_name,role,department_id,active FROM staff WHERE 1=0;
SELECT id,code,full_name,birthdate,sex,contact,insurance,created_by,archived,created_at FROM patient WHERE 1=0;
SELECT id,patient_id,department_id,visit_date,wait_min,stay_hours,diagnosis,readmitted FROM visit WHERE 1=0;
SELECT id,patient_id,staff_id,appt_date,type,status FROM appointment WHERE 1=0;
SELECT id,visit_id,name,status FROM treatment WHERE 1=0;
SELECT id,patient_id,visit_id,amount,paid,issued FROM invoice WHERE 1=0;
SELECT id,vendor,amount,paid,issued FROM vendor_bill WHERE 1=0;
SELECT id,name,category,stock,reorder_level,unit_cost FROM supply WHERE 1=0;
SELECT id,staff_id,action,detail,at FROM audit_log WHERE 1=0;
