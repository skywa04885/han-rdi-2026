-- Option 1
WITH DriverEntry
         AS (SELECT COUNT(1)        AS Entries
                  , Result.DriverId AS DriverId
             FROM Driver
                      INNER JOIN Result ON Result.DriverId = Driver.DriverId
             GROUP BY Result.DriverId),
     DriverWin
         AS (SELECT COUNT(1)        AS Wins
                  , Result.DriverId AS DriverId
             FROM Driver
                      INNER JOIN Result ON Result.DriverId = Driver.DriverId
             WHERE Result.Position = 1
             GROUP BY Result.DriverId),
     -- Select all the years the drivers took part in.
     DriverYear
         AS (SELECT DISTINCT Result.DriverId AS DriverId
                           , Race.RaceYear   AS RaceYear
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
             ORDER BY DriverId, RaceYear
             OFFSET 0 ROWS),
     -- Determine the groups of years.
     [Group]
         AS (SELECT DriverYear.DriverId AS DriverId
                  , DriverYear.RaceYear AS RaceYear
                  , (IIF(
                 LAG(DriverYear.RaceYear) OVER (PARTITION BY DriverYear.DriverId ORDER BY DriverYear.RaceYear) + 1 =
                 DriverYear.RaceYear, 0,
                 1))                    AS NewGroup
             FROM DriverYear),
     -- Determine the islands based on te groups.
     Island
         AS (SELECT [Group].RaceYear                                                                AS RaceYear
                  , [Group].DriverId                                                                AS DriverId
                  , SUM([Group].NewGroup)
                        OVER (ORDER BY [Group].DriverId, [Group].RaceYear ROWS UNBOUNDED PRECEDING) AS Grp
             FROM [Group]),
     -- Determine the ranges based on the islands.
     Range
         AS (SELECT Island.DriverId                                                 AS DriverId
                  , IIF(MIN(Island.RaceYear) = MAX(Island.RaceYear), CAST(MIN(Island.RaceYear) AS VARCHAR),
                        CONCAT_WS('-', MIN(Island.RaceYear), MAX(Island.RaceYear))) AS Range
                  , MIN(Island.RaceYear)                                            AS FromYear
                  , MAX(Island.RaceYear)                                            AS ToYear
             FROM Island
             GROUP BY Island.DriverId, Island.Grp
             ORDER BY DriverId, ToYear
             OFFSET 0 ROWS),
     -- Merge the ranges.
     MergedRange
         AS (SELECT Range.DriverId                AS DriverId
                  , STRING_AGG(Range.Range, ', ') AS Ranges
             FROM Range
             GROUP BY Range.DriverId)
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                                  AS Driver
     , MergedRange.Ranges                                                                 AS Seasons
     , DriverEntry.Entries                                                                AS Entries
     , DriverWin.Wins                                                                     AS Wins
     , CONCAT(ROUND((CAST(DriverWin.Wins AS FLOAT) / DriverEntry.Entries) * 100, 2), '%') AS Percentage
FROM Driver
         INNER JOIN DriverEntry ON DriverEntry.DriverId = Driver.DriverId
         INNER JOIN DriverWin ON DriverWin.DriverId = Driver.DriverId
         LEFT JOIN MergedRange ON MergedRange.DriverId = Driver.DriverId
WHERE DriverWin.Wins >= 25
ORDER BY DriverWin.Wins DESC;

-- Option 2

WITH -- Select all the years the drivers took part in.
     DriverYear
         AS (SELECT DISTINCT Result.DriverId AS DriverId
                           , Race.RaceYear   AS RaceYear
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
             ORDER BY DriverId, RaceYear
             OFFSET 0 ROWS),
     -- Determine the groups of years.
     [Group]
         AS (SELECT DriverYear.DriverId AS DriverId
                  , DriverYear.RaceYear AS RaceYear
                  , (IIF(
                 LAG(DriverYear.RaceYear) OVER (PARTITION BY DriverYear.DriverId ORDER BY DriverYear.RaceYear) + 1 =
                 DriverYear.RaceYear, 0,
                 1))                    AS NewGroup
             FROM DriverYear),
     -- Determine the islands based on te groups.
     Island
         AS (SELECT [Group].RaceYear                                                                AS RaceYear
                  , [Group].DriverId                                                                AS DriverId
                  , SUM([Group].NewGroup)
                        OVER (ORDER BY [Group].DriverId, [Group].RaceYear ROWS UNBOUNDED PRECEDING) AS Grp
             FROM [Group]),
     -- Determine the ranges based on the islands.
     Range
         AS (SELECT Island.DriverId                                                 AS DriverId
                  , IIF(MIN(Island.RaceYear) = MAX(Island.RaceYear), CAST(MIN(Island.RaceYear) AS VARCHAR),
                        CONCAT_WS('-', MIN(Island.RaceYear), MAX(Island.RaceYear))) AS Range
                  , MIN(Island.RaceYear)                                            AS FromYear
                  , MAX(Island.RaceYear)                                            AS ToYear
             FROM Island
             GROUP BY Island.DriverId, Island.Grp
             ORDER BY DriverId, ToYear
             OFFSET 0 ROWS),
     -- Merge the ranges.
     MergedRange
         AS (SELECT Range.DriverId                AS DriverId
                  , STRING_AGG(Range.Range, ', ') AS Ranges
             FROM Range
             GROUP BY Range.DriverId)
SELECT DISTINCT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                          AS Driver
              , MergedRange.Ranges                                                         AS Seasons
              , Result.Entries                                                             AS Entries
              , Result.Wins                                                                AS Wins
              , CONCAT(ROUND((CAST(Result.Wins AS FLOAT) / Result.Entries) * 100, 2), '%') AS Percentage
FROM Driver
         -- Calculate the number of entries and wins for each driver.
         CROSS APPLY (SELECT COUNT(*) OVER (PARTITION BY Result.DriverId) AS Entries
                           , COUNT(CASE WHEN Result.Position = 1 THEN 1 END)
                                   OVER (PARTITION BY Result.DriverId)    AS Wins
                      FROM Result
                      WHERE Result.DriverId = Driver.DriverId) AS Result
-- Join the merged ranges.
         INNER JOIN MergedRange ON MergedRange.DriverId = Driver.DriverId
WHERE Result.Wins >= 25;