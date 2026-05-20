-- КРОК 1: Дедублікація
-- Залишаємо останній snapshot за кожен (ad_id, date)
-- Пріоритет: snapshot того ж дня → найновіший timestamp

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
)
SELECT *
FROM deduped
WHERE rn = 1;


-- Перевірка до: скільки snapshot-ів на (ad_id, date)? Очікуємо 6

SELECT ad_id, date, COUNT(*) AS cnt
FROM marketing_ads_raw
GROUP BY ad_id, date
ORDER BY cnt DESC
LIMIT 5;


-- Перевірка після: має бути рівно cnt = 1 скрізь ✓

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
)
SELECT ad_id, date, COUNT(*) AS cnt
FROM deduped
WHERE rn = 1
GROUP BY ad_id, date
ORDER BY cnt DESC
LIMIT 5;



-- КРОКИ 1-3: Дедублікація → Денні метрики → Підсумок по каналу

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
),

     last_per_day AS (
         SELECT * FROM deduped WHERE rn = 1
     ),

     daily_delta AS (
         SELECT source, ad_id, date,
                spend         - LAG(spend)         OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
                impressions   - LAG(impressions)   OVER (PARTITION BY ad_id ORDER BY date) AS daily_impressions,
                clicks        - LAG(clicks)        OVER (PARTITION BY ad_id ORDER BY date) AS daily_clicks,
                installs      - LAG(installs)      OVER (PARTITION BY ad_id ORDER BY date) AS daily_installs,
                registrations - LAG(registrations) OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
         FROM last_per_day
     ),

     daily_metrics AS (
         SELECT source, date,
                SUM(daily_spend)         AS daily_spend,
                SUM(daily_impressions)   AS daily_impressions,
                SUM(daily_clicks)        AS daily_clicks,
                SUM(daily_installs)      AS daily_installs,
                SUM(daily_registrations) AS daily_registrations
         FROM daily_delta
         WHERE daily_spend IS NOT NULL
         GROUP BY source, date
     ),

     channel_summary AS (
         -- метрики по каналу за весь період, NULLIF захищає від ділення на 0
         SELECT source,
                ROUND(SUM(daily_spend)::NUMERIC, 2)                                                        AS total_spend,
                ROUND((SUM(daily_spend) / NULLIF(SUM(daily_impressions), 0) * 1000)::NUMERIC, 2)           AS cpm,
                ROUND((SUM(daily_clicks)::NUMERIC / NULLIF(SUM(daily_impressions), 0) * 100)::NUMERIC, 2)  AS ctr_pct,
                ROUND((SUM(daily_installs)::NUMERIC / NULLIF(SUM(daily_clicks), 0) * 100)::NUMERIC, 2)     AS cr_click_install_pct,
                ROUND((SUM(daily_registrations)::NUMERIC / NULLIF(SUM(daily_installs), 0) * 100)::NUMERIC, 2) AS cr_install_reg_pct,
                ROUND((SUM(daily_spend) / NULLIF(SUM(daily_registrations), 0))::NUMERIC, 2)                AS cac,
                CASE source
                    WHEN 'tiktok' THEN 8.50
                    WHEN 'meta'   THEN 6.20
                    WHEN 'google' THEN 12.40
                    END AS ltv  -- LTV з воркшопу
         FROM daily_metrics
         GROUP BY source
     )

SELECT source, total_spend, cpm, ctr_pct,
       cr_click_install_pct, cr_install_reg_pct,
       cac, ltv,
       ROUND((ltv / NULLIF(cac, 0))::NUMERIC, 2) AS ltv_cac
FROM channel_summary
ORDER BY cac;


-- Перевірка: від'ємних значень після LAG() має бути 0 ✓

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
),
     last_per_day AS (SELECT * FROM deduped WHERE rn = 1),
     daily_delta AS (
         SELECT source, ad_id, date,
                spend         - LAG(spend)         OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
                registrations - LAG(registrations) OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
         FROM last_per_day
     )
SELECT COUNT(*) AS negative_rows
FROM daily_delta
WHERE daily_spend < 0 OR daily_registrations < 0;


-- БОНУС 5: CAC по місяцях

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
),

     last_per_day AS (
         SELECT * FROM deduped WHERE rn = 1
     ),

     daily_delta AS (
         SELECT source, ad_id, date,
                spend         - LAG(spend)         OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
                registrations - LAG(registrations) OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
         FROM last_per_day
     ),

     monthly_metrics AS (
         SELECT source,
                DATE_TRUNC('month', date) AS month,
                SUM(daily_spend)          AS monthly_spend,
                SUM(daily_registrations)  AS monthly_registrations
         FROM daily_delta
         WHERE daily_spend IS NOT NULL
         GROUP BY source, DATE_TRUNC('month', date)
     )

SELECT source,
       TO_CHAR(month, 'YYYY-MM')                                             AS month,
       ROUND(monthly_spend::NUMERIC, 2)                                      AS monthly_spend,
       monthly_registrations                                                  AS registrations,
       ROUND((monthly_spend / NULLIF(monthly_registrations, 0))::NUMERIC, 2) AS cac
FROM monthly_metrics
ORDER BY source, month;


-- Перевірка: має бути 7 місяців для кожного каналу ✓

WITH deduped AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY ad_id, date
               ORDER BY
                   CASE WHEN DATE(timestamp) = date THEN 0 ELSE 1 END ASC,
                   timestamp DESC
               ) AS rn
    FROM marketing_ads_raw
),
     last_per_day AS (SELECT * FROM deduped WHERE rn = 1),
     daily_delta AS (
         SELECT source, date,
                spend         - LAG(spend)         OVER (PARTITION BY ad_id ORDER BY date) AS daily_spend,
                registrations - LAG(registrations) OVER (PARTITION BY ad_id ORDER BY date) AS daily_registrations
         FROM last_per_day
     )
SELECT source, COUNT(DISTINCT DATE_TRUNC('month', date)) AS months_count
FROM daily_delta
WHERE daily_spend IS NOT NULL
GROUP BY source;