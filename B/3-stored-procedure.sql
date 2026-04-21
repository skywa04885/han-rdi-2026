-- Create the procedure that will create races.
CREATE OR ALTER PROCEDURE CreateRace(
    @RaceId INT,
    @RaceYear INT,
    @NrOfRound INT,
    @CircuitId INT,
    @RaceName NVARCHAR(150),
    @RaceDate DATE,
    @RaceStartTime TIME = NULL,
    @RaceUrl NVARCHAR(150) = NULL,
    @Practice1Date DATE = NULL,
    @Practice1Time TIME = NULL,
    @Practice2Date DATE = NULL,
    @Practice2Time TIME = NULL,
    @Practice3Date DATE = NULL,
    @Practice3Time TIME = NULL,
    @QualificationDate DATE = NULL,
    @QualificationTime TIME = NULL,
    @SprintRaceDate DATE= NULL,
    @SprintRaceTime TIME = NULL
)
AS
BEGIN
    -- Declare the number of races.
    DECLARE @NoRaces INT;

    -- Find the number of races in the season.
    SELECT @NoRaces = COUNT(1)
    FROM Race
    WHERE Race.RaceYear = @RaceYear

    -- Throw an error if the number of races exceeds 25 when the new one will be inserted.
    if @NoRaces > 24
        BEGIN
            THROW 50001, 'The number of races in the season will exceed 25 with the insertion of a new one.', 1
        END

    -- Insert the race.
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate, RaceStartTime, RaceUrl,
                     Practice1Date, Practice1Time, Practice2Date, Practice2Time, Practice3Date, Practice3Time,
                     QualificationDate, QualificationTime, SprintRaceDate, SprintRaceTime)
    VALUES (@RaceId, @RaceYear, @NrOfRound, @CircuitId, @RaceName,
            @RaceDate, @RaceStartTime, @RaceUrl, @Practice1Date,
            @Practice1Time, @Practice2Date, @Practice2Time,
            @Practice3Date, @Practice3Time, @QualificationDate,
            @QualificationTime, @SprintRaceDate, @SprintRaceTime);
END
GO

-- Create the procedure that will update races.
CREATE OR ALTER PROCEDURE UpdateRace(
    @RaceId INT,
    @RaceYear INT,
    @NrOfRound INT,
    @CircuitId INT,
    @RaceName NVARCHAR(150),
    @RaceDate DATE,
    @RaceStartTime TIME = NULL,
    @RaceUrl NVARCHAR(150) = NULL,
    @Practice1Date DATE = NULL,
    @Practice1Time TIME = NULL,
    @Practice2Date DATE = NULL,
    @Practice2Time TIME = NULL,
    @Practice3Date DATE = NULL,
    @Practice3Time TIME = NULL,
    @QualificationDate DATE = NULL,
    @QualificationTime TIME = NULL,
    @SprintRaceDate DATE= NULL,
    @SprintRaceTime TIME = NULL
)
AS
BEGIN
    -- Declare the original race year.
    DECLARE @OriginalRaceYear INT

    -- Select the existing race.
    SELECT @OriginalRaceYear = Race.RaceYear
    FROM Race
    WHERE Race.RaceId = @RaceId

    -- If the race could not be found, do nothing, a regular update will also remain silent.
    IF @OriginalRaceYear IS NULL
        BEGIN
            RETURN
        END

    -- Perform the validation of the number of races in the season, only if the year changed.
    if @OriginalRaceYear != @RaceYear
        BEGIN
            -- Declare the number of races.
            DECLARE @NoRaces INT;

            -- Find the number of races in the season.
            SELECT @NoRaces = COUNT(1)
            FROM Race
            WHERE Race.RaceYear = @RaceYear

            -- Throw an error if the number of races exceeds 25 when the update will be performed.
            if @NoRaces > 24
                BEGIN
                    THROW 50001, 'The number of races in the season will exceed 25 with the addition of a new one.', 1
                END
        END

    -- Perform the update of the race.
    UPDATE Race
    SET RaceYear          = @RaceYear,
        NrOfRound         = @NrOfRound,
        CircuitId         = @CircuitId,
        RaceName          = @RaceName,
        RaceDate          = @RaceDate,
        RaceStartTime     = @RaceStartTime,
        RaceUrl           = @RaceUrl,
        Practice1Date     = @Practice1Date,
        Practice1Time     = @Practice1Time,
        Practice2Date     = @Practice2Date,
        Practice2Time     = @Practice2Time,
        Practice3Date     = @Practice3Date,
        Practice3Time     = @Practice3Time,
        QualificationDate = @QualificationDate,
        QualificationTime = @QualificationTime,
        SprintRaceDate    = @SprintRaceDate,
        SprintRaceTime    = @SprintRaceTime
    WHERE RaceId = @RaceId
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Insert races up to the limit (24 existing + 1 new = 25 total).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test01: performing'

-- Create test circuit
PRINT 'Test01: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create test season
PRINT 'Test01: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

-- Create 24 existing races
PRINT 'Test01: creating 24 existing races'
DECLARE @i INT = 1
WHILE @i <= 24
BEGIN
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000 + @i, 2030, @i, 900000, 'Pre-existing race', '2030-03-02')
    SET @i = @i + 1
END

-- Insert 25th race (should succeed)
PRINT 'Test01: inserting 25th race'
EXEC CreateRace
     @RaceId = 999999,
     @RaceYear = 2030,
     @NrOfRound = 25,
     @CircuitId = 900000,
     @RaceName = 'Final allowed race',
     @RaceDate = '2030-12-01'

PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should fail) - Insert race exceeding 25 limit.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test02: performing'

BEGIN TRY

    -- Create circuit
    PRINT 'Test02: creating test circuit'
    INSERT INTO Circuit(CircuitId)
    VALUES (900001)

    -- Create season
    PRINT 'Test02: creating test season'
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2031, 'https://example.com')

    -- Create 25 existing races
    PRINT 'Test02: creating 25 existing races'
    DECLARE @i INT = 1
    WHILE @i <= 25
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (800000 + @i, 2031, @i, 900001, 'Existing race', '2031-03-02')
        SET @i = @i + 1
    END

    -- This should fail (26th race)
    PRINT 'Test02: inserting race exceeding limit'
    EXEC CreateRace
         @RaceId = 899999,
         @RaceYear = 2031,
         @NrOfRound = 26,
         @CircuitId = 900001,
         @RaceName = 'Overflow race',
         @RaceDate = '2031-12-01';

    THROW 50001, 'Test failed: expected exception was not thrown', 1

END TRY
BEGIN CATCH
    PRINT 'Test02: expected exception occurred'
    PRINT 'Test02: succeeded (exception was expected)'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should succeed) - Update race within same season (no year change).
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

-- Setup circuit + season
INSERT INTO Circuit(CircuitId)
VALUES (900002)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2032, 'https://example.com')

-- Create race
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (700001, 2032, 1, 900002, 'Original race', '2032-03-02')

-- Update same race
PRINT 'Test03: updating race without year change'
EXEC UpdateRace
     @RaceId = 700001,
     @RaceYear = 2032,
     @NrOfRound = 1,
     @CircuitId = 900002,
     @RaceName = 'Updated race name',
     @RaceDate = '2032-03-03'

PRINT 'Test03: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Move race to a season with free capacity.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test04: performing'

-- Circuits
INSERT INTO Circuit(CircuitId)
VALUES (900003)

-- Season A
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2033, 'https://example.com')

-- Season B
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2034, 'https://example.com')

-- Create race in season A
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (600001, 2033, 1, 900003, 'Race A', '2033-03-02')

-- Create 10 races in season B
DECLARE @i INT = 1
WHILE @i <= 10
BEGIN
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (610000 + @i, 2034, @i, 900003, 'Existing race', '2034-03-02')
    SET @i = @i + 1
END

-- Move race
PRINT 'Test04: updating race to different valid season'
EXEC UpdateRace
     @RaceId = 600001,
     @RaceYear = 2034,
     @NrOfRound = 11,
     @CircuitId = 900003,
     @RaceName = 'Moved race',
     @RaceDate = '2034-06-01'

PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Move race into full season.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test05: performing'

BEGIN TRY

    -- Circuit
    INSERT INTO Circuit(CircuitId)
    VALUES (900004)

    -- Seasons
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2035, 'https://example.com')

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2036, 'https://example.com')

    -- Source race
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (500001, 2035, 1, 900004, 'Race A', '2035-03-02')

    -- Fill target season (25 races)
    DECLARE @i INT = 1
    WHILE @i <= 25
    BEGIN
        INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
        VALUES (510000 + @i, 2036, @i, 900004, 'Full season race', '2036-03-02')
        SET @i = @i + 1
    END

    -- Attempt move (should fail)
    PRINT 'Test05: updating race into full season'
    EXEC UpdateRace
         @RaceId = 500001,
         @RaceYear = 2036,
         @NrOfRound = 26,
         @CircuitId = 900004,
         @RaceName = 'Invalid move',
         @RaceDate = '2036-06-01';

    THROW 50001, 'Test failed: expected exception was not thrown', 1

END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred'
    PRINT 'Test05: succeeded (exception was expected)'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Move race into empty season.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test06: performing'

-- Circuit
INSERT INTO Circuit(CircuitId)
VALUES (900005)

-- Seasons
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2037, 'https://example.com')

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2038, 'https://example.com')

-- Race
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (400001, 2037, 1, 900005, 'Race to move', '2037-03-02')

-- Move
PRINT 'Test06: updating race to empty season'
EXEC UpdateRace
     @RaceId = 400001,
     @RaceYear = 2038,
     @NrOfRound = 1,
     @CircuitId = 900005,
     @RaceName = 'Moved cleanly',
     @RaceDate = '2038-03-02'

PRINT 'Test06: succeeded'
ROLLBACK
GO