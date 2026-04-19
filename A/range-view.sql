-- Create the view containing all the driver year ranges.
CREATE OR ALTER VIEW DriverYearRanges AS
WITH DriverYear
         AS (SELECT DISTINCT Result.DriverId AS DriverId
                           , Race.RaceYear   AS RaceYear
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
             ORDER BY DriverId, RaceYear
             OFFSET 0 ROWS),
     DriverYearGroup
         AS (SELECT DriverYear.DriverId AS DriverId
                  , DriverYear.RaceYear AS RaceYear
                  , (IIF(
                 LAG(DriverYear.RaceYear) OVER (PARTITION BY DriverYear.DriverId ORDER BY DriverYear.RaceYear) + 1 =
                 DriverYear.RaceYear, 0,
                 1))                    AS NewGroup
             FROM DriverYear),
     DriverYearIsland
         AS (SELECT DriverYearGroup.RaceYear                                                                        AS RaceYear
                  , DriverYearGroup.DriverId                                                                        AS DriverId
                  , SUM(DriverYearGroup.NewGroup)
                        OVER (ORDER BY DriverYearGroup.DriverId, DriverYearGroup.RaceYear ROWS UNBOUNDED PRECEDING) AS Grp
             FROM DriverYearGroup),
     DriverYearRange
         AS (SELECT DriverYearIsland.DriverId                                                           AS DriverId
                  , IIF(MIN(DriverYearIsland.RaceYear) = MAX(DriverYearIsland.RaceYear),
                        CAST(MIN(DriverYearIsland.RaceYear) AS VARCHAR),
                        CONCAT_WS('-', MIN(DriverYearIsland.RaceYear), MAX(DriverYearIsland.RaceYear))) AS Range
                  , MIN(DriverYearIsland.RaceYear)                                                      AS FromYear
                  , MAX(DriverYearIsland.RaceYear)                                                      AS ToYear
             FROM DriverYearIsland
             GROUP BY DriverYearIsland.DriverId, DriverYearIsland.Grp
             ORDER BY DriverId, ToYear
             OFFSET 0 ROWS)
SELECT DriverYearRange.DriverId                AS DriverId
     , STRING_AGG(DriverYearRange.Range, ', ') AS Ranges
FROM DriverYearRange
GROUP BY DriverYearRange.DriverId;