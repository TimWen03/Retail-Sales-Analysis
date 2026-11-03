-- Data Cleaning

-- creates a duplicate database to keep the original data set untouched
SELECT *
INTO sales_transactions_staging
FROM Sales_transactions_2022_2025;

SELECT *
FROM sales_transactions_staging;

-- 1. Removing duplicate records


-- Identify duplicates
SELECT
    Transaction_ID,
    COUNT(*) AS Duplicate_Count -- counts the number of times each transaction_ID appears
FROM dbo.sales_transactions_staging
GROUP BY Transaction_ID
HAVING COUNT(*) > 1 -- more than 1 is a duplicate
ORDER BY Duplicate_Count DESC;


-- View duplicates
WITH DuplicateCheck AS ( -- creates a CTE to easily organise query
    SELECT *,
        ROW_NUMBER() OVER ( --assigns a sequential number to each row within a group
            PARTITION BY Transaction_ID -- separates dataset into groups based on transaction_ID
            ORDER BY Transaction_ID
        ) AS RowNum 
    FROM dbo.sales_transactions_staging
)
SELECT * -- retrieves all columns from the CTE
FROM DuplicateCheck
WHERE RowNum > 1; -- where row num is more than 1. i.e duplicate records

-- Remove duplicates
WITH DuplicateCheck AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY Transaction_ID
            ORDER BY Transaction_ID
        ) AS RowNum
    FROM dbo.sales_transactions_staging
)
DELETE FROM DuplicateCheck -- same logic as above, instead of select, removes duplicate row
WHERE RowNum > 1;

-- Run identify duplicates again to verify results.

-- 2. Standardizing Data