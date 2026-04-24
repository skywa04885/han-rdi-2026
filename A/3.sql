-- Option 1
WITH SeasonWinner
         AS (SELECT Race.RaceYear
                  , DriverStanding.DriverId
                  , CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS DriverName
             FROM DriverStanding
                      INNER JOIN Race ON Race.RaceId = DriverStanding.RaceId
                      INNER JOIN Driver ON Driver.DriverId = DriverStanding.DriverId
             WHERE DriverStanding.Position = 1
               AND Race.RaceYear BETWEEN 2015 AND 2024
               AND Race.NrOfRound =
                   (SELECT MAX(Race2.NrOfRound) FROM Race Race2 WHERE Race2.RaceYear = Race.RaceYear)),
     ChampStandings
         AS (SELECT Race.RaceYear
                  , Race.RaceId
                  , Race.RaceDate
                  , Race.NrOfRound
                  , Race.RaceName
                  , DriverStanding.Position                                                AS StandPos
                  , ROW_NUMBER() OVER (PARTITION BY Race.RaceYear ORDER BY Race.NrOfRound) AS Seq
             FROM DriverStanding
                      INNER JOIN Race ON Race.RaceId = DriverStanding.RaceId
                      INNER JOIN SeasonWinner ON SeasonWinner.DriverId = DriverStanding.DriverId AND
                                                 SeasonWinner.RaceYear = Race.RaceYear),
     FirstUnbrokenP1
         AS (SELECT RaceYear
                  , MIN(CASE WHEN StandPos = 1 THEN Seq END) AS FirstSeq
             FROM ChampStandings
             WHERE Seq > COALESCE((SELECT MAX(ChampStandings2.Seq)
                                   FROM ChampStandings AS ChampStandings2
                                   WHERE ChampStandings2.RaceYear = ChampStandings.RaceYear
                                     AND ChampStandings2.StandPos > 1), 0)
             GROUP BY RaceYear),
     SeasonTotals
         AS (SELECT RaceYear
                  , COUNT(*) AS TotaalRaces
             FROM Race
             WHERE RaceYear BETWEEN 2015 AND 2024
             GROUP BY RaceYear),
     ChampWins
         AS (SELECT Race.RaceYear
                  , COUNT(*) AS RaceWins
             FROM Result
                      INNER JOIN Race ON Race.RaceId = Result.RaceId
                      INNER JOIN SeasonWinner
                                 ON SeasonWinner.DriverId = Result.DriverId AND
                                    SeasonWinner.RaceYear = Race.RaceYear
             WHERE Result.Position = 1
             GROUP BY Race.RaceYear)

SELECT SeasonWinner.RaceYear    AS Seizoen
     , SeasonWinner.DriverName  AS Kampioen
     , ChampWins.RaceWins       AS RaceWins
     , SeasonTotals.TotaalRaces AS TotaalRaces
     , ChampStandings.RaceDate  AS LeiderVanaf
     , ChampStandings.NrOfRound AS Volgnummer
     , ChampStandings.RaceName  AS Race
FROM SeasonWinner
         JOIN ChampWins ON ChampWins.RaceYear = SeasonWinner.RaceYear
         JOIN SeasonTotals ON SeasonTotals.RaceYear = SeasonWinner.RaceYear
         JOIN FirstUnbrokenP1 ON FirstUnbrokenP1.RaceYear = SeasonWinner.RaceYear
         JOIN ChampStandings
              ON ChampStandings.RaceYear = SeasonWinner.RaceYear AND ChampStandings.Seq = FirstUnbrokenP1.FirstSeq
ORDER BY SeasonWinner.RaceYear;

-- Option 2
WITH SeasonWinner
         AS (SELECT Race.RaceYear
                  , DriverStanding.DriverId
                  , CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS DriverName
             FROM DriverStanding
                      INNER JOIN Race ON Race.RaceId = DriverStanding.RaceId
                      INNER JOIN Driver ON Driver.DriverId = DriverStanding.DriverId
             WHERE DriverStanding.Position = 1
               AND Race.RaceYear BETWEEN 2015 AND 2024
               AND Race.NrOfRound =
                   (SELECT MAX(Race2.NrOfRound)
                    FROM Race Race2
                    WHERE Race2.RaceYear = Race.RaceYear))

SELECT SeasonWinner.RaceYear     AS Seizoen
     , SeasonWinner.DriverName   AS Kampioen
     , RaceWins.RaceWins         AS RaceWins
     , SeasonTotals.TotaalRaces  AS TotaalRaces
     , FirstUnbrokenP1.RaceDate  AS LeiderVanaf
     , FirstUnbrokenP1.NrOfRound AS Volgnummer
     , FirstUnbrokenP1.RaceName  AS Race
FROM SeasonWinner
         CROSS APPLY (SELECT COUNT(*) AS TotaalRaces
                      FROM Race
                      WHERE Race.RaceYear = SeasonWinner.RaceYear) AS SeasonTotals
         CROSS APPLY (SELECT COUNT(*) AS RaceWins
                      FROM Result
                               INNER JOIN Race ON Race.RaceId = Result.RaceId
                      WHERE Result.DriverId = SeasonWinner.DriverId
                        AND Race.RaceYear = SeasonWinner.RaceYear
                        AND Result.Position = 1) AS RaceWins
         CROSS APPLY (SELECT TOP 1 Race.RaceDate
                                 , Race.NrOfRound
                                 , Race.RaceName
                      FROM DriverStanding
                               INNER JOIN Race ON Race.RaceId = DriverStanding.RaceId
                      WHERE DriverStanding.DriverId = SeasonWinner.DriverId
                        AND Race.RaceYear = SeasonWinner.RaceYear
                        AND DriverStanding.Position = 1
                        AND NOT EXISTS (SELECT 1
                                        FROM DriverStanding DS2
                                                 INNER JOIN Race Race2 ON Race2.RaceId = DS2.RaceId
                                        WHERE DS2.DriverId = SeasonWinner.DriverId
                                          AND Race2.RaceYear = SeasonWinner.RaceYear
                                          AND DS2.Position > 1
                                          AND Race2.NrOfRound > Race.NrOfRound)
                      ORDER BY Race.NrOfRound) AS FirstUnbrokenP1
ORDER BY SeasonWinner.RaceYear;