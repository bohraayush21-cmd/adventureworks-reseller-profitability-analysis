CREATE DATABASE IF NOT EXISTS adventureworks_dw;
USE adventureworks_dw;
-- 1. Dimension: Sales Order
CREATE TABLE dim_sales_order (
    SalesOrderLineKey BIGINT PRIMARY KEY,
    Channel VARCHAR(50),
    Sales_Order VARCHAR(50),
    Sales_Order_Line VARCHAR(50)
);

-- 2. Dimension: Territory
CREATE TABLE dim_territory (
    SalesTerritoryKey INT PRIMARY KEY,
    Region VARCHAR(100),
    Country VARCHAR(100),
    `Group` VARCHAR(100)
);

-- 3. Dimension: Reseller
CREATE TABLE dim_reseller (
    ResellerKey INT PRIMARY KEY,
    Reseller_ID VARCHAR(50),
    Business_Type VARCHAR(100),
    Reseller VARCHAR(255),
    City VARCHAR(100),
    State_Province VARCHAR(100),
    Country_Region VARCHAR(100),
    Postal_Code VARCHAR(50)
);

-- 4. Dimension: Product
CREATE TABLE dim_product (
    ProductKey INT PRIMARY KEY,
    SKU VARCHAR(100),
    Product VARCHAR(255),
    Standard_Cost DECIMAL(12, 4),
    Color VARCHAR(50),
    List_Price DECIMAL(12, 4),
    Model VARCHAR(100),
    Subcategory VARCHAR(100),
    Category VARCHAR(100)
);

-- 5. Dimension: Customer
CREATE TABLE dim_customer (
    CustomerKey INT PRIMARY KEY,
    Customer_ID VARCHAR(50),
    Customer VARCHAR(255),
    City VARCHAR(100),
    State_Province VARCHAR(100),
    Country_Region VARCHAR(100),
    Postal_Code VARCHAR(50)
);

-- 6. Dimension: Date
CREATE TABLE dim_date (
    DateKey INT PRIMARY KEY,
    Date DATE,
    Fiscal_Year VARCHAR(20),
    Fiscal_Quarter VARCHAR(20),
    Month VARCHAR(50),
    Full_Date VARCHAR(50),
    MonthKey INT
);

-- 7. Fact Table: Sales Data
CREATE TABLE fact_sales (
    SalesOrderLineKey BIGINT,
    ResellerKey INT,
    CustomerKey INT,
    ProductKey INT,
    OrderDateKey INT,
    DueDateKey INT,
    ShipDateKey INT NULL,
    SalesTerritoryKey INT,
    Order_Quantity INT,
    Unit_Price DECIMAL(12, 4),
    Extended_Amount DECIMAL(12, 4),
    Product_Standard_Cost DECIMAL(12, 4),
    Total_Product_Cost DECIMAL(12, 4),
    Sales_Amount DECIMAL(12, 4),
    PRIMARY KEY (SalesOrderLineKey),
    FOREIGN KEY (ResellerKey) REFERENCES dim_reseller(ResellerKey),
    FOREIGN KEY (ProductKey) REFERENCES dim_product(ProductKey),
    FOREIGN KEY (SalesTerritoryKey) REFERENCES dim_territory(SalesTerritoryKey),
    FOREIGN KEY (OrderDateKey) REFERENCES dim_date(DateKey)
);
ALTER TABLE dim_date MODIFY COLUMN Date VARCHAR(50);
select* from dim_territory;
select* from dim_customer;
select* from dim_date;
SET SQL_SAFE_UPDATES = 0;
UPDATE dim_date 
SET Date = STR_TO_DATE(Date, '%d-%m-%Y')
WHERE Date IS NOT NULL;
ALTER TABLE dim_date MODIFY COLUMN Date DATE;
SET SQL_SAFE_UPDATES = 1;
select* from dim_product;
select* from dim_reseller;
USE adventureworks_dw;
TRUNCATE TABLE dim_sales_order;
SHOW VARIABLES LIKE 'secure_file_priv';
USE adventureworks_dw;

-- Purana partial data saaf karo
TRUNCATE TABLE dim_sales_order;

-- 1,21,254 rows ko direct bulk load karo
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dim_Sales_Order_Data.csv'
INTO TABLE dim_sales_order
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Channel, SalesOrderLineKey, Sales_Order, Sales_Order_Line);

-- Check row count
SELECT COUNT(*) FROM dim_sales_order;
select* from dim_sales_order;
USE adventureworks_dw;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/dim_Sales_data.csv'
INTO TABLE fact_sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(SalesOrderLineKey, ResellerKey, CustomerKey, ProductKey, OrderDateKey, DueDateKey, @v_ShipDateKey, SalesTerritoryKey, Order_Quantity, Unit_Price, Extended_Amount, Product_Standard_Cost, Total_Product_Cost, Sales_Amount)
SET ShipDateKey = NULLIF(@v_ShipDateKey, '');
Select count(*) from fact_sales;
select* from fact_sales;

###Profitability base line
## Where is the actual profit generated compared to the high revenue volume?
#Phase 1.1
select count(*) as Total_Transactions,
Round(sum(Sales_Amount),2) as Total_Revenue,
Round(sum(Total_Product_Cost),2) as Total_Product_Cost,
Round(sum(Sales_Amount-Total_Product_Cost),2) as Total_Gross_Profit,
Round(((sum(Sales_Amount)-sum(Total_Product_Cost))/sum(sales_amount))*100,2) as Overall_Gross_Profit_Margin_pct
from fact_sales;

#Phase 1.2 Rev vs profit contribution by channel
with ChannelTotals as(
select so.Channel,
Round(sum(f.Sales_Amount),2) as Channel_Revenue,
Round(sum(f.Sales_Amount-f.Total_Product_Cost),2) as Channel_Gross_Profit
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey=so.SalesOrderLineKey
group by so.Channel)
select Channel,Channel_Revenue,
Round((Channel_Revenue/sum(Channel_Revenue) Over())*100,2) as Revenue_Profit_Pct,
Channel_Gross_Profit,
ROUND((Channel_Gross_Profit / SUM(Channel_Gross_Profit) OVER ()) * 100, 2) AS Profit_Contribution_Pct
from ChannelTotals;
-- PHASE 1 INSIGHT: Total revenue is $109.81M with an 11.43% gross margin.
-- Reseller generates 73.26% of revenue but only 3.75% of profit (0.58% margin), while Internet delivers 96.25% of profit (41.15% margin).
-- High volume is masking a severe reseller margin collapse.

### Effective Selling Price Analysis
## How does the effective selling price to resellers compare against unit product cost?
# Phase 2 Effective Selling Price vs Product Cost Comparison by Channel
select 
so.Channel,
sum(f.Order_Quantity) as Total_Units_Sold,
Round(sum(f.Sales_Amount), 2) as Total_Revenue,
Round(sum(f.Total_Product_Cost), 2) as Total_Cost,
Round(sum(f.Sales_Amount) / sum(f.Order_Quantity), 2) as Avg_Effective_Price_Per_Unit,
Round(sum(f.Total_Product_Cost) / sum(f.Order_Quantity), 2) as Avg_Cost_Per_Unit,
Round((sum(f.Sales_Amount) / sum(f.Order_Quantity)) - (sum(f.Total_Product_Cost) / sum(f.Order_Quantity)), 2) as Unit_Profit_Gap,
Round(sum(f.Sales_Amount) / sum(f.Total_Product_Cost), 3) as Price_To_Cost_Ratio,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct
from fact_sales f
Join dim_sales_order so ON f.SalesOrderLineKey = so.SalesOrderLineKey
group by so.Channel;
-- PHASE 2 INSIGHT: Reseller unit economics are operating at near break-even (Price-to-Cost Ratio: 1.006).
-- Resellers yield an effective selling price of $375.27 against a cost of $373.08, leaving an alarming unit profit buffer of just $2.19 (0.58% margin).
-- In contrast, Internet maintains a 1.699 ratio with a $200.02 unit profit buffer (41.15% margin).

### Negative Margin Investigation
## Where precisely is the enterprise incurring negative-margin sales?
# Phase 3
select so.Channel,
count(f.SalesOrderLineKey) as Total_transactions,
sum(case when f.Sales_Amount<f.Total_Product_Cost then 1 else 0 end) as Loss_Transaction_Count,
Round(sum(case when f.Sales_Amount<f.Total_Product_Cost then 1 else 0 end)/count(f.SalesOrderLineKey)*100,2) as 
Pct_loss_Transactions,
count(distinct case when f.Sales_Amount < f.Total_Product_Cost then f.ProductKey end) as Distinct_Loss_Products,
Round(sum(case when f.Sales_Amount < f.Total_Product_Cost then f.Sales_Amount else 0 end),2) as Revenue_At_Loss,
Round((sum(case when f.Sales_Amount < f.Total_Product_Cost then f.Sales_Amount else 0 end)/Sum(f.Sales_Amount))*100,2)
as Pct_Revenue_At_Loss,
Round(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount-f.Total_Product_Cost) else 0 end),2) as
Total_Loss_Generated
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey=so.SalesOrderLineKey
group by so.Channel;
-- PHASE 3 INSIGHT: 100% of enterprise losses are isolated to the Reseller channel.
-- 35.87% of reseller transactions (21,829 orders across 129 products) executed below cost, generating $40.13M in loss-making revenue (49.89% of reseller sales).
-- This generated an aggregate gross loss of -$3.32M, directly eroding reseller profit down to a negligible $470K (0.58% margin).

### Product Mix Analysis
## Is the profitability deficit isolated to particular product lines?
# Phase 4.1 Category-Wise Breakdown (Reseller Channel)
SELECT 
p.Category,
count(f.SalesOrderLineKey) as Transaction_Count,
sum(f.Order_Quantity) as Total_Units_Sold,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Total_Product_Cost), 2) as Total_Cost,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct,
Round(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount - f.Total_Product_Cost) else 0 end), 2) as Total_Loss_Generated
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller'
group by p.Category
order by Gross_Profit asc;

-- Phase 4.2 Subcategory-Level Profitability (Reseller Only)
select 
p.Category,
p.Subcategory,
sum(f.Order_Quantity) as Total_Units_Sold,
Round(sum(f.Sales_Amount), 2) AS Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct,
Round(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount - f.Total_Product_Cost) else 0 end), 2) as Total_Loss_Generated
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller'
group by p.Category, p.Subcategory
order by Gross_Profit asc;

# Phase 4.3
select p.Product,p.Category,p.Subcategory,
sum(f.Order_Quantity) as Total_Units_Sold,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Total_Product_Cost), 2) as Cost,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct
From fact_sales f
Join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
Join dim_product p on f.ProductKey = p.ProductKey
Where so.Channel = 'Reseller'
group by p.Product, p.Category, p.Subcategory
order by Gross_Profit asc
limit 15;
-- PHASE 4 INSIGHT: 95.1% of all reseller losses are concentrated in the Bikes category (-$3.16M loss, -1.49% margin).
-- Specifically, Touring Bikes (-$1.24M loss, -11.84% margin) and Road Bikes (-$1.21M loss, -3.99% margin) are the core loss drivers.
-- Non-bike categories remain profitable (Accessories: 34.27%, Clothing: 13.07%, Components: 8.75%).
-- PHASE 4 PRODUCT-LEVEL INSIGHT: All top 15 loss-making SKUs belong strictly to Touring Bikes and Road Bikes.
-- Touring-1000 series suffers severe negative margins (-19% to -22%), with just two SKUs destroying over $477K in gross profit.
-- Road-350-W and Road-650 models also generate heavy volume at negative 7% to 14% margins.

### Does a small group of products account for the vast majority of the company's losses?
## Pareto & Cumulative Loss Contribution
# Phase 5
-- Simple Pareto: Top Loss-Making Products & Cumulative Loss %
with ProductLoss as (
select 
p.Product,
p.Subcategory,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Total_Profit_Loss
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_product p on f.ProductKey = p.ProductKey
Where so.Channel = 'Reseller'
group by p.Product, p.Subcategory
having Total_Profit_Loss < 0)
select
Product,
Subcategory,
Total_Profit_Loss,
Round((Total_Profit_Loss / sum(Total_Profit_Loss) over ()) * 100, 2) as Pct_Of_Loss,
Round((sum(Total_Profit_Loss) over (order by Total_Profit_Loss) / sum(Total_Profit_Loss) over ()) * 100, 2) as Cumulative_Loss_Pct
from ProductLoss
order by Total_Profit_Loss asc
limit 15;
-- PHASE 5 PARETO INSIGHT: Reseller margin deficit exhibits extreme product-level concentration.
-- Touring-1000 Yellow (sizes 60 & 46) alone account for 17.65% (-$477K) of total loss pool.
-- Just 15 SKUs (exclusively Touring and Road Bikes) generate 54.06% of cumulative reseller losses.

### Reseller segment analysis
## Which reseller business types are the primary drivers of negative-margin sales?
# Phase 6.1 Profitability & Negative-Margin Share by Business Type
select
r.Business_Type,
count(distinct r.ResellerKey) as Total_Resellers,
count(f.SalesOrderLineKey) as Total_Orders,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Total_Product_Cost), 2) as Total_Cost,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct,
sum(case when f.Sales_Amount < f.Total_Product_Cost then 1 else 0 end) as Loss_Transactions_Count,
Round((sum(case when f.Sales_Amount < f.Total_Product_Cost then 1 else 0 end) / count(f.SalesOrderLineKey)) * 100, 2
    ) as Pct_Loss_Transactions,
Round(abs(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount - f.Total_Product_Cost) else 0 end)), 2) as Total_Loss_Generated
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_reseller r on f.ResellerKey = r.ResellerKey
where so.Channel = 'Reseller'
group by r.Business_Type
order by Gross_Profit asc;

#Phase 6.2 Product Category Mix within Each Business Type
SELECT 
r.Business_Type,
p.Category,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) AS Gross_Margin_Pct
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_reseller r on f.ResellerKey = r.ResellerKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller'
group by r.Business_Type, p.Category
order by r.Business_Type, Gross_Profit asc;

-- PHASE 6 INSIGHT: Warehouse resellers are the primary driver of value destruction, generating -$4.78K profit (-0.01% margin) and absorbing $1.92M (57.8%) of total loss.
-- Bikes run negative gross margins across ALL 3 business types: Warehouse (-2.98%), Specialty Bike Shop (-1.42%), and VAR (-0.10%).
-- Non-bike categories remain consistently healthy (10% to 36% margins) across every segment.

### Individual Reseller Concentration
## Are enterprise losses isolated to a specific cohort of wholesale partner accounts?
# Phase 7.1
SELECT 
r.Reseller,
r.Business_Type,
count(f.SalesOrderLineKey) as Total_Orders,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Total_Product_Cost), 2) as Cost,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct,
Round(abs(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount - f.Total_Product_Cost) else 0 end)), 2) as Total_Loss_Generated
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_reseller r on f.ResellerKey = r.ResellerKey
where so.Channel = 'Reseller'
group by r.Reseller, r.Business_Type
order by Gross_Profit asc
limit 15;

# Phase 7.2 Reseller Loss Concentration (Pareto on Net Deficit)
with ResellerLoss as (
select 
r.Reseller,
r.Business_Type,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) AS Net_Profit_Loss
From fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_reseller r on f.ResellerKey = r.ResellerKey
where so.Channel = 'Reseller'
group by  r.Reseller, r.Business_Type
having Net_Profit_Loss < 0)
select
Reseller,
Business_Type,
Net_Profit_Loss,
Round((Net_Profit_Loss / sum(Net_Profit_Loss) over ()) * 100, 2) as Pct_Of_Reseller_Loss,
Round((sum(Net_Profit_Loss) over (order by Net_Profit_Loss)/ sum(Net_Profit_Loss) over ()) * 100, 2) as Cumulative_Loss_Pct
from ResellerLoss
order by Net_Profit_Loss asc
limit 15;

-- PHASE 7 INSIGHT: Profitability risk is NOT concentrated in a few resellers (Top 15 accounts drive only 25.48% of total losses).
-- 14 out of the top 15 loss-making accounts are Warehouses, running negative margins between -3.60% and -15.73%.
-- The margin collapse is systemic across the Warehouse business model rather than partner-specific misconduct.

### Geographic Root Cause
## is margin erosion driven by regional geographic factors?
# Phase 8.1 Country & Region Profitability Breakdown
select t.Country,t.Region,
count(f.SalesOrderLineKey) as Total_Orders,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Total_Product_Cost), 2) as Total_Cost,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Gross_Margin_Pct,
Round(abs(sum(case when f.Sales_Amount < f.Total_Product_Cost then (f.Sales_Amount - f.Total_Product_Cost) else 0 end)), 2) as Total_Loss_Generated,
Round((sum(case when f.Sales_Amount < f.Total_Product_Cost then 1 else 0 end) / count(f.SalesOrderLineKey)) * 100,2) as Pct_Loss_Transactions
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_territory t on f.SalesTerritoryKey = t.SalesTerritoryKey
where so.Channel = 'Reseller'
group by t.Country, t.Region
order by Gross_Profit asc;

#Phase 8.2 Cross-Analysis: Region × Bikes Category
select t.Country,t.Region,p.Category,
Round(sum(f.Sales_Amount), 2) as Bike_Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Bike_Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Bike_Margin_Pct
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_territory t on f.SalesTerritoryKey = t.SalesTerritoryKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller' and p.Category = 'Bikes'
group by t.Country, t.Region, p.Category
order by Bike_Gross_Profit asc;

-- PHASE 8 INSIGHT: Profitability collapse is NOT isolated to any single geography.
-- Loss transactions are systemic across all 10 territories (ranging from 30% to 52.6% of orders).
-- Germany (-5.61%), Australia (-6.82%), France (-0.81%), and US Southwest (-0.08%) operate at net negative margins overall.
-- Bikes run negative gross margins across 9 out of 10 global regions, proving a global pricing flaw rather than local operational or tax issues.

### Volume vs Margin Analysis
## How does the volume-margin trade-off correlate with the Reseller channel's gross profit erosion?
# Phase 9.1
select p.Product,p.Subcategory,
sum(f.Order_Quantity) as Units_Sold,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Margin_Pct
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller'
group by p.Product, p.Subcategory
order by Units_Sold desc
limit 15;

# Phase 9.2
select 
p.Product,p.Subcategory,
sum(f.Order_Quantity) as Units_Sold,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Margin_Pct
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller'
group by  p.Product, p.Subcategory
order by Revenue desc
limit 15;

-- PHASE 9 INSIGHT: Severe divergence between Top Volume vs Top Revenue profitability.
-- Top Volume is dominated by high-margin Accessories/Clothing (Helmets, Vests, Shorts at 24% to 35% margin), though subsidized by negative-margin Jerseys (-13% to -34%) and Caps (-18%).
-- Top Revenue is dominated by Bikes, where Mountain Bikes generate thin profits (9% margin), but high-ticket Road and Touring Bikes destroy profit (-3.5% to -21.8% margin) on millions in revenue.

### Time-Series Investigation
## Was the profitability collapse a sudden shock or a progressive structural deterioration?
# Phase 10.1: Reseller Margin Trend by Year & Quarter
select d.Fiscal_Year,d.Fiscal_Quarter,
count(f.SalesOrderLineKey) as Total_Orders,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Margin_Pct,
Round((sum(case when f.Sales_Amount < f.Total_Product_Cost then 1 else 0 end) /count(f.SalesOrderLineKey)) * 100,2) as Pct_Loss_Transactions
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_date d on f.OrderDateKey = d.DateKey
where so.Channel = 'Reseller'
group by d.Fiscal_Year, d.Fiscal_Quarter
order by d.Fiscal_Year asc, d.Fiscal_Quarter asc;

#Phase 10.2
select d.Fiscal_Year,p.Category,
Round(sum(f.Sales_Amount), 2) as Revenue,
Round(sum(f.Sales_Amount - f.Total_Product_Cost), 2) as Gross_Profit,
Round(((sum(f.Sales_Amount) - sum(f.Total_Product_Cost)) / sum(f.Sales_Amount)) * 100, 2) as Margin_Pct
from fact_sales f
join dim_sales_order so on f.SalesOrderLineKey = so.SalesOrderLineKey
join dim_date d on f.OrderDateKey = d.DateKey
join dim_product p on f.ProductKey = p.ProductKey
where so.Channel = 'Reseller' and p.Category in ('Bikes', 'Accessories')
group by d.Fiscal_Year, p.Category
order by d.Fiscal_Year asc, p.Category asc;

-- PHASE 10 INSIGHT: The reseller margin collapse is a deteriorating structural trend, not an isolated blip.
-- FY2018 operated stably at ~3.7%-4.2% margin until a sharp Q4 deficit (-11.79%), followed by a brief FY2019 stabilization (~3.7%-4.6%).
-- The catastrophic breakdown happened in FY2020: Bikes margin plummeted to -4.27% (-$1.23M deficit) alongside peak revenue ($28.87M), pushing overall FY2020 Q1 margins down to -6.50%.






