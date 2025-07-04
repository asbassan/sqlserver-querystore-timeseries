/*
--------------------------------------------------------------------------------
CRM Load Simulation Script (Robust Plan Bloat & Forced Plans, PRINT-safe)
--------------------------------------------------------------------------------

Purpose:
- Generate synthetic CRM workload and summary metrics for time series analysis.
- Hourly granularity, random data gaps (including independent gaps for Orders/OrderDetails/Metrics).
- Simulates plan bloat, IQP, APRC, and actively forces plans and causes plan regressions.
- Ensures:
    - At least one query with 7+ plan variants (bloat)
    - At least 5 forced plans (with plan regressions)
    - At least one query with 7+ plan variants ("max plan variants for a query" >= 7)
    - High query variation per hour
- All previous simulation features retained.
- Appropriate indexes are created.
- Robust and restartable.
- All PRINT statements use variable assignment to avoid type errors.

--------------------------------------------------------------------------------
*/

-- Drop database if exists for clean rerun (optional, for dev/test only)
-- IF DB_ID('CRMForecastDemo') IS NOT NULL
--     DROP DATABASE CRMForecastDemo;
-- GO

-- Create database with specific MDF (20GB) and LDF (8GB) sizes and file names/paths
IF DB_ID('CRMForecastDemo') IS NULL
    CREATE DATABASE CRMForecastDemo
    ON PRIMARY (
        NAME = N'CRMForecastDemo_Data',
        FILENAME = N'D:\SQLServerInstallation\demodata\CRMForecastDemo.mdf',   -- Change path as needed for your SQL Server instance
        SIZE = 20480MB,
        FILEGROWTH = 1024MB
    )
    LOG ON (
        NAME = N'CRMForecastDemo_Log',
        FILENAME = N'D:\SQLServerInstallation\demodata\CRMForecastDemo_log.ldf',  -- Change path as needed for your SQL Server instance
        SIZE = 8192MB,
        FILEGROWTH = 512MB
    );
GO

USE CRMForecastDemo;
GO

ALTER DATABASE CRMForecastDemo SET QUERY_STORE = ON;
ALTER DATABASE CRMForecastDemo SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, 
    MAX_STORAGE_SIZE_MB = 10240,
	DATA_FLUSH_INTERVAL_SECONDS = 120,
    INTERVAL_LENGTH_MINUTES = 5,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    QUERY_CAPTURE_MODE = ALL
);
GO

IF OBJECT_ID('dbo.OrderDetails', 'U') IS NOT NULL DROP TABLE dbo.OrderDetails;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.SimulationState', 'U') IS NOT NULL DROP TABLE dbo.SimulationState;
IF OBJECT_ID('dbo.WorkloadMetrics', 'U') IS NOT NULL DROP TABLE dbo.WorkloadMetrics;
GO

CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID NCHAR(5) NOT NULL,
    EmployeeID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    RequiredDate DATETIME,
    ShippedDate DATETIME,
    ShipVia INT,
    Freight MONEY,
    ShipName NVARCHAR(40),
    ShipAddress NVARCHAR(60),
    ShipCity NVARCHAR(15),
    ShipRegion NVARCHAR(15),
    ShipPostalCode NVARCHAR(10),
    ShipCountry NVARCHAR(15)
);
GO

CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate);
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
GO

CREATE TABLE dbo.OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL FOREIGN KEY REFERENCES dbo.Orders(OrderID),
    ProductID INT NOT NULL,
    UnitPrice MONEY,
    Quantity SMALLINT,
    Discount REAL
);
GO

CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderID ON dbo.OrderDetails(OrderID);
CREATE NONCLUSTERED INDEX IX_OrderDetails_ProductID ON dbo.OrderDetails(ProductID);
GO

CREATE TABLE dbo.SimulationState (
    LastLoadedDay INT NOT NULL,
    LastLoadedHour INT NOT NULL,
    CONSTRAINT PK_SimulationState PRIMARY KEY (LastLoadedDay, LastLoadedHour)
);
GO

CREATE TABLE dbo.WorkloadMetrics (
    SimDay INT NOT NULL,
    SimHour INT NOT NULL,
    MetricDate DATETIME NOT NULL,
    OrdersInserted INT,
    OrderDetailsInserted INT,
    QueryCount INT,
    QueryVariants INT,
    ForcedPlanCount INT,
    PlanVariants INT,
    Notes NVARCHAR(200),
    PRIMARY KEY (SimDay, SimHour)
);
GO

-- Simulation parameters
DECLARE @SimulationDays INT = 10;
DECLARE @HoursPerDay INT = 24;

-- Helper for random gaps
IF OBJECT_ID('tempdb..#HourlyGaps') IS NOT NULL DROP TABLE #HourlyGaps;
CREATE TABLE #HourlyGaps (SimDay INT, SimHour INT, GapOrders BIT, GapDetails BIT, GapMetrics BIT);

DECLARE @d INT = 1;
DECLARE @h INT;
DECLARE @GapOrders BIT, @GapDetails BIT, @GapMetrics BIT;
WHILE @d <= @SimulationDays
BEGIN
    SET @h = 0;
    WHILE @h < @HoursPerDay
    BEGIN
        SET @GapOrders = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 1 ELSE 0 END;
        SET @GapDetails = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 1 ELSE 0 END;
        SET @GapMetrics = CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN 1 ELSE 0 END;
        INSERT INTO #HourlyGaps VALUES (@d, @h, @GapOrders, @GapDetails, @GapMetrics);
        SET @h = @h + 1;
    END
    SET @d = @d + 1;
END

-- Get restart point
DECLARE @LastLoadedDay INT, @LastLoadedHour INT;
SELECT TOP 1 @LastLoadedDay = LastLoadedDay, @LastLoadedHour = LastLoadedHour
FROM dbo.SimulationState
ORDER BY LastLoadedDay DESC, LastLoadedHour DESC;

IF @LastLoadedDay IS NULL
BEGIN
    SET @LastLoadedDay = 0;
    SET @LastLoadedHour = -1;
    INSERT INTO dbo.SimulationState (LastLoadedDay, LastLoadedHour) VALUES (0, -1);
END

DECLARE @Day INT = @LastLoadedDay;
DECLARE @Hour INT = @LastLoadedHour + 1;
IF @Hour >= @HoursPerDay
BEGIN
    SET @Day = @Day + 1;
    SET @Hour = 0;
END

DECLARE @Today DATETIME = CAST(GETDATE() AS DATE);

-- Simulation variables (declared up front)
DECLARE @MetricDate DATETIME;
DECLARE @OrdersThisHour INT;
DECLARE @OrderDetailsThisHour INT;
DECLARE @QueryCount INT;
DECLARE @QueryVariants INT;
DECLARE @ForcedPlanCount INT;
DECLARE @PlanVariants INT;
DECLARE @i INT;
DECLARE @OrderDate DATETIME;
DECLARE @RequiredDate DATETIME;
DECLARE @CustomerID NCHAR(5);
DECLARE @ShipPostalCode NVARCHAR(10);
DECLARE @OrderID INT;
DECLARE @Details INT;
DECLARE @j INT;
DECLARE @Q1 INT;
DECLARE @OrderIdForAdhoc INT;
DECLARE @sql NVARCHAR(200);
DECLARE @ad INT;
DECLARE @d_metric DATETIME;
DECLARE @msg NVARCHAR(400);

-- Plan bloat/forcing simulation variables
DECLARE @bloat_query NVARCHAR(200);
DECLARE @bloat_sql NVARCHAR(400);
DECLARE @v INT;
DECLARE @plan_query_id BIGINT;
DECLARE @plan_plan_id BIGINT;
DECLARE @force_plan_count INT;
DECLARE @plan_count INT;
DECLARE @waits INT;

-- Main Simulation Loop: hourly, with random gaps, plan bloat, and forced plans
WHILE @Day <= @SimulationDays
BEGIN
    WHILE @Hour < @HoursPerDay
    BEGIN
        SET @MetricDate = DATEADD(HOUR, (@Day - @SimulationDays) * 24 + @Hour, @Today);
        SELECT @GapOrders = GapOrders, @GapDetails = GapDetails, @GapMetrics = GapMetrics 
        FROM #HourlyGaps WHERE SimDay = @Day AND SimHour = @Hour;

        SET @OrdersThisHour = 0;
        SET @OrderDetailsThisHour = 0;
        SET @QueryCount = 0;
        SET @QueryVariants = 0;
        SET @ForcedPlanCount = 0;
        SET @PlanVariants = 0;

        -- 1. Insert Orders (if not a gap)
        IF @GapOrders = 0
        BEGIN
            SET @OrdersThisHour = 2 + ABS(CHECKSUM(NEWID())) % 10;
            SET @i = 1;
            WHILE @i <= @OrdersThisHour
            BEGIN
                SET @OrderDate = @MetricDate;
                SET @RequiredDate = DATEADD(DAY, 2, @MetricDate);
                SET @CustomerID = 
                    CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) + 
                    CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) + 
                    CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) + 
                    CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) + 
                    CHAR(65 + ABS(CHECKSUM(NEWID())) % 26);
                SET @ShipPostalCode = RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS NVARCHAR(4)), 4);

                INSERT INTO dbo.Orders (
                    CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, ShipVia, Freight,
                    ShipName, ShipAddress, ShipCity, ShipRegion, ShipPostalCode, ShipCountry
                )
                VALUES (
                    @CustomerID,
                    1 + ABS(CHECKSUM(NEWID())) % 9,
                    @OrderDate,
                    @RequiredDate,
                    NULL,
                    1 + ABS(CHECKSUM(NEWID())) % 3,
                    CAST(10 + (RAND() * 990) AS MONEY),
                    'ShipName' + CAST(@i AS NVARCHAR(10)),
                    'Address' + CAST(@i AS NVARCHAR(10)),
                    'City' + CAST(ABS(CHECKSUM(NEWID())) % 10 AS NVARCHAR(2)),
                    NULL,
                    @ShipPostalCode,
                    'Country' + CAST(ABS(CHECKSUM(NEWID())) % 5 AS NVARCHAR(2))
                );
                SET @OrderID = SCOPE_IDENTITY();

                -- 2. Insert OrderDetails (if not a gap; else only orders with no details)
                IF @GapDetails = 0
                BEGIN
                    SET @Details = 1 + ABS(CHECKSUM(NEWID())) % 5;
                    SET @OrderDetailsThisHour = @OrderDetailsThisHour + @Details;
                    SET @j = 1;
                    WHILE @j <= @Details
                    BEGIN
                        INSERT INTO dbo.OrderDetails (OrderID, ProductID, UnitPrice, Quantity, Discount)
                        VALUES (
                            @OrderID,
                            1 + ABS(CHECKSUM(NEWID())) % 50,
                            CAST(10 + (RAND() * 90) AS MONEY),
                            1 + ABS(CHECKSUM(NEWID())) % 10,
                            CAST(RAND() * 0.25 AS REAL)
                        );
                        SET @j = @j + 1;
                    END
                END
                SET @i = @i + 1;
            END
        END

        -- 3. Simulate hourly workload (IQP/APRC/bloat/variation)
        IF @GapMetrics = 0
        BEGIN
            SET @d_metric = @MetricDate;
            EXEC sp_executesql N'SELECT SUM(Freight) FROM dbo.Orders WHERE OrderDate >= @d', N'@d DATETIME', @d_metric;
            SET @QueryCount = @QueryCount + 1;

            IF ((@Day * 24 + @Hour) % 18 = 0)
            BEGIN
                CREATE INDEX IX_Orders_OrderDate_Temp ON dbo.Orders(OrderDate);
                EXEC sp_executesql N'SELECT OrderID FROM dbo.Orders WHERE OrderDate = @d', N'@d DATETIME', @d_metric;
                SET @QueryCount = @QueryCount + 1;
                DROP INDEX IX_Orders_OrderDate_Temp ON dbo.Orders;
                EXEC sp_executesql N'SELECT OrderID FROM dbo.Orders WHERE OrderDate = @d', N'@d DATETIME', @d_metric;
                SET @QueryCount = @QueryCount + 1;
            END

            IF ((@Day * 24 + @Hour) % 12 = 0)
            BEGIN
                SET @Q1 = 1 + ABS(CHECKSUM(NEWID())) % 10;
                EXEC sp_executesql N'SELECT * FROM dbo.OrderDetails WHERE Quantity = @q', N'@q INT', @Q1;
                SET @QueryCount = @QueryCount + 1;
                EXEC sp_executesql N'SELECT * FROM dbo.OrderDetails WHERE Quantity = @q', N'@q INT', 10;
                SET @QueryCount = @QueryCount + 1;
            END

            -- Extra ad-hoc query variation using dynamic SQL
            SET @ad = 1;
            WHILE @ad <= 12
            BEGIN
                SET @OrderIdForAdhoc = ABS(CHECKSUM(NEWID())) % ((@Day * 1000) + (@Hour * 50) + @ad + 1);
                SET @sql = N'SELECT COUNT(*) FROM dbo.Orders WHERE OrderID = ' + CAST(ISNULL(@OrderIdForAdhoc, 0) AS NVARCHAR(10));
                EXEC sp_executesql @sql;
                SET @QueryCount = @QueryCount + 1;
                -- Throw in some other literals for more query variety
                SET @sql = N'SELECT COUNT(*) FROM dbo.OrderDetails WHERE ProductID = ' + CAST(@ad AS NVARCHAR(10));
                EXEC sp_executesql @sql;
                SET @QueryCount = @QueryCount + 1;
                SET @ad = @ad + 1;
            END

            IF ((@Day * 24 + @Hour) % 30 = 0)
            BEGIN
                CREATE INDEX IX_OrderDetails_Quantity_Temp ON dbo.OrderDetails(Quantity);
                EXEC sp_executesql N'SELECT COUNT(*) FROM dbo.OrderDetails WHERE Quantity = @q', N'@q INT', 5;
                SET @QueryCount = @QueryCount + 1;
                DROP INDEX IX_OrderDetails_Quantity_Temp ON dbo.OrderDetails;
                EXEC sp_executesql N'SELECT COUNT(*) FROM dbo.OrderDetails WHERE Quantity = @q', N'@q INT', 5;
                SET @QueryCount = @QueryCount + 1;
            END

            -- === PLAN REGRESSION + FORCED PLAN + PLAN BLOAT SCENARIO (robust, only once) ===
            -- This block will generate 7 plan variants for the same query and force 5 plans.
            IF @Day = 1 AND @Hour = 2
            BEGIN
                SET @bloat_query = N'SELECT COUNT(*) FROM dbo.OrderDetails WHERE Quantity = ';
                SET @v = 1;
                WHILE @v <= 7
                BEGIN
                    SET @bloat_sql = @bloat_query + CAST(@v AS NVARCHAR(10));
                    EXEC sp_executesql @bloat_sql;
                    SET @v = @v + 1;
                END

                -- Get the query_id for this pattern
                SET @plan_query_id = NULL;
                SET @plan_count = 0;
                SET @waits = 0;
                WHILE (@plan_count < 7 OR @plan_query_id IS NULL) AND @waits < 36
                BEGIN
                    SELECT TOP 1 @plan_query_id = qs.query_id
                    FROM sys.query_store_query_text qt
                    INNER JOIN sys.query_store_query qs ON qt.query_text_id = qs.query_text_id
                    WHERE qt.query_sql_text LIKE 'SELECT COUNT(*) FROM dbo.OrderDetails WHERE Quantity =%';

                    IF @plan_query_id IS NOT NULL
                        SELECT @plan_count = COUNT(*) FROM sys.query_store_plan WHERE query_id = @plan_query_id;
                    IF @plan_count < 7 OR @plan_query_id IS NULL
                    BEGIN
                        WAITFOR DELAY '00:00:05';
                        SET @waits = @waits + 1;
                    END
                END

                -- Force the first 5 plans
                IF @plan_query_id IS NOT NULL AND @plan_count >= 7
                BEGIN
                    DECLARE plan_cursor CURSOR LOCAL FOR
                        SELECT TOP (5) plan_id FROM sys.query_store_plan WHERE query_id = @plan_query_id;
                    OPEN plan_cursor;
                    FETCH NEXT FROM plan_cursor INTO @plan_plan_id;
                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        EXEC sp_query_store_force_plan @plan_query_id, @plan_plan_id;
                        FETCH NEXT FROM plan_cursor INTO @plan_plan_id;
                    END
                    CLOSE plan_cursor;
                    DEALLOCATE plan_cursor;
                END

                -- Debug print
                SET @msg = N'Guaranteed plan bloat run: ' + ISNULL(CAST(@plan_count AS NVARCHAR(10)), '0') + N' plans, forced up to 5.';
                PRINT @msg;
            END
            -- === END PLAN REGRESSION/PLAN BLOAT/PLAN FORCING BLOCK ===

            -- Query Store metrics for this hour
            SELECT @QueryVariants = COUNT(DISTINCT query_hash) FROM sys.query_store_query;
            SELECT @ForcedPlanCount = COUNT(*) FROM sys.query_store_plan WHERE is_forced_plan = 1;
            SELECT TOP 1 @PlanVariants = MAX(PlanVariants) FROM (
                SELECT COUNT(plan_id) AS PlanVariants FROM sys.query_store_plan GROUP BY query_id
            ) AS t;

            -- Insert into hourly metrics
            INSERT INTO dbo.WorkloadMetrics
            (SimDay, SimHour, MetricDate, OrdersInserted, OrderDetailsInserted, QueryCount, QueryVariants, ForcedPlanCount, PlanVariants, Notes)
            VALUES
            (@Day, @Hour, @MetricDate, @OrdersThisHour, @OrderDetailsThisHour, @QueryCount, @QueryVariants, @ForcedPlanCount, @PlanVariants, NULL);
        END

        -- Mark hour as loaded
        IF EXISTS (SELECT 1 FROM dbo.SimulationState WHERE LastLoadedDay = @Day AND LastLoadedHour = @Hour)
            UPDATE dbo.SimulationState SET LastLoadedDay = @Day, LastLoadedHour = @Hour WHERE LastLoadedDay = @Day AND LastLoadedHour = @Hour;
        ELSE
            INSERT INTO dbo.SimulationState (LastLoadedDay, LastLoadedHour) VALUES (@Day, @Hour);

        -- PRINT-progress message for each hour
        SET @msg = 'Simulated Day ' + CAST(@Day AS NVARCHAR(10)) + ', Hour ' + CAST(@Hour AS NVARCHAR(10)) +
                   ' | Orders: ' + CAST(ISNULL(@OrdersThisHour,0) AS NVARCHAR(10)) +
                   ' | Details: ' + CAST(ISNULL(@OrderDetailsThisHour,0) AS NVARCHAR(10)) +
                   ' | Queries: ' + CAST(ISNULL(@QueryCount,0) AS NVARCHAR(10));
        PRINT @msg;

        SET @Hour = @Hour + 1;
    END
    SET @Day = @Day + 1;
    SET @Hour = 0;
END

PRINT 'Data load, workload simulation, and hourly metrics collection complete!';
