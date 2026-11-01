# KPI definitions and target

| KPI | Definition | Columns used |
|---|---|---|
| % seen within 4 hours | (all A&E attendances minus attendances over 4 hours) / all A&E attendances, all department types | "A&E attendances ..." and "Attendances over 4hrs ..." (all six of each, booked appointments included) |
| Total attendances | sum of all A&E attendances, all department types | "A&E attendances ..." |
| 12 hour waits from decision to admit | patients who waited 12+ hours from decision to admit to admission | "Patients who have waited 12+ hrs from DTA to admission" |
| Month on month change | this month minus last month (percentage points for the 4 hour %) | |

## Target

**82% within 4 hours.** NHS England, Medium Term Planning Framework 2026/27 to 2028/29 (published 24 Oct 2025), page 30, success measures table: "Every trust to maintain or improve to 82% by March 2027".
https://www.england.nhs.uk/wp-content/uploads/2025/10/medium-term-planning-framework-delivering-change-together-2026-27-to-2028-29.pdf

The same framework sets 85% as the national average for 2028/29. The constitutional standard is 95%.

## RAG bands (my choice, stated as an assumption)

* Green: 82% or above (meets the 2026/27 target)
* Amber: 78% to 81.9% (meets last year's floor: "a minimum of 78% of patients seen within 4 hours in March 2026", NHS England 2025/26 priorities and operational planning guidance, https://www.england.nhs.uk/long-read/2025-26-priorities-and-operational-planning-guidance/)
* Red: under 78%

## Scope rules

* Source: NHS England, A&E Attendances and Emergency Admissions, monthly provider CSVs, October 2024 to September 2026 (24 months). Page: https://www.england.nhs.uk/statistics/statistical-work-areas/ae-waiting-times-and-activity/ . File URLs per month are in data/sources.csv.
* Each file's national total row is removed, and the provider rows are checked to add up exactly to it.
* RAG table and worst 10 list: only providers with a major (Type 1) A&E that month, so walk in centres and urgent treatment centres do not sit at the top with 100%.
* National and regional KPIs: all providers, all department types (this is how NHS England reports the headline figure).
