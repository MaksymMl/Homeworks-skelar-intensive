SELECT
    cohort,
    total_users,
    users_90d_gt_7d,
    ROUND(users_90d_gt_7d / total_users * 100, 2) AS pct_90d_gt_7d
FROM (
         SELECT
             registration_date AS cohort,
             COUNT(*) AS total_users,
             COUNTIF(revenue_90d >= revenue_7d) AS users_90d_gt_7d
         FROM `your_project_id.marketing_data.users`
         WHERE is_payer = 1
         GROUP BY registration_date
     )
ORDER BY cohort

SELECT
    registration_date AS cohort,
    ROUND(AVG(revenue_7d), 2) AS avg_revenue_7d,
    ROUND(AVG(revenue_90d), 2) AS avg_revenue_90d
FROM `your_project_id.marketing_data.users`
WHERE is_payer = 1
GROUP BY registration_date
ORDER BY registration_date