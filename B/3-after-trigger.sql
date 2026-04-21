-- Create the trigger that checks for race count in seasons.
CREATE OR ALTER TRIGGER TooManyRacesInSeason
    ON Race
    AFTER INSERT, UPDATE
    AS
BEGIN
    -- Declare variable containing the overflow info.
    DECLARE @OverflowInfo NVARCHAR(500);

    -- Check for any overflow that might have been caused by the insert or update.
    SELECT TOP 1 @OverflowInfo = CONCAT('Season with more than 25 races detected: RaceYear = ',
                                        CAST(Race.RaceYear AS NVARCHAR(4)))
    FROM Race
    WHERE Race.RaceYear IN (SELECT inserted.RaceYear FROM inserted)
    GROUP BY Race.RaceYear
    HAVING COUNT(1) > 25

    -- Throw error if overflow detected
    IF @OverflowInfo IS NOT NULL
        BEGIN
            THROW 50001, @OverflowInfo, 1;
        END
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Insert up to 25 races in a season (boundary check).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test01: performing'

-- Create test circuit
PRINT 'Test01: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (910000)

-- Create test season
PRINT 'Test01: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2040, 'https://example.com')

-- Create 24 existing races
PRINT 'Test01: creating 24 existing races'
DECLARE @i INT = 1
WHILE @i <= 24
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (910000 + @i, 2040, @i, 910000, 'Existing race', '2040-03-02')
        SET @i = @i + 1
    END

-- Insert 25th race (should succeed)
PRINT 'Test01: inserting 25th race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (919999, 2040, 25, 910000, 'Final allowed race', '2040-12-01')

PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should fail) - Insert 26th race in season (trigger should fire).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test02: performing'

BEGIN TRY

    -- Create circuit
    PRINT 'Test02: creating test circuit'
    INSERT INTO Circuit(CircuitId)
    VALUES (910001)

    -- Create season
    PRINT 'Test02: creating test season'
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2041, 'https://example.com')

    -- Create 25 existing races
    PRINT 'Test02: creating 25 existing races'
    DECLARE @i INT = 1
    WHILE @i <= 25
        BEGIN
            INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
            VALUES (920000 + @i, 2041, @i, 910001, 'Existing race', '2041-03-02')
            SET @i = @i + 1
        END

    -- Insert 26th race (should fail)
    PRINT 'Test02: inserting 26th race'
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (929999, 2041, 26, 910001, 'Overflow race', '2041-12-01');

    THROW 50001, 'Test failed: expected exception was not thrown', 1

END TRY
BEGIN CATCH
    PRINT 'Test02: expected exception occurred'
    PRINT 'Test02: succeeded (exception was expected)'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should succeed) - Update race without changing season (no overflow).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

-- Setup circuit + season
INSERT INTO Circuit(CircuitId)
VALUES (910002)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2042, 'https://example.com')

-- Create race
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (930001, 2042, 1, 910002, 'Original race', '2042-03-02')

-- Update race (same season, safe)
PRINT 'Test03: updating race without year change'
UPDATE Race
SET RaceName = 'Updated race name'
WHERE RaceId = 930001

PRINT 'Test03: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Move race to another season with available capacity.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test04: performing'

-- Circuits
INSERT INTO Circuit(CircuitId)
VALUES (910003)

-- Seasons
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2043, 'https://example.com')

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2044, 'https://example.com')

-- Source race
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (940001, 2043, 1, 910003, 'Race A', '2043-03-02')

-- Create 10 races in target season
DECLARE @i INT = 1
WHILE @i <= 10
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (941000 + @i, 2044, @i, 910003, 'Existing race', '2044-03-02')
        SET @i = @i + 1
    END

-- Move race (should succeed)
PRINT 'Test04: updating race to different valid season'
UPDATE Race
SET RaceYear  = 2044,
    NrOfRound = 11,
    RaceName  = 'Moved race'
WHERE RaceId = 940001

PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Move race into a season already exceeding limit (trigger should fire).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test05: performing'

BEGIN TRY

    -- Circuit
    INSERT INTO Circuit(CircuitId)
    VALUES (910004)

    -- Seasons
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2045, 'https://example.com')

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2046, 'https://example.com')

    -- Source race
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (950001, 2045, 1, 910004, 'Race A', '2045-03-02')

    -- Fill target season with 25 races
    DECLARE @i INT = 1
    WHILE @i <= 25
        BEGIN
            INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
            VALUES (951000 + @i, 2046, @i, 910004, 'Full season race', '2046-03-02')
            SET @i = @i + 1
        END

    -- Move race into overflow season (should fail)
    PRINT 'Test05: updating race into full season'
    UPDATE Race
    SET RaceYear  = 2046,
        NrOfRound = 26,
        RaceName  = 'Invalid move'
    WHERE RaceId = 950001;

    THROW 50001, 'Test failed: expected exception was not thrown', 1

END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred'
    PRINT 'Test05: succeeded (exception was expected)'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Insert multiple races across seasons without triggering overflow.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test06: performing'

-- Circuit
INSERT INTO Circuit(CircuitId)
VALUES (910005)

-- Seasons
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2047, 'https://example.com')

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2048, 'https://example.com')

-- Insert 25 races in 2047
DECLARE @i INT = 1
WHILE @i <= 25
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (960000 + @i, 2047, @i, 910005, 'Season 2047 race', '2047-03-02')
        SET @i = @i + 1
    END

-- Insert 5 races in 2048 (both valid independently)
DECLARE @j INT = 1
WHILE @j <= 5
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (961000 + @j, 2048, @j, 910005, 'Season 2048 race', '2048-03-02')
        SET @j = @j + 1
    END

PRINT 'Test06: succeeded'
ROLLBACK
GO