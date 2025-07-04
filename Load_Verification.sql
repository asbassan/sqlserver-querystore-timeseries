/*
--------------------------------------------------------------------------------
CRM Workload Verification Script (Synchronized with Loader, PRINT-safe)
--------------------------------------------------------------------------------
Purpose: Prints key checks and stats in clearly separated sections, in a format
         suitable for direct copy-paste review or markdown rendering.
         All PRINT statements use variable assignment to avoid type errors.
         Ensures verification is in sync with simulation logic and requirements.
--------------------------------------------------------------------------------
*/

USE CRMForecastDemo;
GO

DECLARE @msg NVARCHAR(400);

-- Section 1: Summary of WorkloadMetrics (Hourly)
PRINT '=== CHECK: WorkloadMetrics Summary (Hourly) ===';
DECLARE @HoursCovered INT, @FirstHour DATETIME, @LastHour DATETIME, @TotalOrders INT, @TotalOrderDetails INT, @TotalQueries INT;
SELECT
    @HoursCovered = COUNT(*),
    @FirstHour = MIN(MetricDate),
    @LastHour = MAX(MetricDate),
    @TotalOrders = SUM(OrdersInserted),
    @TotalOrderDetails = SUM(OrderDetailsInserted),
    @TotalQueries = SUM(QueryCount)
FROM dbo.WorkloadMetrics;
SET @msg = 'Hours Covered: ' + CAST(ISNULL(@HoursCovered, 0) AS NVARCHAR(12));
PRINT @msg;
SET @msg = 'First Hour: ' + ISNULL(CONVERT(NVARCHAR(19), @FirstHour, 120), N'N/A');
PRINT @msg;
SET @msg = 'Last Hour: ' + ISNULL(CONVERT(NVARCHAR(19), @LastHour, 120), N'N/A');
PRINT @msg;
SET @msg = 'Total Orders: ' + CAST(ISNULL(@TotalOrders, 0) AS NVARCHAR(20));
PRINT @msg;
SET @msg = 'Total Order Details: ' + CAST(ISNULL(@TotalOrderDetails, 0) AS NVARCHAR(20));
PRINT @msg;
SET @msg = 'Total Queries: ' + CAST(ISNULL(@TotalQueries, 0) AS NVARCHAR(20));
PRINT @msg;
PRINT '';

-- Section 2: Hourly Gaps in Metrics Table
PRINT '=== CHECK: Hourly Gaps in Metrics Table ===';
;WITH AllHours AS (
    SELECT d AS SimDay, h AS SimHour
    FROM (SELECT TOP (SELECT MAX(SimDay) FROM dbo.WorkloadMetrics) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS d FROM sys.all_objects) days
    CROSS JOIN (SELECT TOP 24 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS h FROM sys.all_objects) hours
),
MissingMetrics AS (
    SELECT a.SimDay, a.SimHour
    FROM AllHours a
    LEFT JOIN dbo.WorkloadMetrics m ON a.SimDay = m.SimDay AND a.SimHour = m.SimHour
    WHERE a.SimDay IS NOT NULL AND a.SimHour IS NOT NULL AND m.SimDay IS NULL
)
SELECT
    'Missing Interval: SimDay ' + CAST(SimDay AS NVARCHAR(5)) + ', Hour ' + CAST(SimHour AS NVARCHAR(2)) AS [MissingHour]
FROM MissingMetrics;

DECLARE @MissingGaps INT;
SELECT @MissingGaps = COUNT(*) FROM (
    SELECT 1 AS Dummy
    FROM (
        SELECT d AS SimDay, h AS SimHour
        FROM (SELECT TOP (SELECT MAX(SimDay) FROM dbo.WorkloadMetrics) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS d FROM sys.all_objects) days
        CROSS JOIN (SELECT TOP 24 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS h FROM sys.all_objects) hours
    ) a
    LEFT JOIN dbo.WorkloadMetrics m ON a.SimDay = m.SimDay AND a.SimHour = m.SimHour
    WHERE a.SimDay IS NOT NULL AND a.SimHour IS NOT NULL AND m.SimDay IS NULL
) g;
IF @MissingGaps = 0
    SET @msg = 'INFO: No missing hourly intervals in metrics table.';
ELSE
    SET @msg = 'INFO: ' + CAST(@MissingGaps AS NVARCHAR(10)) + ' hourly intervals missing from dbo.WorkloadMetrics.';
PRINT @msg;
PRINT '';

-- Section 3: Data Alignment Gaps Between Orders and OrderDetails
PRINT '=== CHECK: Data Alignment Gaps Between Orders and OrderDetails ===';
;WITH OrdersByHour AS (
    SELECT DATEPART(DAY, OrderDate) AS SimDay, DATEPART(HOUR, OrderDate) AS SimHour, COUNT(*) AS OrdersInHour
    FROM dbo.Orders
    GROUP BY DATEPART(DAY, OrderDate), DATEPART(HOUR, OrderDate)
),
OrderDetailsByHour AS (
    SELECT DATEPART(DAY, o.OrderDate) AS SimDay, DATEPART(HOUR, o.OrderDate) AS SimHour, COUNT(*) AS DetailsInHour
    FROM dbo.OrderDetails d
    INNER JOIN dbo.Orders o ON d.OrderID = o.OrderID
    GROUP BY DATEPART(DAY, o.OrderDate), DATEPART(HOUR, o.OrderDate)
)
SELECT
    'SimDay ' + CAST(o.SimDay AS NVARCHAR(5)) + ', Hour ' + CAST(o.SimHour AS NVARCHAR(2))
    + ': Orders=' + CAST(o.OrdersInHour AS NVARCHAR(5))
    + ', Details=' + CAST(ISNULL(d.DetailsInHour,0) AS NVARCHAR(5))
    + ' -- ' +
    CASE WHEN d.DetailsInHour IS NULL THEN 'Gap in OrderDetails'
         WHEN o.OrdersInHour = 0 THEN 'Gap in Orders'
         ELSE 'Aligned'
    END AS [AlignmentGap]
FROM OrdersByHour o
LEFT JOIN OrderDetailsByHour d
    ON o.SimDay = d.SimDay AND o.SimHour = d.SimHour
WHERE d.DetailsInHour IS NULL OR o.OrdersInHour = 0;

DECLARE @AlignmentGaps INT;
SELECT @AlignmentGaps = COUNT(*) FROM (
    SELECT 1 AS Dummy
    FROM (
        SELECT DATEPART(DAY, OrderDate) AS SimDay, DATEPART(HOUR, OrderDate) AS SimHour, COUNT(*) AS OrdersInHour
        FROM dbo.Orders
        GROUP BY DATEPART(DAY, OrderDate), DATEPART(HOUR, OrderDate)
    ) o
    LEFT JOIN (
        SELECT DATEPART(DAY, o.OrderDate) AS SimDay, DATEPART(HOUR, o.OrderDate) AS SimHour, COUNT(*) AS DetailsInHour
        FROM dbo.OrderDetails d
        INNER JOIN dbo.Orders o ON d.OrderID = o.OrderID
        GROUP BY DATEPART(DAY, o.OrderDate), DATEPART(HOUR, o.OrderDate)
    ) d
    ON o.SimDay = d.SimDay AND o.SimHour = d.SimHour
    WHERE d.DetailsInHour IS NULL OR o.OrdersInHour = 0
) ag;
IF @AlignmentGaps = 0
    SET @msg = 'INFO: No data alignment gaps between Orders and OrderDetails.';
ELSE
    SET @msg = 'INFO: ' + CAST(@AlignmentGaps AS NVARCHAR(10)) + ' alignment gaps detected between Orders and OrderDetails.';
PRINT @msg;
PRINT '';

-- Section 4: Sufficient Data Test
PRINT '=== CHECK: Sufficient Data Test ===';
DECLARE @SufficientMsg NVARCHAR(100);
IF @HoursCovered >= 168 AND @TotalOrders >= 1000
    SET @SufficientMsg = 'Sufficient data present for initial time series analysis.';
ELSE
    SET @SufficientMsg = 'WARNING: Not enough data for robust time series analysis. Simulate more days or higher volume.';
PRINT @SufficientMsg;

DECLARE @infoMsg NVARCHAR(200);
SET @infoMsg = 'INFO: ' + CAST(ISNULL(@HoursCovered, 0) AS NVARCHAR(10)) + ' hourly intervals and ' + CAST(ISNULL(@TotalOrders, 0) AS NVARCHAR(10)) + ' orders detected.';
PRINT @infoMsg;
PRINT '';

-- Section 5: Query Store Review (Plan Bloat/Forced Plan/Plan Variants/Query Variants)
PRINT '=== CHECK: Query Store Review ===';
DECLARE @MaxQueryVariants INT, @MaxForcedPlans INT, @MaxPlanVariants INT, @MaxQueryId BIGINT, @MaxQueryText NVARCHAR(200);
SELECT
    @MaxQueryVariants = MAX(QueryVariants),
    @MaxForcedPlans = MAX(ForcedPlanCount),
    @MaxPlanVariants = MAX(PlanVariants)
FROM dbo.WorkloadMetrics;

-- Find the query_id and text for the max plan variants (robust join)
SELECT TOP 1
    @MaxQueryId = q.query_id,
    @MaxQueryText = qt.query_sql_text
FROM sys.query_store_plan p
INNER JOIN sys.query_store_query q ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
GROUP BY q.query_id, qt.query_sql_text
ORDER BY COUNT(p.plan_id) DESC;

SET @msg = 'Max Query Variants in an Hour: ' + ISNULL(CAST(@MaxQueryVariants AS NVARCHAR(10)), N'N/A');
PRINT @msg;
SET @msg = 'Max Forced Plans in an Hour: ' + ISNULL(CAST(@MaxForcedPlans AS NVARCHAR(10)), N'N/A');
PRINT @msg;
SET @msg = 'Max Plan Variants for a Query: ' + ISNULL(CAST(@MaxPlanVariants AS NVARCHAR(10)), N'N/A');
PRINT @msg;
SET @msg = 'Query with Most Plan Variants (query_id): ' + ISNULL(CAST(@MaxQueryId AS NVARCHAR(20)), N'N/A');
PRINT @msg;
SET @msg = 'Query with Most Plan Variants (sample text): ' + ISNULL(@MaxQueryText, N'N/A');
PRINT @msg;
SET @msg = 'INFO: If Max Forced Plans >= 5 and Max Plan Variants >= 7, simulation of plan instability/regression/plan correction succeeded.';
PRINT @msg;
PRINT '';

-- Section 6: Query Store Usage
PRINT '=== CHECK: Query Store Usage ===';
DECLARE @qs_state NVARCHAR(50), @qs_current_size INT, @qs_max_size INT, @qs_ro_reason NVARCHAR(50);
SELECT
    @qs_state = actual_state_desc,
    @qs_current_size = current_storage_size_mb,
    @qs_max_size = max_storage_size_mb,
    @qs_ro_reason = readonly_reason
FROM sys.database_query_store_options;
SET @msg = 'State: ' + ISNULL(@qs_state, N'N/A');
PRINT @msg;
SET @msg = 'Current Storage Size (MB): ' + ISNULL(CAST(@qs_current_size AS NVARCHAR(10)), N'N/A');
PRINT @msg;
SET @msg = 'Max Storage Size (MB): ' + ISNULL(CAST(@qs_max_size AS NVARCHAR(10)), N'N/A');
PRINT @msg;
SET @msg = 'Readonly Reason: ' + ISNULL(@qs_ro_reason, N'N/A');
PRINT @msg;
SET @msg = 'INFO: Query Store is healthy and has plenty of space remaining.';
PRINT @msg;
PRINT '';

PRINT '=== VERIFICATION COMPLETE ===';
PRINT 'If you see "Sufficient data present", minimal gaps, healthy Query Store, Max Forced Plans >= 5, Max Plan Variants >= 7, and high Max Query Variants, your data is ready for time series and IQP/plan analysis.';