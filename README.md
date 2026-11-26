# Amazon Repeat Purchase Analysis and Prediction

A data analytics portfolio project that studies whether Amazon shoppers buy again, when they return, and how much they spend over the next 90 days. It uses MySQL for cohort analysis, Power BI for reporting, and Python for model evaluation.
<img width="1161" height="650" alt="amazon analysis" src="https://github.com/user-attachments/assets/22c331e8-8015-4e59-8988-6ffbb286805d" />

## Data and methodology

The [Amazon Open E-commerce 1.0 dataset](https://doi.org/10.7910/DVN/YGLYDY) contains purchase histories shared by U.S. Amazon shoppers. The MySQL import contained 1,850,717 product lines for 5,027 shoppers. The historical analysis used the 2018–2022 records.

- **Purchase day.** Multiple product lines from the same shopper on the same date count as one purchase day. The first observed purchase day can occur after a shopper’s actual first Amazon purchase.
- **Repeat purchase.** A shopper returned if they bought again on a later day within 90 days.
- **90-day spend.** Sum of unit price multiplied by quantity on days 1–90, with zero for shoppers who made no follow-up purchase.
- **Model evaluation.** Trained on 3,356 shoppers whose follow-up ended before July 2018 and tested on 507 shoppers first observed from July through December 2018. Inputs were first-day spend, units, and distinct products. Many training shoppers were first observed near the start of the dataset, which limits how broadly the results can be applied.

## What shoppers did

In the test cohort, **70.22%** bought again within 90 days and **48.92%** returned within 30 days. Average 90-day follow-up spend was **$130.40** across all 507 test shoppers.

| First return window | Shoppers | Share of test cohort | Average 90-day spend |
|---|---:|---:|---:|
| Days 1–30 | 248 | 48.92% | $224.72 |
| Days 31–60 | 62 | 12.23% | $122.26 |
| Days 61–90 | 46 | 9.07% | $60.87 |
| No return within 90 days | 151 | 29.78% | $0.00 |

The timing chart describes observed behavior. The classifiers predict whether a shopper returns within 90 days.

## Model results

### Outreach prioritization

Each method shortlisted 101 test shoppers.

| Method | Non-returners found | Shortlist non-return rate |
|---|---:|---:|
| Logistic regression | 35 | 34.65% |
| Lowest first-day spend | 34 | 33.66% |
| XGBoost | 32 | 31.68% |
| Random selection | About 30 expected | 29.78% expected |

At a return-probability threshold of 0.5, both classifiers predicted that every test shopper would return. With a fixed shortlist size, logistic regression identified one more non-returner than the spending rule. I selected the spending rule for the case study because it is easy to implement in SQL. A separate outreach experiment would be needed to measure whether contacting shortlisted shoppers increases purchases.

### 90-day spending prediction

| Method | Test mean absolute error |
|---|---:|
| Training median | **$178.62** |
| Training mean | $289.79 |
| Ridge regression | $294.02 |

The training median produced the lowest test error. Ridge regression using first-day purchase features did not improve the spending forecast.

## Reproduce the XGBoost run

1. Download the purchase CSV from [Harvard Dataverse](https://doi.org/10.7910/DVN/YGLYDY) and use the MySQL workflow to create the chronological modeling split.
2. Export the split as **shopper_model_split.csv** with these columns: first_day_spend, first_day_units, first_day_distinct_products, returned_90d, and data_split. The split values are train and test.
3. Run the commands below from the repository root with Python 3.13.

~~~bash
python -m pip install -r requirements.txt
python train_xgboost.py shopper_model_split.csv --output models
~~~

The training script writes an XGBoost JSON model, a Joblib snapshot, and test metrics. It reloads both model files and verifies that they reproduce the original test probabilities. Use the native JSON as the primary model file and load Joblib snapshots only from trusted sources.
