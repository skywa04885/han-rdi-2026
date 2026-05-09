-- Option 1
WITH DriverWins AS (SELECT Result.DriverId AS DriverId
                         , Race.RaceYear   AS RaceYear
                         , COUNT(1)        AS Wins
                    FROM Result
                             INNER JOIN Race ON Race.RaceId = Result.RaceId
                    WHERE Result.Position = 1
                    GROUP BY Result.DriverId, Race.RaceYear),
     DriverRaces AS (SELECT Result.DriverId AS DriverId
                          , Race.RaceYear   AS RaceYear
                          , COUNT(1)        AS Races
                     FROM Result
                              INNER JOIN Race ON Race.RaceId = Result.RaceId
                     GROUP BY Result.DriverId, Race.RaceYear)
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS Driver
     , DriverRaces.RaceYear                              AS Season
     , DriverRaces.Races                                 AS Races
     , COALESCE(DriverWins.Wins, 0)                      AS Wins
     , CONCAT(CAST(ROUND(100.0 * COALESCE(DriverWins.Wins, 0) / NULLIF(DriverRaces.Races, 0), 2) AS DECIMAL(10, 2)),
              '%')                                       AS Percentage
FROM DriverRaces
         INNER JOIN Driver ON Driver.DriverId = DriverRaces.DriverId
         LEFT JOIN DriverWins
                   ON DriverWins.DriverId = DriverRaces.DriverId
                       AND DriverWins.RaceYear = DriverRaces.RaceYear
ORDER BY COALESCE(DriverWins.Wins, 0) * 1.0 / DriverRaces.Races DESC;

-- Option 2
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS Driver
     , Race.RaceYear                                     AS Season
     , COUNT(1)                                          AS Races
     , SUM(IIF(Result.Position = 1, 1, 0))               AS Wins
     , CONCAT(CAST(ROUND(100.0 * SUM(IIF(Result.Position = 1, 1, 0)) / NULLIF(COUNT(*), 0), 2) AS DECIMAL(10, 2)),
              '%')                                       AS Percentage
FROM Result
         INNER JOIN Race ON Race.RaceId = Result.RaceId
         INNER JOIN Driver ON Driver.DriverId = Result.DriverId
GROUP BY Driver.DriverId, Driver.Firstname, Driver.Lastname, Race.RaceYear
ORDER BY SUM(IIF(Result.Position = 1, 1, 0)) * 1.0 / COUNT(1) DESC;

-- Option 3
SELECT CONCAT_WS(' ', d.Firstname, d.Lastname)                          AS Driver
     , dr.RaceYear                                                      AS Season
     , ss.Races                                                         AS Races
     , ss.Wins                                                          AS Wins
     , CONCAT(CAST(ROUND(100.0 * ss.Wins / NULLIF(ss.Races, 0), 2)
                  AS DECIMAL(10, 2)), '%')                              AS Percentage
FROM (SELECT DISTINCT Result.DriverId, Race.RaceYear
      FROM Result
               INNER JOIN Race ON Race.RaceId = Result.RaceId) dr
         CROSS APPLY (SELECT COUNT(*)                                                AS Races
                           , SUM(CASE WHEN res.Position = 1 THEN 1 ELSE 0 END)       AS Wins
                      FROM Result res
                               INNER JOIN Race r ON r.RaceId = res.RaceId
                      WHERE res.DriverId = dr.DriverId
                        AND r.RaceYear = dr.RaceYear) ss
         INNER JOIN Driver d ON d.DriverId = dr.DriverId
ORDER BY ss.Wins * 1.0 / ss.Races DESC;
