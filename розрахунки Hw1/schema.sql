CREATE TABLE marketing_ads_raw
(
    source        VARCHAR,
    campaign_id   VARCHAR,
    adset_id      VARCHAR,
    ad_id         VARCHAR,
    date          DATE,
    spend         NUMERIC(10, 4),
    impressions   INTEGER,
    clicks        INTEGER,
    installs      INTEGER,
    registrations INTEGER,
    timestamp     TIMESTAMPTZ
);
