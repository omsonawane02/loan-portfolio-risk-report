-- Loan Portfolio Risk & Performance Report: SQL queries
-- Database: loan_risk, table: loans (1,279,312 rows, Lending Club accepted loans issued 2012-2016)
-- "Resolved" = Fully Paid, Charged Off or Default (resolved_flag = 1)
-- "Mature" = 36-month loans issued 2012-2015, 60-month loans issued 2012-2013

USE loan_risk;

-- Indexes (speed up the grouped queries)
CREATE INDEX idx_grade ON loans(grade);
CREATE INDEX idx_status ON loans(loan_status);
CREATE INDEX idx_year ON loans(issue_year);
CREATE INDEX idx_resolved ON loans(resolved_flag);

-- 1. Overall KPIs (expected: 1,279,312 loans, default rate 19.90%)
SELECT
  COUNT(*) AS total_loans,
  ROUND(SUM(funded_amnt)/1000000, 1) AS amount_funded_millions,
  ROUND(AVG(int_rate), 2) AS avg_int_rate,
  ROUND(100 * AVG(CASE WHEN resolved_flag = 1 THEN default_flag END), 2) AS default_rate_resolved_pct
FROM loans;

-- 2. Status bucket counts (expected: 1,054,324 / 214,886 / 6,242 / 3,860)
SELECT status_bucket, COUNT(*) AS loans
FROM loans
GROUP BY status_bucket
ORDER BY loans DESC;

-- 3. Default rate by grade, resolved loans
SELECT grade,
       COUNT(*) AS resolved_loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
WHERE resolved_flag = 1
GROUP BY grade
ORDER BY grade;

-- 4. Mature 36-month vintages (expected: 13.58, 12.33, 13.73, 14.89)
SELECT issue_year,
       COUNT(*) AS resolved_loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY issue_year
ORDER BY issue_year;

-- 5. Pricing vs realised return by grade, ALL resolved loans
--    (distorted by young 60-month cohorts; kept to show why mature cohorts are used)
SELECT grade,
       COUNT(*) AS resolved_loans,
       ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_rec_prncp + total_rec_int + recoveries) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS return_via_total_pymnt_pct
FROM loans
WHERE resolved_flag = 1
GROUP BY grade
ORDER BY grade;

-- 6. Pricing vs realised return by grade, mature 36-month loans
SELECT grade,
       COUNT(*) AS resolved_loans,
       ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY grade
ORDER BY grade;

-- 7. Pricing vs realised return by grade, mature 60-month loans
SELECT grade,
       COUNT(*) AS resolved_loans,
       ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 60 AND issue_year BETWEEN 2012 AND 2013
GROUP BY grade
ORDER BY grade;

-- 8. Overall mature default rate and return, by term
SELECT term_months,
       COUNT(*) AS resolved_loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct
FROM loans
WHERE resolved_flag = 1
  AND ((term_months = 36 AND issue_year BETWEEN 2012 AND 2015)
    OR (term_months = 60 AND issue_year BETWEEN 2012 AND 2013))
GROUP BY term_months;

-- 9. Default rate by issue year and grade, mature 36-month (mix vs within-grade change)
SELECT issue_year, grade,
       COUNT(*) AS loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY issue_year, grade
ORDER BY issue_year, grade;

-- 10. Default rate by issue year and term, ALL resolved loans (includes young cohorts)
SELECT issue_year, term_months,
       COUNT(*) AS resolved_loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
WHERE resolved_flag = 1
GROUP BY issue_year, term_months
ORDER BY term_months, issue_year;

-- 11. Pricing and return by vintage, mature 36-month
SELECT issue_year,
       COUNT(*) AS resolved_loans,
       ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY issue_year
ORDER BY issue_year;

-- 12. Risk and return by loan purpose, mature 36-month
SELECT purpose,
       COUNT(*) AS loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct,
       ROUND(100 * (SUM(total_pymnt) - SUM(funded_amnt)) / SUM(funded_amnt), 2) AS realised_return_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY purpose
ORDER BY loans DESC;

-- 13. Default rate by state, mature 36-month, states with at least 5,000 loans
SELECT addr_state,
       COUNT(*) AS loans,
       ROUND(100 * AVG(default_flag), 2) AS default_rate_pct
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY addr_state
HAVING COUNT(*) >= 5000
ORDER BY default_rate_pct DESC;

-- 14. Where the dollars are lost, mature 36-month, by grade ($ millions)
--     principal lost = funded amount minus principal repaid, on defaulted loans, before recoveries
SELECT grade,
       ROUND(SUM(funded_amnt) / 1000000, 1) AS lent_millions,
       ROUND(SUM(total_rec_int) / 1000000, 1) AS interest_received_millions,
       ROUND(SUM(CASE WHEN default_flag = 1 THEN funded_amnt - total_rec_prncp ELSE 0 END) / 1000000, 1) AS principal_lost_millions,
       ROUND(SUM(recoveries) / 1000000, 1) AS recoveries_millions
FROM loans
WHERE resolved_flag = 1 AND term_months = 36 AND issue_year BETWEEN 2012 AND 2015
GROUP BY grade
ORDER BY grade;
