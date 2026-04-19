-- Option 1
WITH DriverSeasons
         AS (SELECT Driver.DriverId
                  , CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS DriverName
                  , Race.RaceYear
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
                      INNER JOIN Driver ON Driver.DriverId = Result.DriverId
             GROUP BY Driver.DriverId, Driver.Firstname, Driver.Lastname, Race.RaceYear),
     PeriodStarts
         AS (SELECT DriverId
                  , DriverName
                  , RaceYear
                  , LAG(RaceYear) OVER (PARTITION BY DriverId ORDER BY RaceYear) AS PrevYear
             FROM DriverSeasons),
     PeriodGroups
         AS (SELECT DriverId
                  , DriverName
                  , RaceYear
                  , PrevYear
                  , SUM(IIF(PrevYear IS NULL OR RaceYear > PrevYear + 1, 1, 0))
                        OVER (PARTITION BY DriverId ORDER BY RaceYear) AS PeriodNr
             FROM PeriodStarts),
     PeriodBounds
         AS (SELECT DriverId
                  , DriverName
                  , PeriodNr
                  , MIN(RaceYear) AS StartYear
                  , MAX(RaceYear) AS EndYear
             FROM PeriodGroups
             GROUP BY DriverId, DriverName, PeriodNr),
     ReturningDrivers
         AS (SELECT DriverId
             FROM PeriodBounds
             GROUP BY DriverId
             HAVING COUNT(*) > 1),
     FormattedPeriods
         AS (SELECT PeriodBounds.DriverId
                  , PeriodBounds.DriverName
                  , PeriodBounds.PeriodNr
                  , IIF(StartYear = EndYear, CAST(StartYear AS NVARCHAR(4)),
                        CAST(StartYear AS NVARCHAR(4)) + N'–' + CAST(EndYear AS NVARCHAR(4))) AS Period
             FROM PeriodBounds
                      INNER JOIN ReturningDrivers ON ReturningDrivers.DriverId = PeriodBounds.DriverId)

SELECT DriverName                                                AS Coureur
     , STRING_AGG(Period, ', ') WITHIN GROUP (ORDER BY PeriodNr) AS Periodes
FROM FormattedPeriods
GROUP BY DriverId, DriverName
ORDER BY DriverName;

-- Option 2
WITH DriverYears
         AS (SELECT DISTINCT Driver.DriverId
                           , CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS DriverName
                           , Race.RaceYear
             FROM Driver
                      INNER JOIN Result ON Driver.DriverId = Result.DriverId
                      INNER fcJOIN Race ON Result.RaceId = Race.RaceId),
     RecursivePeriods
         AS (SELECT DriverYears.DriverId
                  , DriverYears.DriverName
                  , DriverYears.RaceYear AS StartYear
                  , DriverYears.RaceYear AS CurrentYear
             FROM DriverYears
             WHERE NOT EXISTS (SELECT 1
                               FROM DriverYears AS DriverYears2
                               WHERE DriverYears2.DriverId = DriverYears.DriverId
                                 AND DriverYears2.RaceYear = DriverYears.RaceYear - 1)
             UNION ALL
             SELECT RecursivePeriods.DriverId
                  , RecursivePeriods.DriverName
                  , RecursivePeriods.StartYear
                  , DriverYears.RaceYear
             FROM RecursivePeriods
                      INNER JOIN DriverYears
                                 ON DriverYears.DriverId = RecursivePeriods.DriverId
                                     AND DriverYears.RaceYear = RecursivePeriods.CurrentYear + 1),
     CompletedPeriods
         AS (SELECT DriverId
                  , DriverName
                  , StartYear
                  , CurrentYear AS EndYear
             FROM RecursivePeriods
             WHERE NOT EXISTS (SELECT 1
                               FROM DriverYears
                               WHERE DriverYears.DriverId = RecursivePeriods.DriverId
                                 AND DriverYears.RaceYear = RecursivePeriods.CurrentYear + 1)),
     ReturningDrivers
         AS (SELECT *
             FROM CompletedPeriods
             WHERE DriverId IN (SELECT DriverId
                                FROM CompletedPeriods
                                GROUP BY DriverId
                                HAVING COUNT(*) > 1))
SELECT DriverName,
       STRING_AGG(CAST(StartYear AS nvarchar) + N'–' + CAST(EndYear AS nvarchar), ', ')
                  WITHIN GROUP (ORDER BY StartYear) AS Periodes
FROM ReturningDrivers
GROUP BY DriverId, DriverName
ORDER BY DriverName;