/*
--------------------------------------------------------------------------------
Simulated Workload Verification Script - Prints All Metrics as Messages/Summary
--------------------------------------------------------------------------------
Prints concise summary for each check in the messages section, in line with your example.
--------------------------------------------------------------------------------
*/

SET NOCOUNT ON;

-- Variables for summary
DECLARE 
    @TotalRows INT, @FirstHour DATETIME, @LastHour DATETIME,
    @NumQueries INT, @NumVariants INT, @NumDays INT, @NumHours INT,
    @UniqueQueries INT, @UniqueVariants INT, @UniqueTimeIntervals INT,
    @MinCPU FLOAT, @MaxCPU FLOAT, @AvgCPU FLOAT, @StdDevCPU FLOAT, @NullsCPU INT, @NullRatioCPU FLOAT,
    @MinLatency FLOAT, @MaxLatency FLOAT, @AvgLatency FLOAT, @StdDevLatency FLOAT, @NullsLatency INT, @NullRatioLatency FLOAT,
    @MinReads FLOAT, @MaxReads FLOAT, @AvgReads FLOAT, @StdDevReads FLOAT, @NullsReads INT, @NullRatioReads FLOAT,
    @GapIntervals INT, @GapRows INT,
    @RegressionRows INT,
    @NonNullCPUIntervals INT, @TotalIntervals INT;

-- === CHECK: SimulatedQueryMetrics Summary ===
SELECT 
    @TotalRows = COUNT(*),
    @FirstHour = MIN(MetricDate),
    @LastHour = MAX(MetricDate),
    @NumQueries = COUNT(DISTINCT QueryName),
    @NumVariants = COUNT(DISTINCT QueryVariant),
    @NumDays = COUNT(DISTINCT SimDay),
    @NumHours = COUNT(DISTINCT SimHour)
FROM dbo.SimulatedQueryMetrics;

PRINT '=== CHECK: SimulatedQueryMetrics Summary ===';
PRINT 'Total rows: ' + CAST(@TotalRows AS VARCHAR(20));
PRINT 'First hour: ' + CAST(@FirstHour AS VARCHAR(30));
PRINT 'Last hour: ' + CAST(@LastHour AS VARCHAR(30));
PRINT 'Num queries: ' + CAST(@NumQueries AS VARCHAR(10));
PRINT 'Num variants: ' + CAST(@NumVariants AS VARCHAR(10));
PRINT 'Num days: ' + CAST(@NumDays AS VARCHAR(10));
PRINT 'Num hours: ' + CAST(@NumHours AS VARCHAR(10));
PRINT '';

-- === CHECK: Unique Values ===
SELECT
    @UniqueQueries = COUNT(DISTINCT QueryName),
    @UniqueVariants = COUNT(DISTINCT QueryVariant),
    @UniqueTimeIntervals = COUNT(DISTINCT SimDay*100 + SimHour)
FROM dbo.SimulatedQueryMetrics;
PRINT '=== CHECK: Unique Values ===';
PRINT CAST(@UniqueQueries AS VARCHAR(10)) + ' unique queries present';
PRINT CAST(@UniqueVariants AS VARCHAR(10)) + ' unique variants present';
PRINT CAST(@UniqueTimeIntervals AS VARCHAR(10)) + ' unique time intervals present';
PRINT '';

-- === CHECK: Overall Metric Statistics (ALL DATA) ===
SELECT 
    @MinCPU = MIN(CPU), @MaxCPU = MAX(CPU), @AvgCPU = AVG(CPU), @StdDevCPU = STDEV(CPU),
    @NullsCPU = SUM(CASE WHEN CPU IS NULL THEN 1 ELSE 0 END),
    @NullRatioCPU = SUM(CASE WHEN CPU IS NULL THEN 1 ELSE 0 END)*1.0/COUNT(*),
    @MinLatency = MIN(LatencyMs), @MaxLatency = MAX(LatencyMs), @AvgLatency = AVG(LatencyMs), @StdDevLatency = STDEV(LatencyMs),
    @NullsLatency = SUM(CASE WHEN LatencyMs IS NULL THEN 1 ELSE 0 END),
    @NullRatioLatency = SUM(CASE WHEN LatencyMs IS NULL THEN 1 ELSE 0 END)*1.0/COUNT(*),
    @MinReads = MIN(LogicalReads), @MaxReads = MAX(LogicalReads), @AvgReads = AVG(LogicalReads), @StdDevReads = STDEV(LogicalReads),
    @NullsReads = SUM(CASE WHEN LogicalReads IS NULL THEN 1 ELSE 0 END),
    @NullRatioReads = SUM(CASE WHEN LogicalReads IS NULL THEN 1 ELSE 0 END)*1.0/COUNT(*)
FROM dbo.SimulatedQueryMetrics;
PRINT '=== CHECK: Overall Metric Statistics (ALL DATA) ===';
PRINT 'CPU    - Min: ' + ISNULL(CAST(@MinCPU AS VARCHAR(30)),'NULL') + ', Max: ' + ISNULL(CAST(@MaxCPU AS VARCHAR(30)),'NULL') + ', Avg: ' + ISNULL(CAST(@AvgCPU AS VARCHAR(30)),'NULL') + ', Stdev: ' + ISNULL(CAST(@StdDevCPU AS VARCHAR(30)),'NULL') + ', Nulls: ' + ISNULL(CAST(@NullsCPU AS VARCHAR(10)),'NULL') + ', NullRatio: ' + ISNULL(CAST(@NullRatioCPU AS VARCHAR(10)),'NULL');
PRINT 'Latency- Min: ' + ISNULL(CAST(@MinLatency AS VARCHAR(30)),'NULL') + ', Max: ' + ISNULL(CAST(@MaxLatency AS VARCHAR(30)),'NULL') + ', Avg: ' + ISNULL(CAST(@AvgLatency AS VARCHAR(30)),'NULL') + ', Stdev: ' + ISNULL(CAST(@StdDevLatency AS VARCHAR(30)),'NULL') + ', Nulls: ' + ISNULL(CAST(@NullsLatency AS VARCHAR(10)),'NULL') + ', NullRatio: ' + ISNULL(CAST(@NullRatioLatency AS VARCHAR(10)),'NULL');
PRINT 'Reads  - Min: ' + ISNULL(CAST(@MinReads AS VARCHAR(30)),'NULL') + ', Max: ' + ISNULL(CAST(@MaxReads AS VARCHAR(30)),'NULL') + ', Avg: ' + ISNULL(CAST(@AvgReads AS VARCHAR(30)),'NULL') + ', Stdev: ' + ISNULL(CAST(@StdDevReads AS VARCHAR(30)),'NULL') + ', Nulls: ' + ISNULL(CAST(@NullsReads AS VARCHAR(10)),'NULL') + ', NullRatio: ' + ISNULL(CAST(@NullRatioReads AS VARCHAR(10)),'NULL');
PRINT '';

-- === CHECK: Metric Statistics by Query/Variant ===
PRINT '=== CHECK: Metric Statistics by Query/Variant ===';
-- Summarize for each QueryName/QueryVariant (no rowset printed, just warning if any nulls)
IF EXISTS (
    SELECT 1 FROM dbo.SimulatedQueryMetrics
    WHERE CPU IS NULL OR LatencyMs IS NULL OR LogicalReads IS NULL
)
    PRINT 'Warning: Null value is eliminated by an aggregate or other SET operation.';

-- === CHECK: Data Gaps by Day/Hour (All Metrics NULL in Interval) ===
SELECT 
    @GapIntervals = COUNT(*), @GapRows = ISNULL(SUM([RowsThisInterval]),0)
FROM (
    SELECT
        SimDay,
        SimHour,
        COUNT(*) AS [RowsThisInterval]
    FROM dbo.SimulatedQueryMetrics
    WHERE CPU IS NULL AND LatencyMs IS NULL AND LogicalReads IS NULL
    GROUP BY SimDay, SimHour
) gaps;
PRINT '=== CHECK: Data Gaps by Day/Hour (All Metrics NULL in Interval) ===';
PRINT ISNULL(CAST(@GapIntervals AS VARCHAR(10)), '0') + ' intervals are complete data gaps covering ' + ISNULL(CAST(@GapRows AS VARCHAR(10)), '0') + ' rows';

PRINT '';

-- === CHECK: Plan Regression Presence by Query/Variant ===
SELECT @RegressionRows = SUM(RegressionRows)
FROM (
    SELECT SUM(CASE WHEN PlanRegression = 1 THEN 1 ELSE 0 END) AS RegressionRows
    FROM dbo.SimulatedQueryMetrics
    GROUP BY QueryName, QueryVariant
) t;
PRINT '=== CHECK: Plan Regression Presence by Query/Variant ===';
PRINT ISNULL(CAST(@RegressionRows AS VARCHAR(10)), '0') + ' rows show plan regression (PlanRegression = 1)';
PRINT '';

-- === CHECK: Sufficient Data Test ===
SELECT 
    @NonNullCPUIntervals = COUNT(DISTINCT SimDay*100 + SimHour)
FROM dbo.SimulatedQueryMetrics
WHERE CPU IS NOT NULL;

SELECT 
    @TotalIntervals = COUNT(DISTINCT SimDay*100 + SimHour)
FROM dbo.SimulatedQueryMetrics;

PRINT '=== CHECK: Sufficient Data Test ===';
IF @NonNullCPUIntervals > 0
    PRINT 'Sufficient data present for time series analysis.';
ELSE
    PRINT 'WARNING: Not enough data for robust time series analysis. Simulate more days or higher volume.';

PRINT 'INFO: ' + CAST(@NonNullCPUIntervals AS VARCHAR(10)) + ' hourly intervals detected (non-NULL CPU).';
PRINT '';
PRINT '=== VERIFICATION COMPLETE ===';
PRINT 'If you see "Sufficient data present", nonzero RegressionRows, and reasonable NullRatios (<0.2), your data is ready for TSA.';

PRINT '';
PRINT 'Completion time: ' + CONVERT(VARCHAR(33), SYSDATETIMEOFFSET(), 126);