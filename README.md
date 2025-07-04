# sqlserver-querystore-timeseries

**A Novel Simulation Framework for Time Series Analysis and Forecasting in SQL Server Query Store Workloads**

---

## Overview

This repository provides a robust simulation environment and verification toolkit for generating and analyzing synthetic time series data derived from SQL Server Query Store. It is designed to enable experimentation with forecasting, anomaly detection, and workload prediction on realistic, plan-diverse, and gap-rich query workloads.

The project lays the foundation for proactive workload management in SQL Server, illustrating how Query Store's time series data can be used not just for reactive diagnostics, but also for predictive analytics and research into workload forecasting.

---

## Features

- **Synthetic Workload Simulation:**  
  Generates Orders, OrderDetails, and rich query mix with random gaps, plan bloat, forced plans, and high plan diversity.
- **Gap Realism:**  
  Simulates random, independent missing intervals per entity to mimic real-world ETL failures/delays.
- **Advanced Query Features:**  
  Exercises plan cache, plan regression, and plan forcing for robust Query Store data.
- **Restartable & Reproducible:**  
  Designed to safely resume or rerun with parameterized settings.
- **Verification Script:**  
  Ensures the generated dataset has the characteristics (length, continuity, gaps, diversity) needed for time series analysis (TSA).

---

## Repository Contents

- [`load_simulation.sql`](Load_Simulation.sql)  
  Simulates a synthetic CRM-like workload against a dedicated SQL Server database, generating time series data with plan bloat, forced plans, and random gaps.

- [`load_verification.sql`](Load_Verification.sql)  
  Verifies the generated dataset, checking for required time series length, gap distribution, plan variant diversity, and other key metrics to ensure suitability for TSA research.

---

## Getting Started

### 1. Prerequisites

- Microsoft SQL Server 2019 or later (with Query Store enabled)
- Sufficient disk space for the database files (default: 20 GiB data, 8 GiB log)
- Permissions to create, modify, and drop databases

### 2. Usage

#### **A. Run the Simulation**

1. Open `load_simulation.sql` in SQL Server Management Studio or your preferred SQL tool.
2. Adjust parameters at the top of the script if needed (simulation days, gap probability, etc.).
3. Execute the script.  
   - This will create `CRMForecastDemo` database, populate Orders, OrderDetails, WorkloadMetrics, and simulate realistic gaps and query plan diversity.

#### **B. Verify the Data**

1. After simulation completes, open `load_verification.sql`.
2. Execute the script in the same database context.
3. Review the output to confirm:
   - Time series length is sufficient for your TSA experiments
   - Gaps and plan variants are present as expected
   - Metrics are consistent with experimental aims

---

## Applications & Research Directions

- **Time Series Forecasting of Workloads**
- **Anomaly Detection on Query Performance Metrics**
- **Proactive Query Optimization and Plan Management**
- **Benchmarking Model Suitability for Different Workload Patterns**
- **Exploring Overlap Between Time Series Analysis and Reinforcement Learning in DBMS Contexts**

---

## Citation

If you use this repository or its methodology in your research, please cite:

> "From Reaction to Prediction: Laying the Foundations for Time Series Forecasting in SQL Server Query Store Workloads"  
> [Authors/Institution, Year]

---

## License

MIT License (see [LICENSE](LICENSE))

---

## Acknowledgements

This repository and methodology were inspired by the need for reproducible, realistic, and diverse time series datasets for SQL Server Query Store research. For context and further reading, see [this blog post on ETL failure rates](https://datacater.io/blog/how-to-handle-etl-failures/).

---

## Contributions

Contributions and suggestions for extending the simulation, integrating new verification metrics, or supporting additional DBMS platforms are welcome. Please open an issue or submit a pull request.

---
