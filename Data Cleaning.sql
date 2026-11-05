-- Data Cleaning

-- creates a duplicate database to keep the original data set untouched
SELECT *
INTO sales_transactions_staging
FROM Sales_transactions_2022_2025;

SELECT *
FROM dbo.sales_transactions_staging;

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

-- 2. Standardising Data

SELECT *
FROM dbo.sales_transactions_staging

-- visualise the different data types 

SELECT
    ColumnName,
    Value,
    COUNT(*) AS Frequency
FROM dbo.sales_transactions_staging
CROSS APPLY ( -- CROSS APPLY allows evaluation of a table expression for each row
    VALUES -- cast as NVARCHAR to prevent conversion failure
        ('Customer_Gender', CAST(Customer_Gender AS NVARCHAR(255))),
        ('Customer_Segment', CAST(Customer_Segment AS NVARCHAR(255))),
        ('Sales_Channel', CAST(Sales_Channel AS NVARCHAR(255))),
        ('Country', CAST(Country AS NVARCHAR(255))),
        ('Region', CAST(Region AS NVARCHAR(255))),
        ('City', CAST(City AS NVARCHAR(255))),
        ('Product_Category', CAST(Product_Category AS NVARCHAR(255))),
        ('Product_Subcategory', CAST(Product_Subcategory AS NVARCHAR(255))),
        ('Payment_Method', CAST(Payment_Method AS NVARCHAR(255))),
        ('Order_Status', CAST(Order_Status AS NVARCHAR(255))),
        ('Shipping_Method', CAST(Shipping_Method AS NVARCHAR(255))),
        ('Return_Flag', CAST(Return_Flag AS NVARCHAR(255))),
        ('Return_Reason', CAST(Return_Reason AS NVARCHAR(255))),
        ('Promotion_Code', CAST(Promotion_Code AS NVARCHAR(255)))
) AS CategoryData(ColumnName, Value)
GROUP BY ColumnName, Value -- groups by column name
ORDER BY ColumnName, Frequency DESC;

-- from the query above, it's shown that "Non-binary" and "Non Binary appears as 2 separate values

SELECT
    Customer_Gender,
    COUNT(*) AS Frequency
FROM dbo.sales_transactions_staging
GROUP BY Customer_Gender
ORDER BY Frequency DESC;

SELECT DISTINCT 
    Customer_Gender
FROM dbo.sales_transactions_staging;

-- set non binary to non-binary to standardise data

UPDATE dbo.sales_transactions_staging
SET Customer_Gender = 'Non-binary'
WHERE LOWER(TRIM(Customer_Gender)) = 'non binary';

-- 3. Null or blank values

DECLARE @SQL NVARCHAR(MAX); --Delcare a variable to hold the value while the script executes

SELECT @SQL = STRING_AGG( -- combines multiple strings 
    CAST(
        'SELECT ' +
        '''' + REPLACE(Column_Name, '''', '''''') + ''' AS Column_Name, ' +
        'COUNT(*) AS Total_Rows, ' +
        'SUM(CASE WHEN ' + QUOTENAME(Column_Name) +
        ' IS NULL THEN 1 ELSE 0 END) AS Null_Count ' +
        'FROM dbo.sales_transactions_staging2'
        AS NVARCHAR(MAX)
    ),
    ' UNION ALL '
)
FROM dbo.sales_data_dictionary AS d 
INNER JOIN sys.columns AS c  
    ON c.name = d.Column_Name
    AND c.object_id = OBJECT_ID('dbo.sales_transactions_staging2');

EXEC sp_executesql @SQL;

-- The results how some columns do have NULL values e.g Return_Reason, Promotion_Code, however, important columns like transaction_ID have 0 Null values.
-- Given that Payment_Method contains Null values and a customer has to have paid for a product, rows containing Null values will be removed from the dataset.

DELETE
FROM dbo.sales_transactions_staging
WHERE Payment_Method IS NULL;

SELECT 
    Transaction_id,
    Payment_method 
FROM dbo.sales_transactions_staging
WHERE Payment_method  IS NULL;

SELECT *
INTO sales_transactions_staging2
FROM sales_transactions_staging;

SELECT *
FROM sales_transactions_staging2;

UPDATE 
    dbo.sales_transactions_staging2
SET
    Customer_Gender = UPPER(Customer_Gender);

UPDATE 
    dbo.sales_transactions_staging2
SET
    City = UPPER(City);

-- DATA IMPUTATION

-- As seen above, some values for Customer_Gender are NULL, however, we can use existing records, i.e other purchases made by the same Customer_ID and Customer_Name to fill in that data instead of deleting the entire row.

-- Find rows where gender is Null

SELECT
    Transaction_ID,
    Customer_ID,
    Customer_Name,
    Customer_Gender
FROM dbo.sales_transactions_staging2
WHERE Customer_Gender IS NULL;

-- Using self join, compare the table against itself, finding where a customer has Null gender and available gender

SELECT
    A.Transaction_ID,
    A.Customer_ID,
    A.Customer_Name,
    A.Customer_Gender AS Missing_Gender,
    B.Customer_Gender AS Matching_Gender
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Customer_ID = B.Customer_ID
WHERE A.Customer_Gender IS NULL
    AND B.Customer_Gender IS NOT NULL
ORDER BY Customer_ID;

-- Make sure to check for conflicting gender values as a customer may have updated their information

SELECT
    Customer_ID,
    COUNT(DISTINCT Customer_Gender) AS Gender_Count
FROM dbo.sales_transactions_staging2
WHERE Customer_Gender IS NOT NULL
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Customer_Gender) > 1;

-- none exist in this data set so updating the data can continue

UPDATE A
SET A.Customer_Gender = B.Customer_Gender
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Customer_ID = B.Customer_ID
WHERE A.Customer_Gender IS NULL
    AND B.Customer_Gender IS NOT NULL;

-- Verify results

SELECT
    Customer_Gender,
    COUNT(*) AS Total
FROM dbo.sales_transactions_staging2
GROUP BY Customer_Gender;

-- Some Null values still returns since not all customers have multiple transactions which we can use to compare values

SELECT *
FROM dbo.sales_transactions_staging2;

-- Repeat the process for Customer_Name using Customer_ID

SELECT
    A.Transaction_ID,
    A.Customer_ID,
    A.Customer_Name AS Missing_Name,
    B.Customer_Name AS Matching_Name
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Customer_ID = B.Customer_ID
WHERE A.Customer_Name IS NULL
    AND B.Customer_Name IS NOT NULL
ORDER BY Customer_ID;

SELECT
    Customer_ID,
    COUNT(DISTINCT Customer_Name) AS Name_Count
FROM dbo.sales_transactions_staging2
WHERE Customer_Name IS NOT NULL
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Customer_Name) > 1;

UPDATE A
SET A.Customer_Name = B.Customer_Name
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Customer_ID = B.Customer_ID
WHERE A.Customer_Name IS NULL
    AND B.Customer_Name IS NOT NULL;

SELECT *
FROM dbo.sales_transactions_staging2
WHERE Customer_Name IS NULL OR Customer_Name LIKE '';

--  Repeat the process for Product_Name using Product_ID

SELECT
    A.Transaction_ID,
    A.Product_ID,
    A.Product_Name AS Missing_Name,
    B.Product_Name AS Matching_Name
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Product_ID = B.Product_ID
WHERE A.Product_Name IS NULL
    AND B.Product_Name IS NOT NULL
ORDER BY Product_ID;

SELECT
    Product_ID,
    COUNT(DISTINCT Product_Name) AS Name_Count
FROM dbo.sales_transactions_staging2
WHERE Product_Name IS NOT NULL
GROUP BY Product_ID
HAVING COUNT(DISTINCT Product_Name) > 1;

UPDATE A
SET A.Product_Name = B.Product_Name
FROM dbo.sales_transactions_staging2 AS A
INNER JOIN dbo.sales_transactions_staging2 AS B
    ON A.Product_ID = B.Product_ID
WHERE A.Product_Name IS NULL
    AND B.Product_Name IS NOT NULL;

SELECT *
FROM dbo.sales_transactions_staging2
WHERE Product_Name IS NULL OR Product_Name LIKE '';

