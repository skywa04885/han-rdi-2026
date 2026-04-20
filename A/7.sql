-- Ik ben mij ervan bewust dat SQL server een import functie heeft voor CSV. Maar ik krijg het niet voor elkaar om
--  mijn CSV in de docker container te krijgen, iedere keer rechten-errors wegens een of andere rare permissie
--  structuur die Microsoft in de container gedaan heeft, daarom deze handmatige aanpak.

CREATE OR ALTER FUNCTION dbo.SplitPart(@s NVARCHAR(MAX), @sep NCHAR(1), @n INT)
    RETURNS NVARCHAR(MAX) AS
BEGIN
    RETURN (SELECT value
            FROM (SELECT value, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                  FROM STRING_SPLIT(@s, @sep)) t
            WHERE rn = @n)
END;
GO

DROP TABLE IF EXISTS #RaceResults;
GO

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

DECLARE @csv NVARCHAR(MAX) = N'202114;Monza;1;77;Valtteri Bottas;MERCEDES;18;27:54.078;3
202114;Monza;2;33;Max Verstappen;RED BULL RACING HONDA;18;+2.325s;2
202114;Monza;3;3;Daniel Ricciardo;MCLAREN MERCEDES;18;+14.534s;1
202110;Silverstone;1;33;Max Verstappen;RED BULL RACING HONDA;17;25:38.426;3
202110;Silverstone;2;44;Lewis Hamilton;MERCEDES;17;+1.430s;2
202110;Silverstone;3;77;Valtteri Bottas;MERCEDES;17;+7.502s;1
202119;Sao Paulo;1;77;Valtteri Bottas;MERCEDES;24;29:09.559;3
202119;Sao Paulo;2;33;Max Verstappen;RED BULL RACING HONDA;24;+1.170s;2
202119;Sao Paulo;3;55;Carlos Sainz;FERRARI;24;+18.723s;1';

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
WHERE LTRIM(RTRIM(value)) <> '';

SELECT *
FROM #RaceResults;