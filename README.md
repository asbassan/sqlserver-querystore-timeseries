# sqlserver-querystore-timeseries
## A Novel Simulation Framework for Time Series Analysis and Forecasting in SQL Server Query Store Workloads

---

## Overview

This repository provides a comprehensive simulation environment and verification toolkit for generating and analyzing realistic synthetic time series data derived from SQL Server Query Store. The framework is designed to facilitate experimentation with forecasting, anomaly detection, and workload prediction on richly patterned, plan-diverse, and gap-containing query workloads.

It establishes a reproducible foundation for proactive workload management in SQL Server, showcasing how Query Store time series data can be leveraged not just for diagnostics, but also for advanced predictive analytics and research.

---

## Features

### Synthetic Workload Simulation
- **Realistic Patterns:** Simulates 20 days of hourly data for multiple queries and variants, with daily/weekly seasonality, business-hour bursts, organic drift, and events such as deployments, plan regressions, and outliers.
- **Plan Diversity:** Models multiple query hashes (`QueryName`) and variants (`QueryVariant`), each with distinct behaviors and regression windows.
- **Correlated Metrics:** Generates CPU, Latency, and Logical Reads with realistic mathematical relationships.
- **Controlled Missingness:** Injects both random and clustered gaps, as well as correlated missing data, to mimic real-world telemetry and sensor failures.

### Gap Realism and Data Quality
- **Random and Clustered Gaps:** Probabilities are tuned to provide a realistic mix of mostly complete data with rare, but present gaps—allowing for meaningful TSA and anomaly research.
- **Outage Simulation:** Specific outage periods and random data loss help test algorithm robustness.

### Verification Script
- **Automated Data Health Checks:** Verifies the generated dataset with summary statistics, null ratios, gap counts, diversity, and plan regression presence.
- **Suitability for TSA:** Ensures the data is appropriate for time series analysis, forecasting, and anomaly detection.

### Reproducibility and Extensibility
- **Deterministic Randomness:** All simulations are seeded for reproducibility.
- **Parameterizable:** Easy to tune number of queries, gap probabilities, anomaly injection, and more for different research scenarios.
- **Extensible:** Framework is designed to be a solid, modifiable starting point for further research into query performance, gap handling, and advanced TSA.

---

## Repository Contents

- `load_simulation.sql`  
  Simulates a synthetic workload against SQL Server, producing time series data with plan drift, forced plans, events, and random/clustered gaps. The workload covers multiple queries and variants, and is suitable for TSA research.

- `load_verification.sql`  
  Verifies the generated time series dataset, reporting on length, gap distribution, plan diversity, event coverage, and overall data health. Output is designed to be pasted directly into research reports.

- `Section5_Data_Analysis_Notebook.ipynb`  
  (Recommended) Python notebook for downstream analysis, including dataset verification, exploratory analysis, and comparative forecasting with ARIMA, LSTM, Prophet, Random Forest, and XGBoost.

- `load_simulation_master_document.md`  
  Detailed documentation of the simulation framework, its logic, and research motivations.

---

## Getting Started

### 1. Prerequisites
- Microsoft SQL Server 2019 or later (Query Store enabled)
- Sufficient disk space for the database files
- Permissions to create/modify tables and run scripts

### 2. Usage

#### A. Run the Simulation
- Open `load_simulation.sql` in SQL Server Management Studio (SSMS) or Azure Data Studio.
- Adjust top-level parameters (days, gap probabilities, etc.) if desired.
- Execute the script to generate the synthetic workload with realistic gaps and plan diversity.

#### B. Verify the Data
- After simulation, open `load_verification.sql` in the same database.
- Execute the script.
- Review the output for:
  - Total rows and time coverage
  - Gap/plan regression counts
  - Null ratios and data health
  - Suitability for TSA and anomaly detection

#### C. Export for Analysis
- Export the `SimulatedQueryMetrics` table as CSV (see script or use SSMS “Save Results As…”).
- Use the provided Python notebook for downstream analysis and model benchmarking.

---

## Applications & Research Directions

- **Time Series Forecasting of Workloads**
- **Anomaly Detection on Query Performance Metrics**
- **Proactive Query Optimization and Plan Management**
- **Benchmarking Model Suitability for Different Workload Patterns**
- **Exploring Data Gaps, Outages, and Robustness in TSA**
- **Reinforcement Learning and Self-Driving DBMS Research**

---

## Citation

If you use this repository or its methodology in your research, please cite:

> "From Reaction to Prediction: Laying the Foundations for Time Series Forecasting in SQL Server Query Store Workloads"  
> [Authors/Institution, Year]

---

## License

MIT License (see LICENSE)

---

## Acknowledgements

This repository and methodology were inspired by the need for reproducible, realistic, and diverse time series datasets for SQL Server Query Store research. See `load_simulation_master_document.md` for a detailed discussion of simulation design, rationale, and future directions.

---

## Contributions

Contributions and suggestions for extending the simulation, integrating new verification metrics, or supporting additional DBMS platforms are welcome. Please open an issue or submit a pull request.
