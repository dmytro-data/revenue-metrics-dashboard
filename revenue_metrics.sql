WITH 
monthly_payments AS (
    SELECT 
        p.user_id,
        u.language,
        u.age,
        u.has_older_device_model,
        DATE_TRUNC('month', p.payment_date)::date AS payment_month,
        SUM(p.revenue_amount_usd) AS revenue
    FROM project.games_payments p
    LEFT JOIN project.games_paid_users u 
        ON p.user_id = u.user_id
    GROUP BY 1, 2, 3, 4, 5
),

user_analysis AS (
    SELECT 
        *,
        LEAD(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS next_paid_month,
        LAG(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS prev_paid_month,
        LAG(revenue) OVER (PARTITION BY user_id ORDER BY payment_month) AS prev_revenue,
        MIN(payment_month) OVER (PARTITION BY user_id) AS first_payment_month
    FROM monthly_payments
),

active_rows AS (
    SELECT 
        user_id,
        language,
        age,
        has_older_device_model,
        payment_month AS month,
        'active' AS record_type,
        ROUND(revenue::numeric, 2) AS revenue,
        CASE WHEN payment_month = first_payment_month THEN 1 ELSE 0 END AS is_new_paid_user,
        ROUND((CASE WHEN payment_month = first_payment_month THEN revenue ELSE 0 END)::numeric, 2) AS new_mrr,
        CASE 
            WHEN prev_paid_month IS NOT NULL 
                AND prev_paid_month != (payment_month - INTERVAL '1 month')::date
            THEN 1 ELSE 0 
        END AS is_back_from_churn,
        ROUND((CASE 
            WHEN prev_paid_month IS NOT NULL 
                AND prev_paid_month != (payment_month - INTERVAL '1 month')::date
            THEN revenue ELSE 0
        END)::numeric, 2) AS back_from_churn_mrr,
        ROUND((CASE 
            WHEN prev_paid_month = (payment_month - INTERVAL '1 month')::date AND revenue > prev_revenue
            THEN revenue - prev_revenue ELSE 0
        END)::numeric, 2) AS expansion_mrr,
        ROUND((CASE 
            WHEN prev_paid_month = (payment_month - INTERVAL '1 month')::date AND revenue < prev_revenue
            THEN prev_revenue - revenue ELSE 0
        END)::numeric, 2) AS contraction_mrr,
        0 AS is_churned_user,
        0::numeric AS churned_revenue
    FROM user_analysis
),

churn_rows AS (
    SELECT 
        user_id,
        language,
        age,
        has_older_device_model,
        (payment_month + INTERVAL '1 month')::date AS month,
        'churn' AS record_type,
        0::numeric AS revenue,
        0 AS is_new_paid_user,
        0::numeric AS new_mrr,
        0 AS is_back_from_churn,
        0::numeric AS back_from_churn_mrr,
        0::numeric AS expansion_mrr,
        0::numeric AS contraction_mrr,
        1 AS is_churned_user,
        ROUND(revenue::numeric, 2) AS churned_revenue
    FROM user_analysis
    WHERE next_paid_month IS NULL
       OR next_paid_month != (payment_month + INTERVAL '1 month')::date
)

SELECT * FROM active_rows
UNION ALL
SELECT * FROM churn_rows
ORDER BY month, user_id, record_type;