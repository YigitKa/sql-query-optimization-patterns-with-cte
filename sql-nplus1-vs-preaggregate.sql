/* ===============================
  BATCH 1 — DB ve Şema
=================================*/
IF DB_ID(N'Demo_SqlPattern_90') IS NOT NULL
BEGIN
  ALTER DATABASE Demo_SqlPattern_90 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE Demo_SqlPattern_90;
END;
GO
CREATE DATABASE Demo_SqlPattern_90;
GO
USE Demo_SqlPattern_90;
GO

ALTER DATABASE CURRENT SET RECOVERY BULK_LOGGED;

IF OBJECT_ID('dbo.Users','U') IS NOT NULL DROP TABLE dbo.Users;
CREATE TABLE dbo.Users(
    id          INT           NOT NULL PRIMARY KEY CLUSTERED,
    name        NVARCHAR(100) NOT NULL,
    signup_date DATE          NOT NULL
);

IF OBJECT_ID('dbo.Orders','U') IS NOT NULL DROP TABLE dbo.Orders;
CREATE TABLE dbo.Orders(
    id       BIGINT        NOT NULL PRIMARY KEY CLUSTERED,
    user_id  INT           NOT NULL,
    status   VARCHAR(20)   NOT NULL,
    amount   DECIMAL(12,2) NOT NULL,
    order_ts DATETIME2(3)  NOT NULL,
    CONSTRAINT FK_Orders_Users FOREIGN KEY (user_id) REFERENCES dbo.Users(id)
);

CREATE INDEX IX_Orders_User_Status ON dbo.Orders(user_id, status) INCLUDE (amount);
GO


/* ===============================
  BATCH 2 — Veri üretimi + A/B ölçüm
  (Değişkenler burada!)
=================================*/
USE Demo_SqlPattern_90;
GO
SET NOCOUNT ON;

DECLARE @Users       INT     = 100000;      -- Güce göre düşürebilirsin (örn. 20000)
DECLARE @Orders      BIGINT  = 8000000;     -- Güce göre düşürebilirsin (örn. 1000000)
DECLARE @OrdersChunk BIGINT  = 1000000;     -- Parça parça insert
DECLARE @inserted    BIGINT  = 0;

;WITH N AS (
  SELECT TOP (@Users) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
  FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT dbo.Users(id, name, signup_date)
SELECT rn, CONCAT(N'User ', rn),
       DATEADD(DAY, (rn % 365), DATEFROMPARTS(2023,1,1))
FROM N;

WHILE (@inserted < @Orders)
BEGIN
    DECLARE @take BIGINT = IIF(@Orders - @inserted >= @OrdersChunk, @OrdersChunk, @Orders - @inserted);

    ;WITH S AS (
        SELECT TOP (@take)
               @inserted + ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rid
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    )
    INSERT dbo.Orders(id, user_id, status, amount, order_ts)
    SELECT rid,
           ((ABS(CHECKSUM(NEWID())) % @Users) + 1),
           CASE WHEN ABS(CHECKSUM(NEWID())) % 3 = 0 THEN 'pending' ELSE 'completed' END,
           CAST((ABS(CHECKSUM(NEWID())) % 50000)/100.0 + 1.00 AS DECIMAL(12,2)),
           DATEADD(SECOND, rid % 86400, '2023-01-01')
    FROM S;

    SET @inserted += @take;
    PRINT CONCAT('Inserted orders: ', @inserted, ' / ', @Orders);
END;

UPDATE STATISTICS dbo.Users WITH FULLSCAN;
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;

-- Ölçüm
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- SSMS: Include Actual Execution Plan (Ctrl+M)

PRINT '--- Versiyon A: N+1 Alt Sorgu ---';
SELECT 
  u.id AS user_id,
  u.name,
  (SELECT COUNT(*)
   FROM dbo.Orders o
   WHERE o.user_id = u.id AND o.status = 'completed') AS completed_orders,
  (SELECT SUM(o.amount)
   FROM dbo.Orders o
   WHERE o.user_id = u.id AND o.status = 'completed') AS total_spent
FROM dbo.Users u
WHERE u.signup_date >= '2023-01-01';

PRINT '--- Versiyon B: Pre-Aggregate + JOIN ---';
;WITH order_summary AS (
  SELECT user_id,
         COUNT(*)      AS completed_orders,
         SUM(amount)   AS total_spent
  FROM dbo.Orders
  WHERE status = 'completed'
  GROUP BY user_id
)
SELECT u.id AS user_id,
       u.name,
       COALESCE(os.completed_orders, 0) AS completed_orders,
       COALESCE(os.total_spent, 0.00)   AS total_spent
FROM dbo.Users u
LEFT JOIN order_summary os
  ON u.id = os.user_id
WHERE u.signup_date >= '2023-01-01';
GO


/* ===============================
  BATCH 3 — Indexed View + C ölçüm
  (CREATE VIEW tek batch kuralı)
=================================*/
USE Demo_SqlPattern_90;
GO

IF OBJECT_ID('dbo.vw_OrderSummary','V') IS NOT NULL DROP VIEW dbo.vw_OrderSummary;
GO
CREATE VIEW dbo.vw_OrderSummary
WITH SCHEMABINDING
AS
SELECT 
    o.user_id,
    COUNT_BIG(*)                                                   AS order_count,
    SUM(CASE WHEN o.status='completed' THEN o.amount ELSE 0 END)  AS total_spent_completed
FROM dbo.Orders AS o
GROUP BY o.user_id;
GO
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='IXC_vw_OrderSummary' AND object_id = OBJECT_ID('dbo.vw_OrderSummary'))
    DROP INDEX IXC_vw_OrderSummary ON dbo.vw_OrderSummary;
GO
CREATE UNIQUE CLUSTERED INDEX IXC_vw_OrderSummary ON dbo.vw_OrderSummary(user_id);
GO

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

PRINT '--- Versiyon C: Indexed View (NOEXPAND) ---';
SELECT 
  u.id AS user_id,
  u.name,
  COALESCE(v.order_count,0)             AS completed_orders,
  COALESCE(v.total_spent_completed,0.0) AS total_spent
FROM dbo.Users u
LEFT JOIN dbo.vw_OrderSummary v WITH (NOEXPAND)
  ON u.id = v.user_id
WHERE u.signup_date >= '2023-01-01';
GO
