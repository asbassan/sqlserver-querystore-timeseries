# Benchmarking Time Series Forecasting on Synthetic SQL Server Query Telemetry

This repository provides a fully reproducible framework for benchmarking state-of-the-art time series forecasting models on realistic, **synthetically-generated SQL Server query performance telemetry**. It enables researchers and practitioners to evaluate model robustness under operational data gaps, plan regression events, and regime shifts, using a standardized and explainable simulation approach.

## 📄 Paper

**Title:** Benchmarking Time Series Forecasting Models on Synthetic, Operationally-Augmented SQL Server Query Telemetry  
**Authors:** [A.S. Bassan](https://github.com/asbassan)  
**PDF:** [`Benchmarking_Time_Series_Forecasting_Models_on_Synthetic__Operationally_Augmented_SQL_Server_Query_Telemetry (6).pdf`](Benchmarking_Time_Series_Forecasting_Models_on_Synthetic__Operationally_Augmented_SQL_Server_Query_Telemetry%20(6).pdf)

---

## 🚀 Key Features

- **Realistic Synthetic Data:** Simulates 20 days of hourly SQL Server query performance data, including gaps, plan regressions, and regime shifts.
- **Multi-Model Benchmarking:** Compares ARIMA, Prophet, LSTM, Random Forest, and XGBoost models.
- **Robustness Analysis:** Evaluates model performance under data gaps (missingness) and operational regime changes.
- **End-to-End Notebooks:** Jupyter notebooks for dataset verification, exploratory analysis, benchmarking, and robustness studies.
- **SQL + Python Workflow:** All data generation is in SQL, analytics/benchmarks in Python (Jupyter).

---

## 📦 Repository Structure

```
.
├── Benchmarking_Time_Series_Forecasting_Models_on_Synthetic__Operationally_Augmented_SQL_Server_Query_Telemetry (6).pdf    # Paper
├── Load_Simulation.sql                   # SQL script to generate synthetic workload (metrics for queries)
├── Load_Verification.sql                 # SQL script to verify/validate the simulated dataset
├── SimulatedQueryMetrics.csv             # Output: Synthetic telemetry dataset (used by all notebooks)
├── Model_Performance_CI_Grouped_Q1_Q2.ipynb                  # Benchmarking with 95% CI (grouped by Q1/Q2)
├── Model_Performance_Gaps_Regimes.ipynb                      # Benchmarking: Impact of gaps and regime shifts
├── Section5A_Dataset_Verification.ipynb                      # Verification and summary stats of dataset
├── Section5B_Stationarity_Tests.ipynb                        # Stationarity and autocorrelation analysis
├── Section5C_Exploratory_Analysis.ipynb                      # Exploratory analysis, time series plots, correlations
├── Section5d_FrequencyDomain_Analysis.ipynb                  # Frequency-domain (Fourier, periodogram) analysis
├── Section5e_Model_Benchmarking_Results_Corrected.ipynb      # Model benchmarking: train/predict time, RMSE
├── benchmark_summary_all_queries_metrics.ipynb                # Summary benchmarking table (all queries/metrics)
```

---

## 🏗️ How to Use

### 1. Simulate the Workload in SQL Server

- Run `Load_Simulation.sql` in your SQL Server instance to generate the dataset:
    - Creates `dbo.SimulatedQueryMetrics` with realistic hourly CPU, Latency, and LogicalReads for 2 queries × 5 variants over 20 days.
    - Includes operational patterns: gaps, anomalies, plan regressions, deployment shifts.

- Optionally, run `Load_Verification.sql` to print and check data quality and summary statistics.

### 2. Export the Dataset

- Export the `SimulatedQueryMetrics` table to CSV as `SimulatedQueryMetrics.csv`.
    - (e.g., using SQL Server Management Studio's export tools or `bcp` utility)

### 3. Python Benchmarking & Analysis

- Install dependencies:
    ```bash
    pip install numpy pandas scikit-learn xgboost statsmodels prophet tensorflow matplotlib seaborn tabulate
    ```

- Open and run the notebooks (in order of typical workflow):

    1. **Section5A_Dataset_Verification.ipynb**  
       - Confirms data quality, null/missingness, and suitability for time series forecasting.
    2. **Section5B_Stationarity_Tests.ipynb**  
       - Tests for stationarity, autocorrelation (ADF, ACF, PACF).
    3. **Section5C_Exploratory_Analysis.ipynb**  
       - Visualizes time series, explores correlations.
    4. **Section5d_FrequencyDomain_Analysis.ipynb**  
       - Frequency (spectral) analysis: periodogram, white noise checks.
    5. **Section5e_Model_Benchmarking_Results_Corrected.ipynb**  
       - Benchmarks ARIMA, Prophet, LSTM, Random Forest, XGBoost on real simulated data; reports train/predict time and RMSE.
    6. **Model_Performance_CI_Grouped_Q1_Q2.ipynb**  
       - Produces Table 1: RMSE ± 95% CI for each model, grouped by query and metric.
    7. **Model_Performance_Gaps_Regimes.ipynb**  
       - Produces Table 2: Model RMSE in normal, gap, and plan regression periods; % impact.
    8. **benchmark_summary_all_queries_metrics.ipynb**  
       - End-to-end benchmarking summary for all query/metric/model combinations.

---

## 📊 Example Outputs

- **SimulatedQueryMetrics.csv:**  
    - ~2,400 rows (20 days × 24 hours × 2 queries × 5 variants)
    - Columns: SimDay, SimHour, MetricDate, QueryName, QueryVariant, CPU, LatencyMs, LogicalReads, PlanRegression

- **Benchmarking Tables:**  
    - RMSE ± 95% CI for each model/query/metric
    - Gap and regime analysis: % increase in error under operational disruptions

---

## ✨ Research/Design Highlights

- **Synthetic Data with Realistic Missingness:**  
    - Gaps are injected with moderate, empirically justified probabilities (see `Load_Simulation.sql`).
    - Plan regression and deployment events are explicitly simulated.

- **Modeling Pipeline:**  
    - All forecasting models use lagged features (7 lags), expanding window cross-validation, and comparable splits.
    - LSTM, tree, and statistical models are benchmarked side-by-side.

- **Reproducibility:**  
    - All simulation logic is SQL-native and deterministic.
    - Notebooks can be re-run for full end-to-end validation.

---

## 📚 Reference

If you use this dataset or code, please cite:

> Bassan, A.S., "Benchmarking Time Series Forecasting Models on Synthetic, Operationally-Augmented SQL Server Query Telemetry", 2024.  
> [PDF Link](Benchmarking_Time_Series_Forecasting_Models_on_Synthetic__Operationally_Augmented_SQL_Server_Query_Telemetry%20(6).pdf)

---

## 📬 Issues & Contributions

- File issues or questions via GitHub Issues.
- Pull requests are welcome for improvements, bugfixes, or extensions (e.g., new models, new operational patterns).

---

## License

This repository is released under the MIT License.

---

**Contact:** [asbassan@github](https://github.com/asbassan)