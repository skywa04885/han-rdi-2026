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
     DriverSeason
         AS (SELECT Driver.DriverId
                  , Race.RaceYear
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
                      INNER JOIN Driver ON Driver.DriverId = Result.DriverId
             GROUP BY Driver.DriverId, Race.RaceYear),
     PeriodStart
         AS (SELECT DriverId
                  , RaceYear
                  , LAG(RaceYear) OVER (PARTITION BY DriverId ORDER BY RaceYear) AS PrevYear
             FROM DriverSeason),
     PeriodGroup
         AS (SELECT DriverId
                  , RaceYear
                  , PrevYear
                  , SUM(IIF(PrevYear IS NULL OR RaceYear > PrevYear + 1, 1, 0))
                        OVER (PARTITION BY DriverId ORDER BY RaceYear) AS PeriodNr
             FROM PeriodStart),
     PeriodBound
         AS (SELECT DriverId
                  , PeriodNr
                  , MIN(RaceYear) AS StartYear
                  , MAX(RaceYear) AS EndYear
             FROM PeriodGroup
             GROUP BY DriverId, PeriodNr),
     ReturningDriver
         AS (SELECT DriverId
             FROM PeriodBound
             GROUP BY DriverId
             HAVING COUNT(*) > 1),
     FormattedPeriod
         AS (SELECT PeriodBound.DriverId
                  , IIF(StartYear = EndYear, CAST(StartYear AS NVARCHAR(4)),
                        CAST(StartYear AS NVARCHAR(4)) + N'–' + CAST(EndYear AS NVARCHAR(4))) AS Period
             FROM PeriodBound
                      INNER JOIN ReturningDriver ON ReturningDriver.DriverId = PeriodBound.DriverId
             ORDER BY EndYear
             OFFSET 0 ROWS),
     MergedFormattedPeriod
         AS (SELECT STRING_AGG(FormattedPeriod.Period, ', ') AS Period, FormattedPeriod.DriverId AS DriverId
             FROM FormattedPeriod
             GROUP BY FormattedPeriod.DriverId)
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                                  AS Driver
     , MergedFormattedPeriod.Period                                                       AS Seasons
     , DriverEntry.Entries                                                                AS Entries
     , DriverWin.Wins                                                                     AS Wins
     , CONCAT(ROUND((CAST(DriverWin.Wins AS FLOAT) / DriverEntry.Entries) * 100, 2), '%') AS Percentage
FROM Driver
         INNER JOIN DriverEntry ON DriverEntry.DriverId = Driver.DriverId
         INNER JOIN DriverWin ON DriverWin.DriverId = Driver.DriverId
         LEFT JOIN MergedFormattedPeriod ON MergedFormattedPeriod.DriverId = Driver.DriverId
WHERE DriverWin.Wins >= 25
ORDER BY DriverWin.Wins DESC;

-- Option 2
SELECT DISTINCT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                                    AS Driver
              , InnerResult.Entries                                                                  AS Entries
              , InnerResult.Wins                                                                     AS Wins
              , CONCAT(ROUND((CAST(InnerResult.Wins AS FLOAT) / InnerResult.Entries) * 100, 2), '%') AS Percentage
FROM Result
         CROSS APPLY (SELECT COUNT(*) OVER (PARTITION BY InnerResult.DriverId) AS Entries
                           , COUNT(CASE WHEN InnerResult.Position = 1 THEN 1 END)
                                   OVER (PARTITION BY InnerResult.DriverId)    AS Wins
                      FROM Result AS InnerResult
                      WHERE InnerResult.DriverId = Result.DriverId) AS InnerResult
         INNER JOIN Driver ON Driver.DriverId = Result.DriverId
WHERE InnerResult.Wins >= 25