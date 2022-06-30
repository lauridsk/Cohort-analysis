-- Inspecting the data

SELECT * FROM retaildata

-- 541909 total records, we also notice some NULLS in the CustomerID column

SELECT * FROM retaildata 
WHERE CustomerID IS NULL

-- 135080 records have NULL in the CustomerID column. We will delete these.

DELETE FROM retaildata WHERE CustomerID IS NULL

/* 
Now we will check for duplicates by assigning duplicates with a value of >1 (If row_num is 2+ it means there is a duplicate).
Since the table has no UniqueID as Primary Key, a UniqueID is needed for this method to work properly. 
So a UniqueID column will be added to start with. 
*/

ALTER TABLE retaildata 
ADD UniqueID INT PRIMARY KEY AUTO_INCREMENT; 

-- Now we have added the UniqueID we can count how many duplicate rows there are (where row_num > 1)

SELECT UniqueID FROM (SELECT UniqueID, ROW_NUMBER() 
OVER (PARTITION BY InvoiceNo, StockCode, Quantity ORDER BY InvoiceDate) AS row_num
FROM retaildata) t1 WHERE row_num > 1;
						
-- There are 5281 duplicates
-- We can now delete the duplicate rows

DELETE FROM retaildata 
WHERE UniqueID IN 
(SELECT UniqueID FROM (SELECT UniqueID, 
ROW_NUMBER() OVER (PARTITION BY InvoiceNo, StockCode, Quantity ORDER BY InvoiceDate) 
AS row_num FROM retaildata) t1 WHERE row_num > 1);

-- Another thing we need to consider is to remove the negative quantities there seems to be when items have been returned.
-- If not dealth with, this will mess up any analysis using the quantity (and price for that matter) column (8841 instances of Quantity < 0)

SELECT * FROM retaildata WHERE Quantity < 0
DELETE FROM retaildata WHERE Quantity < 0

/* Begin Cohort Analysis

Data required for cohort analysis
-- Unique identifier (CustomerID)
-- Initial start date (first invoice date)
-- Revenue 

To get the initial start date using the MIN function, 
the format for InvoiceDate must be changed from the current dd/mm/yyyy format to yyyy-mm-dd
*/

SELECT CustomerID, DATE_FORMAT(STR_TO_DATE(InvoiceDate, '%d/%m/%Y'), '%Y-%m-%d') AS NewInvoiceDate
FROM retaildata 

UPDATE retaildata 
SET InvoiceDate = DATE_FORMAT(STR_TO_DATE(InvoiceDate, '%d/%m/%Y'), '%Y-%m-%d')

-- I'll create a temp table (named "Cohort") 
-- Including: CustomerID, the first time they purchased, and what year and month that was.
-- As I only need year and month, the day will be the 1st of each month indicated by "01"

CREATE TEMPORARY TABLE Cohort AS (
SELECT CustomerID, MIN(InvoiceDate) AS first_purchase_date,
DATE_FORMAT(STR_TO_DATE(MIN(InvoiceDate), '%Y-%m-%d'), '%Y-%m-01') AS Cohort_Date
FROM retaildata
GROUP BY CustomerID)

DROP TEMPORARY TABLE Cohort

SELECT * FROM Cohort

-- Create Cohort Index (an integer representation of the number of months passed since the first customer engagement)

CREATE TEMPORARY TABLE cohort_retention AS (
SELECT
mmm.*, 
(year_diff * 12 + month_diff + 1) AS cohort_index
FROM
(
	SELECT
		mm.*,
		(invoice_year - cohort_year) AS year_diff,
		(invoice_month - cohort_month) AS month_diff
	FROM(
		SELECT
		m.*,
		c.Cohort_Date,
		YEAR(m.InvoiceDate) invoice_year,
		MONTH(m.InvoiceDate) invoice_month,
		YEAR(c.Cohort_Date) cohort_year,
		MONTH(c.Cohort_Date) cohort_month
		FROM retaildata m
		LEFT JOIN Cohort c
		ON m.CustomerID = c.CustomerID
		) mm
) mmm		
)

-- 

SELECT * FROM cohort_retention

SELECT DISTINCT(cohort_index) FROM cohort_retention

/* Saved in a temp table. Cohort_index (int from 1-13) shows when a purchase was made since the first.
If cohort_index = 1 the purchase was made in the same month as first. 
If cohort_index = 2 the purchase was made in the second month after the first and so on
*/


-- When did a customer make a purchase after their first purchase?

SELECT DISTINCT 
CustomerID,
Cohort_Date,
Cohort_Index
FROM Cohort_Retention
ORDER BY 1, 3

