### 1. Database Extraction & Modeling (MySQL)
* Executed relational joins across sales, territory, reseller, and product dimension tables.
* Wrote SQL queries utilizing **CTEs, Window Functions, and Aggregations** to compute gross revenue, total standard cost, net profit, and profit margin percentages across channels.
* Segmented financial performance by reseller business type (Warehouse, Specialty Bike Shop, Value-Added Reseller) and geographic territories.

### 2. Exploratory Data Analysis & Outlier Detection (Python)
* Connected directly to MySQL database instances using **SQLAlchemy** engine configurations and **PyMySQL**.
* Cleaned and preprocessed transaction records using **Pandas** and **NumPy** to detect negative-margin outliers and anomalous discounting patterns.
* Visualized SKU-level unit margin distributions and price-versus-cost floor dynamics using **Matplotlib** and **Seaborn**.
* Isolated specific loss-making product subcategories (Classic Jerseys, Touring-1000 models) where discounting exceeded standard production costs.

### 3. Executive Dashboard Architecture (Power BI)
Built a 5-page, containerized reporting suite with standardized corporate theming (`#0F2537` / `#F4F5F7`):

* **Page 1: Executive Overview | Sales & Profitability Analysis**
  * High-level KPI monitoring ($110M Revenue, $13M Profit, 10.85% Margin Gap) and channel volume vs. profit contribution[cite: 7].
* **Page 2: Profitability Drivers | Regional & Channel Leakage Analysis**
  * Isolates negative cash corridors in Australia (-6.82%) and Germany (-5.61%) diluting US/Canada gains[cite: 8].
* **Page 3: Product & SKU Margin Audit | Subcategory Deficit Breakdown**
  * Granular SKU audit exposing Classic Jerseys (-34.16%) and Touring Bikes (-$1.24M deficit).
* **Page 4: Historical Margin Trajectory | Growth vs. Margin Erosion Over Time**
  * Evaluates 2017–2020 trends showing revenue peaking at $43M while reseller profit flatlined at $0M[cite: 10].
* **Page 5: Root Cause Diagnostic | Partner Business Model & Regional Margin Audit**
  * Cross-dimensional matrix evaluating partner tier, territory, and cost floor vulnerabilities.

---

## 💡 Strategic Recommendations

1. **Enforce Wholesale Price Floors:** Implement non-negotiable minimum price thresholds for Touring and Road bike lines prior to contract renewals[cite: 10].
2. **Freeze Apparel Discounting:** Immediately halt volume-based discount tiers on negative-margin apparel SKUs (Classic Jerseys)[cite: 10].
3. **Restructure International Partner Agreements:** Transition German and Australian warehouse partner agreements from aggressive fixed discounts to margin-sharing or fee-for-service models[cite: 6].
4. **Capital Reallocation:** Shift marketing spend and inventory priority toward the high-margin Internet channel (41% margin) and high-margin Accessories category (~50% margin)[cite: 6, 8].

---

## 💻 Tech Stack & Tools

* **Database / Querying:** MySQL (CTEs, Joins, Window Functions, Aggregations)
* **Data Science / Python:** Python, Pandas, NumPy, SQLAlchemy, PyMySQL, Matplotlib, Seaborn
* **Business Intelligence:** Microsoft Power BI (Star Schema Modeling, DAX Measures, UX/UI Container Design)
