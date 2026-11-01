-- National KPIs per month, with month on month change (LAG looks at the previous row)
-- name: national_monthly
WITH m AS (
  SELECT month,
         SUM(attendances)    AS attendances,
         SUM(within_4hrs)    AS within_4hrs,
         SUM(dta_over_12hrs) AS dta_over_12hrs
  FROM ae_monthly
  GROUP BY month
)
SELECT month,
       attendances,
       ROUND(100.0 * within_4hrs / attendances, 1) AS pct_4hrs,
       dta_over_12hrs,
       -- change worked out on the unrounded % and only then rounded
       ROUND(100.0 * within_4hrs / attendances
             - LAG(100.0 * within_4hrs / attendances) OVER (ORDER BY month), 1) AS pct_4hrs_mom_pts,
       attendances - LAG(attendances) OVER (ORDER BY month)       AS attendances_mom,
       dta_over_12hrs - LAG(dta_over_12hrs) OVER (ORDER BY month) AS dta_over_12hrs_mom
FROM m
ORDER BY month;

-- Worst 10 trusts (major A&E only) in the latest month against the 82% target
-- name: worst10_latest
SELECT org_name, region, attendances,
       ROUND(100.0 * within_4hrs / attendances, 1) AS pct_4hrs,
       dta_over_12hrs
FROM ae_monthly
WHERE has_type1_ae = 1
  AND month = (SELECT MAX(month) FROM ae_monthly)
ORDER BY pct_4hrs ASC
LIMIT 10;

-- RAG count of trusts in the latest month: Green 82%+, Amber 78% to 81.9%, Red under 78%
-- name: rag_latest
SELECT CASE WHEN 100.0 * within_4hrs / attendances >= 82 THEN 'Green'
            WHEN 100.0 * within_4hrs / attendances >= 78 THEN 'Amber'
            ELSE 'Red' END AS rag,
       COUNT(*) AS trusts
FROM ae_monthly
WHERE has_type1_ae = 1
  AND month = (SELECT MAX(month) FROM ae_monthly)
GROUP BY rag;

-- 4 hour performance by region in the latest month
-- name: region_latest
SELECT region,
       SUM(attendances) AS attendances,
       ROUND(100.0 * SUM(within_4hrs) / SUM(attendances), 1) AS pct_4hrs,
       SUM(dta_over_12hrs) AS dta_over_12hrs
FROM ae_monthly
WHERE month = (SELECT MAX(month) FROM ae_monthly)
GROUP BY region
ORDER BY pct_4hrs;

-- Same month one year earlier vs latest month (national)
-- name: year_on_year
WITH m AS (
  SELECT month, SUM(attendances) AS attendances, SUM(within_4hrs) AS within_4hrs,
         SUM(dta_over_12hrs) AS dta_over_12hrs
  FROM ae_monthly GROUP BY month
)
SELECT month, attendances, ROUND(100.0 * within_4hrs / attendances, 1) AS pct_4hrs, dta_over_12hrs
FROM m
WHERE month IN ((SELECT MAX(month) FROM ae_monthly),
                DATE((SELECT MAX(month) FROM ae_monthly), '-1 year'))
ORDER BY month;

-- Region: latest month vs previous month, change in points
-- name: region_mom
WITH r AS (
  SELECT region, month, 100.0 * SUM(within_4hrs) / SUM(attendances) AS pct,
         SUM(dta_over_12hrs) AS dta12
  FROM ae_monthly GROUP BY region, month
),
latest AS (SELECT MAX(month) AS m FROM ae_monthly)
SELECT cur.region,
       ROUND(cur.pct, 1)            AS pct_4hrs,
       ROUND(cur.pct - prev.pct, 1) AS mom_pts,
       cur.dta12                    AS dta_over_12hrs,
       cur.dta12 - prev.dta12       AS dta_over_12hrs_mom
FROM r cur
JOIN r prev ON prev.region = cur.region
           AND prev.month = DATE(cur.month, '-1 month')
WHERE cur.month = (SELECT m FROM latest)
ORDER BY mom_pts;

-- Major A&E trusts with the biggest fall in 4 hour % since last month
-- name: trust_biggest_falls
WITH t AS (
  SELECT org_code, org_name, region, month,
         100.0 * within_4hrs / attendances AS pct
  FROM ae_monthly WHERE has_type1_ae = 1
)
SELECT cur.org_name, cur.region,
       ROUND(prev.pct, 1) AS pct_prev, ROUND(cur.pct, 1) AS pct_now,
       ROUND(cur.pct - prev.pct, 1) AS change_pts
FROM t cur
JOIN t prev ON prev.org_code = cur.org_code
           AND prev.month = DATE(cur.month, '-1 month')
WHERE cur.month = (SELECT MAX(month) FROM ae_monthly)
ORDER BY change_pts
LIMIT 5;

-- Major A&E trusts with the most 12 hour waits in the latest month
-- name: trust_most_12hr_waits
SELECT org_name, region, dta_over_12hrs,
       ROUND(100.0 * within_4hrs / attendances, 1) AS pct_4hrs
FROM ae_monthly
WHERE has_type1_ae = 1
  AND month = (SELECT MAX(month) FROM ae_monthly)
ORDER BY dta_over_12hrs DESC
LIMIT 5;
