# Revenue Metrics Dashboard: SaaS Subscription Analytics

End-to-end analytics solution for a subscription business: a PostgreSQL query that transforms raw transactions into monthly user-level snapshots, plus an interactive Tableau dashboard with 13 key SaaS metrics.

**Live Dashboard**: [Tableau Public](https://public.tableau.com/views/RevenueMetricsDashboard_17797228680350/RevenueMetricsDashboard)

---

## Project Overview

The goal of this project is to provide a subscription business with a complete analytical view of revenue dynamics, customer behavior, and growth factors. The output is a single dashboard that answers the most important business questions in one screen:

- How is revenue growing month over month?
- Are we acquiring new paying customers efficiently?
- How many customers churn, and how much revenue do we lose with them?
- Are existing customers expanding or contracting their spend?
- Are churned customers returning?

The analysis covers the period **March – December 2022** with **383 unique paying customers** and **1,927 transactions**.

---

## Tech Stack

- **PostgreSQL** — data transformation
- **SQL** — CTEs, window functions, conditional aggregation
- **Tableau Public** — visualization and interactivity

---

## SaaS Metrics Covered

The solution computes 13 industry-standard subscription business metrics:

| # | Metric | Description |
|---|--------|-------------|
| 1 | **MRR** | Monthly Recurring Revenue |
| 2 | **Paid Users** | Unique paying customers per month |
| 3 | **ARPPU** | Average Revenue Per Paying User |
| 4 | **New Paid Users** | First-time payers in a month |
| 5 | **New MRR** | Revenue from new customers |
| 6 | **Churned Users** | Customers who stopped paying |
| 7 | **Churn Rate** | Churned / Previous Paid Users |
| 8 | **Churned Revenue** | Revenue lost due to churn |
| 9 | **Revenue Churn Rate** | Churned Revenue / Previous MRR |
| 10 | **Expansion MRR** | Increase in revenue from existing customers |
| 11 | **Contraction MRR** | Decrease in revenue from existing customers |
| 12 | **LT** | Customer Lifetime (1 / Churn Rate) |
| 13 | **LTV** | Lifetime Value (ARPPU × LT) |

---

## SQL Architecture

The query is organized as **4 sequential CTEs**, each performing a clear transformation step.

### CTE 1: `monthly_payments`
Aggregates raw transactions into monthly grain per user. Uses `DATE_TRUNC` to round dates to the start of the month and `SUM` to combine multiple payments. A `LEFT JOIN` enriches each row with user attributes (language, age, device).

### CTE 2: `user_analysis`
Adds context to each row using window functions partitioned by `user_id`:
- `LEAD(payment_month)` — next month the user paid
- `LAG(payment_month)` — previous payment month
- `LAG(revenue)` — previous payment amount (for expansion/contraction logic)
- `MIN(payment_month) OVER` — user's very first payment

### CTE 3: `active_rows`
Generates one row per active payment month with classification flags:
- `is_new_paid_user` — first-ever payment of the user
- `is_back_from_churn` — user paid before, but skipped at least one month
- `expansion_mrr` — payment increased compared to previous month
- `contraction_mrr` — payment decreased compared to previous month
- `record_type = 'active'` — used in Tableau to count active users correctly

### CTE 4: `churn_rows`
Generates synthetic rows for churn events. If a user paid in March and didn't return in April, an "April churn row" is created with the user's last payment as `churned_revenue`. The condition uses `LEAD` from CTE 2 to detect missing follow-up payments.

### Final SELECT
`UNION ALL` combines active and churn rows into a single flat table, ready for Tableau.

---

## Why This Design?

All complex business logic lives in SQL, so Tableau can use the simplest possible aggregations:

```
MRR              = SUM(revenue)
Paid Users       = COUNTD(IIF(record_type='active', user_id, NULL))
Churned Users    = SUM(is_churned_user)
New MRR          = SUM(new_mrr)
Expansion MRR    = SUM(expansion_mrr)
Contraction MRR  = SUM(contraction_mrr)
ARPPU            = MRR / Paid Users
LTV              = Total Revenue / Total Paid Users
```

No Tableau-side LOOKUP, FIXED, or complex table calculations are needed. Every metric works correctly under any combination of date / language / age filters.

---

## Dashboard Highlights

The Tableau dashboard contains:

- **5 KPI cards**: Total Revenue, Paid Users, LTV, Churned Revenue, New MRR
- **6 visualizations**:
  - MRR & Paid Users (combo: bars + line)
  - New MRR & Paid Users (combo)
  - ARPPU (bar chart)
  - Expansion vs Contraction MRR (diverging bars)
  - Churned Revenue & Paid Users (combo)
  - Returning MRR & Paid Users (combo)
- **3 interactive filters**: Date Range, Age, Language

The color palette is intentionally aligned with metric semantics: teal for positive metrics, coral for negative, yellow for neutral unit economics, purple for the unique returning-customers metric.

---

## Key Business Insight

Analysis revealed a **mass churn event in November**: 71 customers left the service, taking $2,800 in monthly revenue with them. This was the largest single-month outflow of the entire period and clearly stands out against the relatively healthy ARPPU and steady new-business acquisition. The recommendation for the business team is to investigate the cohort responsible for the November churn and design targeted win-back activities.

The November churn is partially compensated by Returning MRR — by December, 33 customers came back with $1,361 in revenue, suggesting that re-engagement mechanics are functioning to some degree.

---

## Repository Structure

```
revenue-metrics-dashboard/
├── README.md             — project documentation
└── revenue_metrics.sql   — PostgreSQL transformation query
```

---

## Author

**Dmytro Degtiarov** — Data Analyst
[LinkedIn](https://linkedin.com/in/dmytro-degtiarov) · [Email](mailto:maildegtiarov@gmail.com)
