# -*- coding: utf-8 -*-
"""
Created on Mon Sep 28 17:55:54 2026

@author: bohra
"""

import numpy as np
import pandas as pd
from sqlalchemy import create_engine
from urllib.parse import quote_plus

# Special character (!) ko safely encode karne ke liye
password = quote_plus("Ayush123!")

# Database Connection (Agar DB ka naam adventureworks_dw hai)
engine = create_engine(f'mysql+pymysql://root:{password}@127.0.0.1:3306/adventureworks_dw')

# Query
query = """
SELECT 
    f.SalesOrderLineKey,
    d.Fiscal_Year,
    d.Fiscal_Quarter,
    r.Business_Type,
    r.Reseller,
    t.Country,
    p.Category,
    p.Subcategory,
    p.Product,
    f.Order_Quantity,
    f.Unit_Price,
    f.Sales_Amount,
    f.Total_Product_Cost,
    (f.Sales_Amount - f.Total_Product_Cost) AS Gross_Profit,
    ROUND(((f.Sales_Amount - f.Total_Product_Cost) / f.Sales_Amount) * 100, 2) AS Margin_Pct
FROM fact_sales f
JOIN dim_sales_order so ON f.SalesOrderLineKey = so.SalesOrderLineKey
JOIN dim_date d ON f.OrderDateKey = d.DateKey
JOIN dim_reseller r ON f.ResellerKey = r.ResellerKey
JOIN dim_territory t ON f.SalesTerritoryKey = t.SalesTerritoryKey
JOIN dim_product p ON f.ProductKey = p.ProductKey
WHERE so.Channel = 'Reseller';
"""

print("Connecting to MySQL and loading DataFrame...")
df = pd.read_sql(query, engine)
print("Data loaded successfully!")
print(f"Shape: {df.shape}")
print(df.head(3))


import matplotlib.pyplot as plt
import seaborn as sns

# 1.Phase Distribution
total_orders=len(df)
loss_orders=len(df[df["Gross_Profit"]<0])
total_loss_amount=df.loc[df["Gross_Profit"]<0,"Gross_Profit"].sum()
print("Total Reseller Orders:", total_orders)
print(f"Loss Orders: {loss_orders} ({loss_orders / total_orders * 100:.2f}%)")
print("Total Loss Money: $", round(total_loss_amount, 2))

#Histogram
plt.hist(df["Margin_Pct"],bins=50)
plt.axvline(0,color="red")
plt.title("Margin Pct Distribution")
plt.xlabel("Margin %")
plt.ylabel("Count")
plt.show()


# FINDING: Margin is heavily skewed left with extreme outliers down to -350%,
# showing widespread pricing failure below break-even.
# ACTION: Immediate price floor governance required to stop selling below unit cost.

# 2. OUTLIER ANALYSIS (Category-wise)
df.boxplot(column='Gross_Profit',by="Category",grid=True)
plt.axhline(0,color='red',linestyle='--')
plt.suptitle("")
plt.xlabel("Category")
plt.ylabel("Gross Profit ($)")
plt.show()

#FINDING: Bikes single-handedly drive extreme multi-thousand-dollar losses 
#(down to -$15k per txn), while non-bike categories remain financially safe.
#ACTION: Implement mandatory minimum gross profit gates on Bikes 
#before order fulfillment.

# 3. PRODUCT-LEVEL LOSS CONCENTRATION
Product_Profit=(df.groupby("Product")["Gross_Profit"].sum().sort_values(ascending=True))
top_10_loss_products=Product_Profit.head(10)
top_10_loss_products.plot(kind='barh',color='crimson')
plt.title("Top 10 Loss-Making Products ($)")
plt.xlabel("Total Dollar Loss ($)")
plt.ylabel("Product")
plt.tight_layout()
plt.show()

#FINDING: Touring-1000 Yellow (size 60 & 46) and
#Road models drive concentrated catastrophic losses exceeding -$1.2M collectively.
#ACTION:Halt standard discounting on Touring-1000 series and 
#set non-negotiable price floors immediately.

# 4. PRICE VS COST RELATIONSHIP
unit_cost=df["Total_Product_Cost"]/df["Order_Quantity"]
plt.scatter(df["Unit_Price"],unit_cost,alpha=0.3,color='blue')
max_val=max(df['Unit_Price'].max(),unit_cost.max())
plt.plot([0,max_val],[0,max_val],color='red',linestyle='--',label='Cost Floor')
plt.title("Unit Selling Price vs Unit Product Cost")
plt.xlabel("Unit Selling Price ($)")
plt.ylabel("Unit Cost ($)")
plt.legend()
plt.show()
## Upper part of mid line is Cost>Price or vice versa

# FINDING: Clear inversion cluster where items priced at $800-$1,000 
# carry a unit cost of ~$1,500-$1,900 (Cost > Price).
# ACTION: Eliminate negative-spread sales orders by mandating a hard cost-floor
# block in the ERP system.

# 5. VOLUME VS MARGIN RELATIONSHIP
prod_vol_margin=df.groupby('Product').agg(Total_Volume=('Order_Quantity','sum'),Avg_Margin=('Margin_Pct','mean'))
plt.scatter(prod_vol_margin['Total_Volume'],prod_vol_margin['Avg_Margin'],color='purple',alpha=0.6)
plt.axhline(0,color='red',linestyle='--',label='Break even (0%)')
plt.title("Product Volume vs Average Margin %")
plt.xlabel("Total Order Volume (Units)")
plt.ylabel("Average Margin (%)")
plt.legend()
plt.show()

# FINDING: Massive volume outliers (6,000+ units) sit at negative margins (~ -15%),
# proving volume growth is diluting profitability.
# ACTION: Restructure tiered volume discounts to ensure minimum margin retention on bulk purchases.

# 6. RESELLER PROFITABILITY DISTRIBUTION
reseller_profit = df.groupby('Reseller')['Gross_Profit'].sum()

total_resellers = len(reseller_profit)
loss_resellers = len(reseller_profit[reseller_profit < 0])

print("Total Resellers:", total_resellers)
print(f"Loss-Making Resellers: {loss_resellers} ({loss_resellers / total_resellers * 100:.2f}%)")
plt.hist(reseller_profit, bins=40, color='darkorange')
plt.axvline(0, color='red', linestyle='--', label='Break-even ($0)')
plt.title("Reseller Account Profitability Distribution ($)")
plt.xlabel("Total Profit per Reseller ($)")
plt.ylabel("Number of Resellers")
plt.legend()
plt.show()

# FINDING: Over half of all reseller accounts (52.76%, 334 accounts) 
# generate net negative cumulative gross profit.
# ACTION: Audit partner contracts immediately and establish 
# account-level minimum margin covenants.

# 7. FY2020 DETERIORATION ANALYSIS
pd.options.display.float_format = "${:,.2f}".format

yearly_trend = (df.groupby('Fiscal_Year').agg(Revenue=("Sales_Amount","sum"),Gross_Profit=("Gross_Profit","sum")).reset_index())
print(yearly_trend)

plt.figure()
plt.plot(yearly_trend['Fiscal_Year'],yearly_trend["Revenue"],marker="o",label="Revenue ($)",color='blue')
plt.plot(yearly_trend["Fiscal_Year"],yearly_trend["Gross_Profit"],marker="o",label="Gross Profit ($)",color="red")
plt.axhline(0, color="black", linestyle="--")
plt.title("Yearly Revenue vs Gross Profit Trajectory")
plt.xlabel("Fiscal Year")
plt.ylabel("Amount ($)")
plt.legend()
plt.tight_layout()
plt.show()

# FINDING: Revenue scaled to record peak ($36.2M in FY2020) 
# while Gross Profit crashed below zero (-$673.7K), confirming aggressive
# top-line growth at the expense of bottom-line collapse.
# ACTION: Shift commercial incentives from pure volume/top-line targets
# to gross-profit-based commission models.






