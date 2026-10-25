USE healthcare;

/*============================================
FINANCIAL KPIs
============================================*/
-- 1. Amounts Receivable Outstanding
-- Desc: Total amount of unpaid bills currently pending or under review.

SELECT 
	billing.REFR_NO,
    billing.BILL_AMT - COALESCE(payment.TOTAL_PAID, 0) AS UNPAID
FROM stg_billing as billing
LEFT JOIN (
	SELECT REFR_NO, SUM(PMNT_AMT) AS TOTAL_PAID
    FROM stg_payment
    GROUP BY REFR_NO
) AS payment
	ON billing.REFR_NO = payment.REFR_NO
WHERE billing.BILL_AMT - COALESCE(payment.TOTAL_PAID, 0) > 0
ORDER BY UNPAID DESC;