# A. Bevragingen

## A.1. Welke coureurs zijn in alle races van het seizoen 2024 ge-finished?

### A.1.1. Primaire Uitwerking

#### A.1.1.1. Query

```sql
WITH
    -- The total amount of (inferred) laps for each race in the season of 2024.
    RaceLaps AS (SELECT Race.RaceId      AS RaceId
                      , MAX(Result.Laps) AS Laps
                 FROM Result
                          INNER JOIN Race ON Race.RaceId = Result.RaceId
                 WHERE Race.RaceYear = 2024
                 GROUP BY Race.RaceId),
    -- The amount of laps each driver has completed in each 2024 race.
    DriverLaps AS (SELECT Result.DriverId AS DriverId
                        , Result.RaceId   AS RaceId
                        , Result.Laps     AS Laps
                   FROM Driver
                            INNER JOIN Result ON Result.DriverId = Driver.DriverId
                            INNER JOIN Race ON Race.RaceId = Result.RaceId
                   WHERE Race.RaceYear = 2024),
    -- The amount by which each driver has completed each race (in the range of 0 to 1).
    RaceCompletion AS (SELECT DriverLaps.DriverId                                             AS DriverId
                            , DriverLaps.RaceId                                               AS RaceId
                            , (CAST(DriverLaps.Laps AS FLOAT) / CAST(RaceLaps.Laps AS FLOAT)) AS Completion
                       FROM DriverLaps
                                INNER JOIN RaceLaps ON RaceLaps.RaceId = DriverLaps.RaceId),
    -- The lowest observed completion in all races for each driver.
    MinCompletion AS (SELECT RaceCompletion.DriverId        AS DriverId
                           , MIN(RaceCompletion.Completion) AS MinCompletion
                      FROM RaceCompletion
                      GROUP BY RaceCompletion.DriverId)
-- Select the drivers with (at least) 90% completion for all races, and show their names.
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                         AS Name
     , CONCAT(CAST(ROUND(MinCompletion.MinCompletion, 2) * 100 AS VARCHAR), '%') AS Completion
FROM MinCompletion
         INNER JOIN Driver ON Driver.DriverId = MinCompletion.DriverId
WHERE MinCompletion.MinCompletion >= 0.9
ORDER BY MinCompletion.MinCompletion DESC;
```

#### A.1.1.2. Resultaten

#### A.1.1.3. Toelichting

#### A.1.1.4. Query plan

#### A.1.1.5. Aanbevolen indexen

### A.1.2. Alternatieve Uitwerking

#### A.1.2.1. Query

```sql
WITH
    -- Determine the completion of each driver per race.
    RaceCompletion
        AS (SELECT CAST(Result.Laps AS FLOAT) / MAX(Result.Laps) OVER (PARTITION BY Race.RaceId) AS Completion
                 , Race.RaceId                                                                   AS RaceId
                 , Driver.DriverId                                                               AS DriverId
            FROM Driver
                     INNER JOIN Result ON Result.DriverId = Driver.DriverId
                     INNER JOIN Race ON Race.RaceId = Result.RaceId
            WHERE Race.RaceYear = 2024),
    -- Determine the completion per driver (in the minimum).
    DriverCompletion AS (SELECT MIN(RaceCompletion.Completion) AS MinCompletion
                              , RaceCompletion.DriverId        AS DriverId
                         FROM RaceCompletion
                         GROUP BY RaceCompletion.DriverId)
-- Select only the drivers that have at least 90% completion.
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                            AS Name
     , CONCAT(CAST(ROUND(DriverCompletion.MinCompletion, 2) * 100 AS VARCHAR), '%') AS Completion
FROM DriverCompletion
         INNER JOIN Driver ON Driver.DriverId = DriverCompletion.DriverId
WHERE DriverCompletion.MinCompletion >= 0.9
ORDER BY DriverCompletion.MinCompletion DESC;
```

#### A.1.2.2. Resultaten

#### A.1.2.3. Toelichting

#### A.1.2.4. Query plan

#### A.1.2.5. Aanbevolen indexen

## A.2. Van 2004 tot en met 2024: per race de snelste ronde met circuit, racedatum, coureur, rondenummer, rondetijd, positie, punten, totaal aantal rondes en resultstatus; gesorteerd op circuit en daarna op rondetijd.

### A.2.1. Primaire Uitwerking

#### A.2.1.1. Query

```sql
WITH FastestRaceResult
         AS (SELECT (SELECT TOP 1 Result.ResultId
                     FROM Result
                     WHERE Result.RaceId = Race.RaceId
                       AND Result.FastestLapTime IS NOT NULL
                     ORDER BY Result.FastestLapTime) AS FastestResultId
                  , Race.RaceId                      AS RaceId
             FROM Race
             WHERE Race.RaceYear BETWEEN 2004 AND 2024)
SELECT Circuit.CircuitName                               AS CircuitName
     , Race.RaceDate                                     AS RaceDate
     , CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS Name
     , Result.FastestLap                                 AS FastestLap
     , Result.FastestLapTime                             AS FastestLapTime
     , Result.PositionText                               AS Position
     , Result.Points                                     AS Points
     , Result.Laps                                       AS Laps
     , ResultStatus.ResultStatus                         AS ResultStatus
FROM FastestRaceResult
         INNER JOIN Race ON Race.RaceId = FastestRaceResult.RaceId
         INNER JOIN Result ON Result.ResultId = FastestRaceResult.FastestResultId
         INNER JOIN Driver ON Driver.DriverId = Result.DriverId
         INNER JOIN Circuit ON Circuit.CircuitId = Race.CircuitId
         INNER JOIN ResultStatus ON ResultStatus.ResultStatusId = Result.ResultStatusId
ORDER BY CircuitName, FastestLapTime;
```

#### A.2.1.2. Resultaten

#### A.2.1.3. Toelichting

#### A.2.1.4. Query plan

#### A.2.1.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

### A.2.2. Alternatieve Uitwerking

#### A.2.2.1. Query

```sql
WITH RankedResults
         AS (SELECT r.RaceId
                  , res.ResultId
                  , res.DriverId
                  , res.FastestLap
                  , res.FastestLapTime
                  , res.PositionText
                  , res.Points
                  , res.Laps
                  , res.ResultStatusId
                  , ROW_NUMBER() OVER (PARTITION BY r.RaceId ORDER BY res.FastestLapTime) AS rn
             FROM Race r
                      INNER JOIN Result res
                                 ON res.RaceId = r.RaceId
             WHERE r.RaceYear BETWEEN 2004 AND 2024
               AND res.FastestLapTime IS NOT NULL)

SELECT c.CircuitName                           AS CircuitName
     , r.RaceDate                              AS RaceDate
     , CONCAT_WS(' ', d.Firstname, d.Lastname) AS Name
     , rr.FastestLap                           AS FastestLap
     , rr.FastestLapTime                       AS FastestLapTime
     , rr.PositionText                         AS Position
     , rr.Points                               AS Points
     , rr.Laps                                 AS Laps
     , rs.ResultStatus                         AS ResultStatus
FROM RankedResults rr
         INNER JOIN Race r
                    ON r.RaceId = rr.RaceId
         INNER JOIN Driver d
                    ON d.DriverId = rr.DriverId
         INNER JOIN Circuit c
                    ON c.CircuitId = r.CircuitId
         INNER JOIN ResultStatus rs
                    ON rs.ResultStatusId = rr.ResultStatusId
WHERE rr.rn = 1
ORDER BY CircuitName, FastestLapTime;
```

#### A.2.2.2. Resultaten

#### A.2.2.3. Toelichting

#### A.2.2.4. Query plan

#### A.2.2.5. Aanbevolen indexen

## A.3. Toon voor de seizoenen 2015 tot en met 2024 de winnaar van het seizoen. Geef het jaartal van het seizoen, de naam van de winnaar, het aantal races dat hij heeft gewonnen. Voeg ook het totaal aantal races toe, en voeg tot slot het volgende toe: vanaf welke race (datum, volgnummer in het seizoen + naam van de race) stond hij in de klassering op de eerste plaats en behield hij die eerste plek tot het einde toe.

### A.3.1. Primaire Uitwerking

#### A.3.1.1. Query

```sql
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
```

#### A.3.1.2. Resultaten

#### A.3.1.3. Toelichting

#### A.3.1.4. Query plan

#### A.3.1.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

### A.3.2. Alternatieve Uitwerking

#### A.3.2.1. Query

```sql
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
```

#### A.3.2.2. Resultaten

#### A.3.2.3. Toelichting

#### A.3.2.4. Query plan

#### A.3.2.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

## A.4. Welke coureurs hebben na deelname van een of meerdere seizoenen een periode niet deelgenomen en zijn in een later seizoen weer teruggekeerd in de Formule 1? Geef de naam van de coureur in alfabetische volgorde en daarnaast de periodes (in het format “1991–2006”, “2010–2012”) waarin ze deelgenomen hebben. Zet deze periodes op chronologische volgorde.

### A.4.1. Primaire Uitwerking

#### A.4.1.1. Query

```sql
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS Coureur
     , DriverYearRanges.Ranges                           AS Periodes
FROM Driver
         INNER JOIN DriverYearRanges ON DriverYearRanges.DriverId = Driver.DriverId
ORDER BY Coureur;
```

##### View

In diverse hierna volgende queries worden dezelfde perioden gebruikt, om te voorkomen dat deze complexe query steeds
opnieuw geschreven moet worden, is er gekozen om de volgende view te maken.

```sql
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
```

#### A.4.1.2. Resultaten

#### A.4.1.3. Toelichting

Het uitwerken van dit vraagstuk was enorm complex, veel SQL databases hebben namelijk ingebouwde ondersteuning voor 
ranges, zoals postgres met intrange of tsrange; SQL Server heeft dit echter niet, hierdoor moest deze complete 
logica zelf geschreven worden.

Ik heb dit aangepakt door eerst een beeld te brengen welke jaren iedere driver meegedaan heeft aan races, hierna 
heb ik deze op volgorde gezet, waarbij ik door middel van de LAG() operatie met OVER() heb gekeken of de jaren die 
op volgorde staan, een opeenvolging van elkaar zijn. Indien deze niet matchen wordt er dan een nieuwe groep 
gestart (eigenlijk betekent dit: reeks opgebroken). Door middel van de SUM() operatie met OVER() heb ik daarna echte 
groepen gemaakt van jaren die bij elkaar horen; dit wordt dan in een volgende stap gebruikt om voor iedere groep de 
minimale en maximale jaartallen binnen te halen, waarbij ik ook een string-formatted variant opstel die of een range 
opstelt, of een enkel jaartal als een groep maar een jaar is.

Van deze hele operatie heb ik nader een view gemaakt (en het document ook hierop aangepast), omdat deze in veel 
hierna volgende vraagstukken gebruikt gaat worden. Hierdoor kan toekomstige code te overzien blijven.

Tot slot heb ik veel pogingen gewaagd om een alternatieve implementatie hiervoor te bedenken, dit is mij echter 
niet gelukt. En zoals de opdracht stelde ‘indien mogelijk’; daarom heb ik na veel werk, dus gekozen om deze niet 
voort te zetten. Ik kreeg geen goede uitwerking die anders werkte.

#### A.4.1.4. Query plan

#### A.4.1.5. Aanbevolen indexen

## A.5. Maak een overzicht van alle F1 coureurs die in hun volledige carrière 25 of meer wedstrijden hebben gewonnen. Toon per coureur zijn naam, in één veld een overzicht van de seizoenen waarin hij gereden heeft (ontbrekende jaren weglaten), het aantal races dat hij gestart is, het aantal races die hij gewonnen heeft en het percentage van het aantal races die hij gewonnen heeft ten opzichte van het aantal races dat hij gestart is. Een voorbeeld van hoe het er voor Michael Schumacher en Ayrton Senna uitziet, zie je hieronder.

### A.5.1. Primaire Uitwerking

#### A.5.1.1. Query

```sql
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
             GROUP BY Result.DriverId)
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                                  AS Driver
     , DriverYearRanges.Ranges                                                            AS Seasons
     , DriverEntry.Entries                                                                AS Entries
     , DriverWin.Wins                                                                     AS Wins
     , CONCAT(ROUND((CAST(DriverWin.Wins AS FLOAT) / DriverEntry.Entries) * 100, 2), '%') AS Percentage
FROM Driver
         INNER JOIN DriverEntry ON DriverEntry.DriverId = Driver.DriverId
         INNER JOIN DriverWin ON DriverWin.DriverId = Driver.DriverId
         LEFT JOIN DriverYearRanges ON DriverYearRanges.DriverId = Driver.DriverId
WHERE DriverWin.Wins >= 25
ORDER BY DriverWin.Wins DESC;
```

#### A.5.1.2. Resultaten

#### A.5.1.3. Toelichting

#### A.5.1.4. Query plan

#### A.5.1.5. Aanbevolen indexen

### A.5.2. Alternatieve Uitwerking

#### A.5.2.1. Query

```sql
SELECT DISTINCT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname)                          AS Driver
              , DriverYearRanges.Ranges                                                    AS Seasons
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
         INNER JOIN DriverYearRanges ON DriverYearRanges.DriverId = Driver.DriverId
WHERE Result.Wins >= 25;
```

#### A.5.2.2. Resultaten

#### A.5.2.3. Toelichting

#### A.5.2.4. Query plan

#### A.5.2.5. Aanbevolen indexen

Er zijn geen indexen voorgesteld door de database management tool voor deze query.

## A.6. Er zijn niet ieder jaar evenveel wedstrijden gereden. Daarom is het interessant om te zien welke coureur procentueel de meeste races per seizoen heeft gewonnen. Maak onderstaand overzicht

### A.6.1. Primaire Uitwerking

#### A.6.1.1. Query

```sql
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
```

#### A.6.1.2. Resultaten

#### A.6.1.3. Toelichting

De eerste oplossing voor het vraagstuk heb ik geimplementeerd door gebruik te maken van twee CTEs, een berekend het 
aantal wins per race, en de ander het totaal aantal races per bestuurder. Deze worden dan samengebracht waarbij het 
percentage berekend wordt. Tijdens het samenbrengen is er gekozen voor een left-join van de wins, omdat er niet 
altijd wins voor een jaar zullen zijn. Indien het een inner join zou zijn geweest, zouden enkel jaren met wins zichtbaar zijn.

#### A.6.1.4. Query plan

#### A.6.1.5. Aanbevolen indexen

### A.6.2. Alternatieve Uitwerking

#### A.6.2.1. Query

```sql
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
```

#### A.6.2.2. Resultaten

#### A.6.2.3. Toelichting

Voor de alternatieve implementatie heb ik de query korter proberen te maken. In deze nieuwe query wordt in een keer 
zowel het aantal wins, races en het percentage berekend. Dit is mogelijk door de IIF/NULLIF te gebruiken van SQL 
server, waarbij ik het tellen conditioneel maak (per groep), in plaats van filtering met een WHERE uit te voeren. 
Deze is daardoor veel korter, en heeft ook een simpeler queryplan.

#### A.6.2.4. Query plan

#### A.6.2.5. Aanbevolen indexen

## A.7. Maak de eindstand voor de coureurs van 2021 na. Zie onderstaand overzicht voor de juiste punten.

### A.7.1. Invoegen extra gegevens

#### A.7.1.1. Query

```sql
-- Create helper function for splitting strings.
CREATE OR ALTER FUNCTION dbo.SplitPart(@s NVARCHAR(MAX), @sep NCHAR(1), @n INT)
    RETURNS NVARCHAR(MAX) AS
BEGIN
    RETURN (SELECT value
            FROM (SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                  FROM STRING_SPLIT(@s, @sep)) t
            WHERE rn = @n)
END;
GO

-- Drop the existing race results table if it exists.
DROP TABLE IF EXISTS #RaceResults;
GO

-- Create the race results.
CREATE TABLE #RaceResults
(
    RaceNr      INT,
    Circuit     NVARCHAR(100),
    POS         INT,
    NO          INT,
    Driver      NVARCHAR(100),
    Car         NVARCHAR(100),
    Laps        INT,
    TimeRetired NVARCHAR(50),
    Points      INT
);
GO

-- Create the CSV string.
DECLARE @csv NVARCHAR = N'202114;Monza;1;77;Valtteri Bottas;MERCEDES;18;27:54.078;3
202114;Monza;2;33;Max Verstappen;RED BULL RACING HONDA;18;+2.325s;2
202114;Monza;3;3;Daniel Ricciardo;MCLAREN MERCEDES;18;+14.534s;1
202110;Silverstone;1;33;Max Verstappen;RED BULL RACING HONDA;17;25:38.426;3
202110;Silverstone;2;44;Lewis Hamilton;MERCEDES;17;+1.430s;2
202110;Silverstone;3;77;Valtteri Bottas;MERCEDES;17;+7.502s;1
202119;Sao Paulo;1;77;Valtteri Bottas;MERCEDES;24;29:09.559;3
202119;Sao Paulo;2;33;Max Verstappen;RED BULL RACING HONDA;24;+1.170s;2
202119;Sao Paulo;3;55;Carlos Sainz;FERRARI;24;+18.723s;1';

-- Parse the CSV string into the temporary table.
INSERT INTO #RaceResults
SELECT TRY_CAST(dbo.SplitPart(value, ';', 1) AS INT), -- RaceNr
       dbo.SplitPart(value, ';', 2),                  -- Circuit
       TRY_CAST(dbo.SplitPart(value, ';', 3) AS INT), -- POS
       TRY_CAST(dbo.SplitPart(value, ';', 4) AS INT), -- NO
       dbo.SplitPart(value, ';', 5),                  -- Driver
       dbo.SplitPart(value, ';', 6),                  -- Car
       TRY_CAST(dbo.SplitPart(value, ';', 7) AS INT), -- Laps
       dbo.SplitPart(value, ';', 8),                  -- Time/Retired
       TRY_CAST(dbo.SplitPart(value, ';', 9) AS INT)  -- Points
FROM STRING_SPLIT(@csv, CHAR(10))
WHERE TRIM(value) <> '';

-- Create circuits
INSERT INTO Circuit (CircuitId, CircuitRef, CircuitName, CircuitLocation, Country)
SELECT ROW_NUMBER() OVER (ORDER BY RaceResults.Circuit)
           + ISNULL((SELECT MAX(CircuitId) FROM Circuit), 0),
       RaceResults.Circuit,
       RaceResults.Circuit,
       RaceResults.Circuit,
       'Unknown'
FROM (SELECT DISTINCT Circuit
      FROM #RaceResults) AS RaceResults
WHERE NOT EXISTS (SELECT 1
                  FROM Circuit c
                  WHERE c.CircuitName = RaceResults.Circuit);

-- Create constructors
INSERT INTO Constructor (ConstructorId, ConstructorRef, ContstructorName, Nationality, ConstructorUrl)
SELECT ROW_NUMBER() OVER (ORDER BY RaceResults.Car)
           + ISNULL((SELECT MAX(ConstructorId) FROM Constructor), 0),
       ISNULL(RaceResults.Car, 'UNKNOWN'),
       ISNULL(RaceResults.Car, 'UNKNOWN'),
       'Unknown',
       ''
FROM (SELECT DISTINCT Car
      FROM #RaceResults) AS RaceResults
WHERE NOT EXISTS (SELECT 1
                  FROM Constructor c
                  WHERE c.ContstructorName = RaceResults.Car);

-- Create drivers
INSERT INTO Driver (DriverId, DriverRef, DriverNumber, Firstname, Lastname, Nationality)
SELECT DISTINCT #RaceResults.NO,
                #RaceResults.Driver,
                #RaceResults.NO,
                LEFT(#RaceResults.Driver, CHARINDEX(' ', #RaceResults.Driver + ' ') - 1),
                LTRIM(SUBSTRING(#RaceResults.Driver, CHARINDEX(' ', #RaceResults.Driver + ' '),
                                LEN(#RaceResults.Driver))),
                'Unknown'
FROM #RaceResults
WHERE #RaceResults.NO IS NOT NULL
  AND NOT EXISTS (SELECT 1
                  FROM Driver d
                  WHERE d.DriverId = #RaceResults.NO);

-- Create seasons
INSERT INTO Season (RaceYear, SeasonUrl)
SELECT DISTINCT #RaceResults.RaceNr / 100 AS RaceYear,
                ''
FROM #RaceResults
WHERE NOT EXISTS (SELECT 1
                  FROM Season s
                  WHERE s.RaceYear = #RaceResults.RaceNr / 100);

-- Create races
INSERT INTO Race (RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
SELECT DISTINCT #RaceResults.RaceNr,
                #RaceResults.RaceNr / 100,
                #RaceResults.RaceNr % 100,
                c.CircuitId,
                #RaceResults.Circuit,
                GETDATE()
FROM #RaceResults
         JOIN Circuit c ON c.CircuitName = #RaceResults.Circuit
WHERE NOT EXISTS (SELECT 1
                  FROM Race r
                  WHERE r.RaceId = #RaceResults.RaceNr);

-- Create results
INSERT INTO Result
(ResultId,
 RaceId,
 DriverId,
 ConstructorId,
 Grid,
 Position,
 PositionText,
 PositionOrder,
 Points,
 Laps,
 Time,
 ResultStatusId)
SELECT ROW_NUMBER() OVER (ORDER BY #RaceResults.RaceNr, #RaceResults.POS)
           + ISNULL((SELECT MAX(ResultId) FROM Result), 0),
       #RaceResults.RaceNr,
       d.DriverId,
       c.ConstructorId,
       #RaceResults.POS,
       #RaceResults.POS,
       CAST(#RaceResults.POS AS NVARCHAR),
       #RaceResults.POS,
       #RaceResults.Points,
       #RaceResults.Laps,
       #RaceResults.TimeRetired,
       1
FROM #RaceResults
         JOIN Driver d ON d.DriverId = #RaceResults.NO
         JOIN Constructor c ON c.ContstructorName = #RaceResults.Car
WHERE NOT EXISTS (SELECT 1
                  FROM Result r
                  WHERE r.RaceId = #RaceResults.RaceNr
                    AND r.DriverId = d.DriverId);
```

#### A.7.1.2. Toelichting

Om de gegevens in te laden heb ik deze handmatig moeten uitlezen van het CSV formaat. Helaas omdat ik Docker gebruik, 
was het eenvoudig inladen van CSV bestanden met de ingebouwde functies niet mogelijk; vandaar dat ik het zelf heb 
moeten doen. Het inladen van deze gegevens is gegaan in een tijdelijke tabel.

Deze tijdelijke tabel wordt stapgewijs overgezet naar de daadwerkelijke tables. Dit is in verschillende stappen gegaan, 
waarbij er in iedere stap op basis van de gegevens uit de tijdelijke tabel (en enige aannames) de nieuwe rijen aan 
worden gemaakt. Hierbij is er ook zo veel mogelijk gedaan om te checken dat er geen duplicate rijen worden toegevoegd 
(dit door middel van NOT EXISTS met een subquery).

### A.7.2. Primaire Uitwerking

#### A.7.2.1. Query

```sql
SELECT DriverStanding.Position                  AS POS
     , Driver.Firstname + ' ' + Driver.Lastname AS DRIVER
     , Driver.Nationality                       AS NATIONALITY
     , Constructor.ContstructorName             AS CAR
     , DriverStanding.Points                    AS PTS
FROM DriverStanding
         INNER JOIN Driver ON DriverStanding.DriverId = Driver.DriverId
         INNER JOIN Race ON DriverStanding.RaceId = Race.RaceId
         INNER JOIN Result ON Result.RaceId = Race.RaceId
    AND Result.DriverId = Driver.DriverId
         INNER JOIN Constructor ON Result.ConstructorId = Constructor.ConstructorId
WHERE Race.RaceYear = 2021
  AND Race.RaceId = (SELECT MAX(RaceId)
                     FROM Race
                     WHERE RaceYear = 2021)
ORDER BY DriverStanding.Position;
```

#### A.7.2.2. Resultaten

#### A.7.2.3. Toelichting

#### A.7.2.4. Query plan

#### A.7.2.5. Aanbevolen indexen

### A.7.3. Alternatieve Uitwerking

#### A.7.3.1. Query

```sql
SELECT DriverStanding.Position                  AS POS
     , Driver.Firstname + ' ' + Driver.Lastname AS DRIVER
     , Driver.Nationality                       AS NATIONALITY
     , Constructor.ContstructorName             AS CAR
     , DriverStanding.Points                    AS PTS
FROM DriverStanding
         JOIN Driver ON DriverStanding.DriverId = Driver.DriverId
         JOIN Race ON DriverStanding.RaceId = Race.RaceId
         CROSS APPLY (SELECT TOP 1 Result.ConstructorId
                      FROM Result
                      WHERE Result.DriverId = Driver.DriverId
                        AND Result.RaceId = Race.RaceId
                      ORDER BY Result.ResultId DESC) AS LatestResult
         JOIN Constructor ON LatestResult.ConstructorId = Constructor.ConstructorId
WHERE Race.RaceYear = 2021
  AND Race.RaceId = (SELECT TOP 1 RaceId
                     FROM Race
                     WHERE RaceYear = 2021
                     ORDER BY RaceDate DESC)
ORDER BY DriverStanding.Position;
```

#### A.7.3.2. Resultaten

#### A.7.3.3. Toelichting

#### A.7.3.4. Query plan

#### A.7.3.5. Aanbevolen indexen