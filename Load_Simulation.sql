/*
--------------------------------------------------------------------------------
Simulated Workload Script: Realistic Patterns, Gaps, Seasonality, Anomalies
--- MODERATE GAP PROBABILITIES FOR REALISTIC WORKLOAD ---
--------------------------------------------------------------------------------
- Simulates 20 days of hourly data for 2 queries, 5 variants each
- Probabilities for data gaps and regressions are set for realistic (not excessive) gaps.
--------------------------------------------------------------------------------
*/

/* 1. Deterministic pseudo-random function */
IF OBJECT_ID('dbo.randf') IS NOT NULL
    DROP FUNCTION dbo.randf;
GO
CREATE FUNCTION dbo.randf(@seed1 INT, @seed2 INT, @amp FLOAT)
RETURNS FLOAT
AS
BEGIN
    RETURN ((CAST(CHECKSUM(@seed1, @seed2) AS FLOAT) / 2147483647.0 - 0.5) * 2 * @amp);
END
GO

/* 2. Ensure necessary tables exist */
IF OBJECT_ID('dbo.SimulatedQueryMetrics', 'U') IS NULL
    CREATE TABLE dbo.SimulatedQueryMetrics (
        SimDay INT NOT NULL,
        SimHour INT NOT NULL,
        MetricDate DATETIME NOT NULL,
        QueryName NVARCHAR(100) NOT NULL,
        QueryVariant INT NOT NULL,
        CPU FLOAT NULL,
        LatencyMs FLOAT NULL,
        LogicalReads FLOAT NULL,
        PlanRegression BIT DEFAULT 0,
        PRIMARY KEY (SimDay, SimHour, QueryName, QueryVariant)
    );

IF OBJECT_ID('dbo.SimulatedQueryVariants', 'U') IS NULL
    CREATE TABLE dbo.SimulatedQueryVariants (
        QueryName NVARCHAR(100) NOT NULL,
        QueryVariant INT NOT NULL,
        IsRegression BIT DEFAULT 0,
        Notes NVARCHAR(200),
        PRIMARY KEY(QueryName, QueryVariant)
    );

IF OBJECT_ID('dbo.SimulationState', 'U') IS NOT NULL
    DROP TABLE dbo.SimulationState;
CREATE TABLE dbo.SimulationState (
    LastDay INT NOT NULL,
    LastHour INT NOT NULL,
    PRIMARY KEY (LastDay, LastHour)
);

/* 3. Populate Query Variants & Plan Regressions (idempotent) */
IF NOT EXISTS (SELECT 1 FROM dbo.SimulatedQueryVariants)
BEGIN
    DECLARE @q INT = 1, @v INT, @r INT, @regression INT;
    WHILE @q <= 2
    BEGIN
        SET @v = 1;
        SET @r = 0;
        WHILE @v <= 5
        BEGIN
            -- Multiple variants marked as regression
            SET @regression = CASE WHEN @v IN (2,3,4) THEN 1 ELSE 0 END;
            INSERT INTO dbo.SimulatedQueryVariants (QueryName, QueryVariant, IsRegression, Notes)
            VALUES (
                CONCAT('Q',@q), @v, @regression,
                CASE WHEN @regression=1 THEN 'Plan regression simulated' ELSE NULL END
            );
            SET @v = @v + 1;
        END
        SET @q = @q + 1;
    END
END

/* 4. Simulation Logic (moderate gap rates for realistic test) */
TRUNCATE TABLE dbo.SimulatedQueryMetrics;
DELETE FROM dbo.SimulationState;

DECLARE @SimulationDays INT = 20;
DECLARE @HoursPerDay INT = 24;
DECLARE @NumQueries INT = 2;
DECLARE @VariantsPerQuery INT = 5;

DECLARE @Day INT, @Hour INT, @Query INT, @Variant INT,
        @QueryName NVARCHAR(100), @IsRegression BIT,
        @CPU FLOAT, @Latency FLOAT, @Reads FLOAT,
        @trend FLOAT, @season FLOAT, @noise FLOAT,
        @MetricDate DATETIME,
        @Weekly FLOAT, @Hourly FLOAT, @Drift FLOAT,
        @BusinessHours INT, @Spike BIT, @Outage BIT, @ClusterOutage BIT,
        @GapDay BIT, @GapCPU BIT, @GapLat BIT, @GapReads BIT,
        @ClusterStartDay INT, @ClusterStartHour INT, @ClusterLen INT,
        @DeployDay INT;

-- MODERATE probabilities for realistic simulation (not excessive gaps)
DECLARE @DayGapProb INT = 50;     -- 2% of rows will have all metrics NULL
DECLARE @MetricGapProb INT = 15;  -- ~7% chance per metric
DECLARE @AnomalyProb INT = 100;   -- 1% anomaly
DECLARE @SpikeProb INT = 20;      -- 5% chance per row for a modest spike
DECLARE @ClusterGapProb INT = 100;-- 1% for clustered outage
DECLARE @OutageProb INT = 30;     -- ~3% for random short outage

-- Simulate a 4-hour outage block on day 5, 4-7am (clustered gap example)
SET @ClusterStartDay = 5;
SET @ClusterStartHour = 4;
SET @ClusterLen = 4;

-- Simulate a deployment event at day 10 (shift means upwards)
SET @DeployDay = 10;

SET @Day = 1;
WHILE @Day <= @SimulationDays
BEGIN
    SET @Hour = 0;
    WHILE @Hour < @HoursPerDay
    BEGIN
        SET @Query = 1;
        WHILE @Query <= @NumQueries
        BEGIN
            SET @Variant = 1;
            WHILE @Variant <= @VariantsPerQuery
            BEGIN
                SET @QueryName = CONCAT('Q',@Query);

                SELECT @IsRegression = IsRegression FROM dbo.SimulatedQueryVariants
                WHERE QueryName = @QueryName AND QueryVariant = @Variant;

                SET @MetricDate = DATEADD(HOUR, (@Day-1)*24+@Hour, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0));

                /* Realistic Patterns */
                SET @Weekly = 12*COS(2*PI()*((@Day-1)/7.0 + (@Hour/168.0)));
                SET @BusinessHours = CASE WHEN @Hour BETWEEN 8 AND 18 THEN 1 ELSE 0 END;
                SET @Hourly = 8*SIN(2*PI()*@Hour/24 + @Variant);
                SET @Drift = 0.7 * @Day;
                SET @trend = 30 + @Variant*4 + @Query*6 + @Drift + @Weekly + @Hourly + 10*@BusinessHours;

                -- Plan regression: moderate window
                IF @IsRegression = 1 AND @Day BETWEEN 7 AND 14
                    SET @trend = @trend + 25;

                -- Simulate deployment at day 10
                IF @Day = @DeployDay AND @Hour BETWEEN 9 AND 13
                    SET @trend = @trend + 20;

                SET @noise = dbo.randf(@Day*10000 + @Hour*100 + @Query*10 + @Variant, 101, 6);

                SET @CPU = @trend + @noise;

                -- Anomaly (occasional)
                SET @Spike = CASE WHEN ABS(CHECKSUM(@Day*@Hour+@Query*@Variant, 3333)) % @AnomalyProb = 0 THEN 1 ELSE 0 END;
                IF @Spike = 1
                    SET @CPU = @CPU * (2 + ABS(CHECKSUM(@Day, @Hour, 4444)) % 4);

                -- Small random spike (modest)
                IF ABS(CHECKSUM(@Day*@Hour+@Query*@Variant, 5555)) % @SpikeProb = 0
                    SET @CPU = @CPU * (1.2 + dbo.randf(@Day, @Hour, 0.3));

                -- Latency: correlated to CPU
                SET @Latency = 110 + 1.6*@CPU + dbo.randf(@Day*20000 + @Hour*200 + @Query*20 + @Variant, 222, 9);
                IF @IsRegression = 1 AND @Day BETWEEN 7 AND 14 SET @Latency = @Latency + 40;
                IF @Day = @DeployDay AND @Hour BETWEEN 9 AND 13 SET @Latency = @Latency + 30;
                IF @Spike = 1 SET @Latency = @Latency * (1.5 + dbo.randf(@Day, @Hour, 0.5));

                -- Reads: scaled to CPU, plus noise
                SET @Reads = 80 + 1.2*@CPU + @Variant*7 + dbo.randf(@Day*30000 + @Hour*300 + @Query*30 + @Variant, 333, 6);

                /* Gaps / Missingness */
                SET @ClusterOutage = CASE WHEN @Day = @ClusterStartDay AND @Hour BETWEEN @ClusterStartHour AND (@ClusterStartHour + @ClusterLen - 1) THEN 1 ELSE 0 END;
                SET @Outage = CASE WHEN ABS(CHECKSUM(@Day, @Hour, 7777)) % @OutageProb = 0 THEN 1 ELSE 0 END;

                IF @ClusterOutage = 1 OR @Outage = 1
                BEGIN
                    SET @CPU = NULL;
                    SET @Latency = NULL;
                    SET @Reads = NULL;
                END
                ELSE
                BEGIN
                    SET @GapDay = CASE WHEN ABS(CHECKSUM(@Day*10000 + @Hour*100 + @Query*10 + @Variant, 9001)) % @DayGapProb = 0 THEN 1 ELSE 0 END;
                    IF @GapDay = 1
                    BEGIN
                        SET @CPU = NULL;
                        SET @Latency = NULL;
                        SET @Reads = NULL;
                    END
                    ELSE
                    BEGIN
                        SET @GapCPU = CASE WHEN ABS(CHECKSUM(@Day*10000 + @Hour*100 + @Query*10 + @Variant, 9002)) % @MetricGapProb = 0 THEN 1 ELSE 0 END;
                        SET @GapLat = CASE WHEN ABS(CHECKSUM(@Day*10000 + @Hour*100 + @Query*10 + @Variant, 9003)) % @MetricGapProb = 0 THEN 1 ELSE 0 END;
                        SET @GapReads = CASE WHEN ABS(CHECKSUM(@Day*10000 + @Hour*100 + @Query*10 + @Variant, 9004)) % @MetricGapProb = 0 THEN 1 ELSE 0 END;
                        IF @GapCPU = 1 SET @CPU = NULL;
                        IF @GapLat = 1 SET @Latency = NULL;
                        IF @GapReads = 1 SET @Reads = NULL;
                    END
                END

                -- Correlated missingness
                IF @CPU IS NULL
                BEGIN
                    IF dbo.randf(@Day, @Hour, 1) > 0.7 SET @Latency = NULL;
                    IF dbo.randf(@Hour, @Variant, 1) > 0.7 SET @Reads = NULL;
                END

                -- Insert
                INSERT INTO dbo.SimulatedQueryMetrics
                (SimDay, SimHour, MetricDate, QueryName, QueryVariant, CPU, LatencyMs, LogicalReads, PlanRegression)
                VALUES
                (@Day, @Hour, @MetricDate, @QueryName, @Variant, @CPU, @Latency, @Reads, @IsRegression);

                SET @Variant = @Variant + 1;
            END
            SET @Query = @Query + 1;
        END
        SET @Hour = @Hour + 1;
    END
    SET @Day = @Day + 1;
END

PRINT 'Realistic simulated workload with MODERATE gap/regression rates complete!';
GO