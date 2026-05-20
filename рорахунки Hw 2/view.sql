CREATE OR REPLACE VIEW `your_project_id.marketing_data.v_spend_users` AS

WITH users_clean AS (
    SELECT
        registration_date,
        channel,
        geo,
        COUNT(*) AS users,
        COUNTIF(is_payer = 1) AS payers,
        SUM(CASE
                WHEN is_payer = 1
                    AND registration_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
                    THEN revenue_7d
                ELSE NULL
            END) AS total_revenue_7d,
        SUM(CASE
                WHEN is_payer = 1
                    AND registration_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
                    THEN revenue_90d
                ELSE NULL
            END) AS total_revenue_90d
    FROM `your_project_id.marketing_data.users`
    GROUP BY registration_date, channel, geo
)

SELECT
    s.date,
    s.channel,
    s.geo,
    s.spend,
    u.users,
    u.payers,
    u.total_revenue_7d,
    u.total_revenue_90d
FROM `your_project_id.marketing_data.spend` s
    LEFT JOIN users_clean u
ON s.date = u.registration_date
    AND s.channel = u.channel
    AND s.geo = u.geo;


CREATE OR REPLACE VIEW `your_project_id.marketing_data.v_users_device` AS

SELECT
    registration_date,
    channel,
    geo,
    device_os,
    is_payer,
    CASE
        WHEN registration_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
            THEN revenue_7d
        ELSE NULL
        END AS revenue_7d,
    CASE
        WHEN registration_date <= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
            THEN revenue_90d
        ELSE NULL
        END AS revenue_90d
FROM `your_project_id.marketing_data.users`;

