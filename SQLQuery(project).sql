USE MortgageFinance;
GO

SELECT COUNT(*) FROM funded_loans;
SELECT COUNT(*) FROM cost_allocation;
SELECT COUNT(*) FROM lock_pipeline;
SELECT COUNT(*) FROM general_ledger;

SELECT *
FROM funded_loans
WHERE funded_amount IS NULL
   OR margin_bps IS NULL
   OR funded_month IS NULL;

ALTER TABLE funded_loans
ALTER COLUMN funded_amount BIGINT;


-- Total Production Volume
SELECT 
    SUM(funded_amount) AS Total_Volume
FROM funded_loans;

-- Monthly Volume
SELECT 
    FORMAT(funded_month, 'yyyy-MM') AS Month,
    SUM(funded_amount) AS Monthly_Volume
FROM funded_loans
GROUP BY FORMAT(funded_month, 'yyyy-MM')
ORDER BY Month;

-- Gross Revenue
SELECT 
    SUM(funded_amount * margin_bps / 10000.0) AS Gross_Revenue
FROM funded_loans;

-- Monthly Revenue by Channel
SELECT 
    FORMAT(funded_month, 'yyyy-MM') AS Month,
    channel,
    COUNT(*) AS Loan_Count,
    SUM(funded_amount) AS Total_Volume,
    ROUND(AVG(margin_bps),1) AS Avg_Margin,
    SUM(funded_amount * margin_bps / 10000.0) AS Revenue
FROM funded_loans
GROUP BY FORMAT(funded_month, 'yyyy-MM'), channel
ORDER BY Month;

-- Monthly Cost
SELECT 
    FORMAT(cost_month, 'yyyy-MM') AS Month,
    SUM(fixed_cost + variable_cost) AS Total_Cost
FROM cost_allocation
GROUP BY FORMAT(cost_month, 'yyyy-MM')
ORDER BY Month;

-- Monthly Net Profit
WITH Revenue AS (
    SELECT 
        FORMAT(funded_month, 'yyyy-MM') AS Month,
        SUM(funded_amount * margin_bps / 10000.0) AS Total_Revenue
    FROM funded_loans
    GROUP BY FORMAT(funded_month, 'yyyy-MM')
),
Cost AS (
    SELECT 
        FORMAT(cost_month, 'yyyy-MM') AS Month,
        SUM(fixed_cost + variable_cost) AS Total_Cost
    FROM cost_allocation
    GROUP BY FORMAT(cost_month, 'yyyy-MM')
)

SELECT 
    r.Month,
    r.Total_Revenue,
    c.Total_Cost,
    (r.Total_Revenue - c.Total_Cost) AS Net_Profit
FROM Revenue r
JOIN Cost c ON r.Month = c.Month
ORDER BY r.Month;

-- Monthly report View
CREATE VIEW vw_monthly_financials AS
WITH Revenue AS (
    SELECT 
        FORMAT(funded_month, 'yyyy-MM') AS Month,
        SUM(funded_amount) AS Total_Volume,
        SUM(funded_amount * margin_bps / 10000.0) AS Total_Revenue
    FROM funded_loans
    GROUP BY FORMAT(funded_month, 'yyyy-MM')
),
Cost AS (
    SELECT 
        FORMAT(cost_month, 'yyyy-MM') AS Month,
        SUM(fixed_cost + variable_cost) AS Total_Cost
    FROM cost_allocation
    GROUP BY FORMAT(cost_month, 'yyyy-MM')
)

SELECT 
    r.Month,
    r.Total_Volume,
    r.Total_Revenue,
    c.Total_Cost,
    (r.Total_Revenue - c.Total_Cost) AS Net_Profit
FROM Revenue r
JOIN Cost c ON r.Month = c.Month;

SELECT * FROM vw_monthly_financials;

-- Cost Per Loan
WITH Loan_Count AS (
    SELECT 
        FORMAT(funded_month, 'yyyy-MM') AS Month,
        COUNT(*) AS Total_Loans
    FROM funded_loans
    GROUP BY FORMAT(funded_month, 'yyyy-MM')
),
Cost AS (
    SELECT 
        FORMAT(cost_month, 'yyyy-MM') AS Month,
        SUM(fixed_cost + variable_cost) AS Total_Cost
    FROM cost_allocation
    GROUP BY FORMAT(cost_month, 'yyyy-MM')
)

SELECT 
    l.Month,
    l.Total_Loans,
    c.Total_Cost,
    (c.Total_Cost * 1.0 / l.Total_Loans) AS Cost_Per_Loan
FROM Loan_Count l
JOIN Cost c ON l.Month = c.Month
ORDER BY l.Month;

-- Revenue Per Loan
SELECT 
    FORMAT(funded_month, 'yyyy-MM') AS Month,
    COUNT(*) AS Loan_Count,
    SUM(funded_amount * margin_bps / 10000.0) AS Revenue,
    (SUM(funded_amount * margin_bps / 10000.0) * 1.0 / COUNT(*)) AS Revenue_Per_Loan
FROM funded_loans
GROUP BY FORMAT(funded_month, 'yyyy-MM')
ORDER BY Month;

-- Profit Per Loan
WITH Revenue AS (
    SELECT 
        FORMAT(funded_month, 'yyyy-MM') AS Month,
        COUNT(*) AS Loan_Count,
        SUM(funded_amount * margin_bps / 10000.0) AS Revenue
    FROM funded_loans
    GROUP BY FORMAT(funded_month, 'yyyy-MM')
),
Cost AS (
    SELECT 
        FORMAT(cost_month, 'yyyy-MM') AS Month,
        SUM(fixed_cost + variable_cost) AS Total_Cost
    FROM cost_allocation
    GROUP BY FORMAT(cost_month, 'yyyy-MM')
)

SELECT 
    r.Month,
    r.Loan_Count,
    (r.Revenue - c.Total_Cost) AS Net_Profit,
    ((r.Revenue - c.Total_Cost) / r.Loan_Count) AS Profit_Per_Loan
FROM Revenue r
JOIN Cost c ON r.Month = c.Month
ORDER BY r.Month;

-- Pull Through Rate
WITH Locked AS (
    SELECT 
        FORMAT(lock_month, 'yyyy-MM') AS Month,
        COUNT(*) AS Locked_Loans
    FROM lock_pipeline
    GROUP BY FORMAT(lock_month, 'yyyy-MM')
),
Funded AS (
    SELECT 
        FORMAT(funded_month, 'yyyy-MM') AS Month,
        COUNT(*) AS Funded_Loans
    FROM funded_loans
    GROUP BY FORMAT(funded_month, 'yyyy-MM')
)

SELECT 
    funded_month,
    COUNT(*) AS Loan_Count
FROM funded_loans
GROUP BY funded_month
ORDER BY funded_month;

UPDATE funded_loans
SET funded_month = DATEADD(
    MONTH,
    ABS(CHECKSUM(NEWID())) % 12,
    CAST('2024-01-01' AS DATE)
);

