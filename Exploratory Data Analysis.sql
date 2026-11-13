-- Exploratory Data Analysis

-- USE RetailSalesData;

SELECT *
FROM dbo.sales_transactions_staging2;

-- Dataset overview and profiling 

-- First, inspect the structure and overall dataset before investigating business questions

SELECT
    COUNT(*) AS Total_Transactions,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers,
    COUNT(DISTINCT Product_ID) AS Unique_Products,
    COUNT(DISTINCT Store_ID) AS Unique_Stores,
    MIN(Order_Date) AS First_Order,
    MAX(Order_Date) AS Last_Order,
    SUM(Sales_Amount) AS Total_Revenue,
    SUM(Profit) AS Total_Profit
FROM dbo.sales_transactions_staging2;

-- Sales performance analysis

-- Monthly revenue, how much did the business generate, which months have the highest / lowest sales, trends over time etc

SELECT
    YEAR(Order_Date) AS Sales_Year,
    MONTH(Order_Date) AS Sales_Month,
    COUNT(*) AS Total_Transactions,
    SUM(Sales_Amount) AS Total_Revenue,
    AVG(Sales_Amount) AS Average_Order_Value
FROM dbo.sales_transactions_staging2
GROUP BY
    YEAR(Order_Date),
    MONTH(Order_Date)
ORDER BY
    Sales_Year,
    Sales_Month;

-- Sales per city, which countries and regions generate the most sales, may be able to assist in advertising and focusing resources in those specific areas or expand to near by regions.

SELECT
    Country,
    City,
    COUNT(*) AS Total_Transactions,
    SUM(Sales_Amount) AS Total_Revenue,
    AVG(Sales_Amount) AS Average_Order_Value
FROM dbo.sales_transactions_staging2
GROUP BY 
    Country,
    City
ORDER BY
    Country,
    City;

-- Customer analysis

-- Revenue by customer segment, which market makes the most revenue, how many customer are in that segment, how many transactions and whats the average transactions value

SELECT
    Customer_Segment,
    COUNT(DISTINCT Customer_ID) AS Unique_Customers,
    COUNT(*) AS Total_Transactions,
    SUM(Sales_Amount) AS Total_Revenue,
    AVG(Sales_Amount) AS Average_Transaction_Value
FROM dbo.sales_transactions_staging2
GROUP BY Customer_Segment
ORDER BY Total_Revenue DESC;

-- Revenue by customers, which customer brings in the most revenue, what is their average transaction value, this shows the company whom it may want to enhance customer relationships with.

SELECT
    Customer_ID,
    Customer_Name,
    COUNT(*) AS Total_Transactions,
    SUM(Sales_Amount) AS Total_Revenue,
    AVG(Sales_Amount) AS Average_Transaction_Value
FROM dbo.sales_transactions_staging2
GROUP BY 
    Customer_ID,
    Customer_Name
ORDER BY Total_Revenue DESC;

-- Total revenue, average revenue and total transactions by customer age_group and sales_channel
-- May allow the business to see who their main demographic is, which channels they used and where improvements need to be made

WITH AgeChannelAnalysis AS ( 
-- CREATE CTE to organise intermediate results before perform analysis. CTE imrpvoes query readability by seperating data aggregation from final ranking. 
-- A CTE (COMMON TABLE EXPRESSION) is essentially a temporary named result set that exists for the duration of the statement immediately following it
    SELECT
        CASE -- catergorising into age groups instead of using individual age 
            WHEN Customer_Age BETWEEN 18 AND 24 THEN '18-24'
            WHEN Customer_Age BETWEEN 25 AND 34 THEN '25-34'
            WHEN Customer_Age BETWEEN 35 AND 44 THEN '35-44'
            WHEN Customer_Age BETWEEN 45 AND 54 THEN '45-54'
            WHEN Customer_Age BETWEEN 55 AND 64 THEN '55-64'
            WHEN Customer_Age >= 65 THEN '65+'
        END AS Age_Group,

        COALESCE(Sales_Channel, 'Unknown') AS Sales_Channel, --Returns the first non-null value if the sales channel is missing

        COUNT(DISTINCT Transaction_ID) AS Total_Transactions,
        COUNT(DISTINCT Customer_ID) AS Unique_Customers,
        SUM(Quantity) AS Total_Units_Purchased,
        SUM(Sales_Amount) AS Total_Revenue,
        AVG(Sales_Amount) AS Average_Transaction_Value

    FROM dbo.sales_transactions_staging2

    WHERE Customer_Age >= 18 -- Filter the data so that minors are not included

    GROUP BY 
        CASE
            WHEN Customer_Age BETWEEN 18 AND 24 THEN '18-24'
            WHEN Customer_Age BETWEEN 25 AND 34 THEN '25-34'
            WHEN Customer_Age BETWEEN 35 AND 44 THEN '35-44'
            WHEN Customer_Age BETWEEN 45 AND 54 THEN '45-54'
            WHEN Customer_Age BETWEEN 55 AND 64 THEN '55-64'
            WHEN Customer_Age >= 65 THEN '65+'
        END,
        COALESCE(Sales_Channel, 'Unknown')
) -- END OF CTE

SELECT 
    Age_Group,
    Sales_Channel,
    Total_Transactions,
    Unique_Customers,
    Total_Units_Purchased,
    Total_Revenue,
    Average_Transaction_Value,

    RANK() OVER ( -- creates a ranking based on total transactions
        ORDER BY Total_Revenue DESC
    ) AS Channel_Rank

FROM AgeChannelAnalysis

ORDER BY Channel_Rank;