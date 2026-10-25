USE healthcare;

/*
1. Row counts
*/

SELECT 'stg_billing' AS table_name, COUNT(*) AS row_count FROM stg_billing
UNION ALL
SELECT 'stg_payment', COUNT(*) FROM stg_payment;