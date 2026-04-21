-- Create the stored procedure that will perform the insert.
CREATE OR ALTER PROCEDURE CreateResultProcedure(
    @ResultId INT,
    @RaceId INT,
    @DriverId INT,
    @ConstructorId INT = NULL,
    @ResultNumber INT = NULL,
    @Grid INT = NULL,
    @Position INT = NULL,
    @PositionText NVARCHAR(50) = NULL,
    @PositionOrder INT = NULL,
    @Points DECIMAL(18, 4) = NULL,
    @Laps INT = NULL,
    @Time NVARCHAR(50) = NULL,
    @Milliseconds INT = NULL,
    @FastestLap INT = NULL,
    @Rank INT = NULL,
    @FastestLapTime TIME = NULL,
    @FastestLapSpeed DECIMAL(18, 4) = NULL,
    @ResultStatusId INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON

    -- Declare the race year with the initial value of null (so that we can see if the record existed).
    DECLARE @RaceYear INT = NULL

    -- Select the year of the race that has the race id (also used to determine existence).
    SELECT @RaceYear = Race.RaceYear
    FROM Race
    WHERE Race.RaceId = @RaceId

    -- Make sure the race year could be fetched (always the case if the race exists).
    IF @RaceYear IS NULL
        BEGIN
            THROW 50001, 'Race does not exist', 1
        END

    -- If the season equals or is after 1979, make sure the driver does not already have a result in this race.
    IF @RaceYear >= 1979 AND EXISTS(SELECT 1
                                    FROM Result
                                    WHERE RaceId = @RaceId
                                      AND DriverId = @DriverId)
        BEGIN
            THROW 50001, 'Driver already has a result in this race', 2
        END

    -- Insert the result.
    INSERT INTO Result (ResultId, RaceId, DriverId, ConstructorId, ResultNumber, Grid, Position, PositionText,
                        PositionOrder, Points, Laps, Time, Milliseconds, FastestLap, Rank, FastestLapTime,
                        FastestLapSpeed, ResultStatusId)
    VALUES (@ResultId, @RaceId, @DriverId, @ConstructorId, @ResultNumber,
            @Grid, @Position, @PositionText, @PositionOrder, @Points,
            @Laps, @Time, @Milliseconds, @FastestLap, @Rank,
            @FastestLapTime, @FastestLapSpeed, @ResultStatusId)
END
GO

-- Create the update stored procedure.
CREATE OR ALTER PROCEDURE UpdateResultProcedure(
    @ResultId INT,
    @RaceId INT,
    @DriverId INT,
    @ConstructorId INT = NULL,
    @ResultNumber INT = NULL,
    @Grid INT = NULL,
    @Position INT = NULL,
    @PositionText NVARCHAR(50) = NULL,
    @PositionOrder INT = NULL,
    @Points DECIMAL(18, 4) = NULL,
    @Laps INT = NULL,
    @Time NVARCHAR(50) = NULL,
    @Milliseconds INT = NULL,
    @FastestLap INT = NULL,
    @Rank INT = NULL,
    @FastestLapTime TIME = NULL,
    @FastestLapSpeed DECIMAL(18, 4) = NULL,
    @ResultStatusId INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @RaceYear INT = NULL;

    -- Check race exists
    SELECT @RaceYear = RaceYear
    FROM Race
    WHERE RaceId = @RaceId;

    IF @RaceYear IS NULL
        BEGIN
            THROW 50001, 'Race does not exist', 1;
        END

    -- Check result exists
    IF NOT EXISTS (SELECT 1 FROM Result WHERE ResultId = @ResultId)
        BEGIN
            THROW 50001, 'Result does not exist', 1;
        END

    -- Enforce driver uniqueness after 1979 (excluding itself!)
    IF @RaceYear >= 1979 AND EXISTS (SELECT 1
                                     FROM Result
                                     WHERE RaceId = @RaceId
                                       AND DriverId = @DriverId
                                       AND ResultId <> @ResultId)
        BEGIN
            THROW 50001, 'Driver already has a result in this race', 2;
        END

    -- Perform update
    UPDATE Result
    SET RaceId          = @RaceId,
        DriverId        = @DriverId,
        ConstructorId   = @ConstructorId,
        ResultNumber    = @ResultNumber,
        Grid            = @Grid,
        Position        = @Position,
        PositionText    = @PositionText,
        PositionOrder   = @PositionOrder,
        Points          = @Points,
        Laps            = @Laps,
        Time            = @Time,
        Milliseconds    = @Milliseconds,
        FastestLap      = @FastestLap,
        Rank            = @Rank,
        FastestLapTime  = @FastestLapTime,
        FastestLapSpeed = @FastestLapSpeed,
        ResultStatusId  = @ResultStatusId
    WHERE ResultId = @ResultId;
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Two different drivers in same race (after 1979)
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test01: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

PRINT 'Test01: inserting driver 900000'
EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

PRINT 'Test01: inserting driver 900001 (different driver, should succeed)'
EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 2;

PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Same driver allowed multiple results before 1979
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test02: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (1600, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 1600, 1, 900000, 'Test race', '1600-03-02')

PRINT 'Test02: inserting first result'
EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

PRINT 'Test02: inserting second result with SAME driver (allowed pre-1979)'
EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900000, @Position = 2;

PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should fail) - Same driver twice in same race after 1979
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

BEGIN TRY

    INSERT INTO Circuit(CircuitId) VALUES (900000)

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

    PRINT 'Test03: first insert (driver 900000)'
    EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

    PRINT 'Test03: second insert SAME DRIVER (should fail)'
    EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900000, @Position = 2;

    THROW 50001, 'Test failed: expected exception not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test03: expected exception occurred'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Update driver to a different race entry (no conflict)
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test04: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;
EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 2;

PRINT 'Test04: updating result (same driver, same race entry allowed)'
EXEC UpdateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 3;

PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Update to duplicate driver in same race
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test05: performing'

BEGIN TRY

    INSERT INTO Circuit(CircuitId) VALUES (900000)

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

    EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;
    EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 2;

    PRINT 'Test05: forcing duplicate driver via update (should fail)'
    EXEC UpdateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900000, @Position = 2;

    THROW 50001, 'Test failed: expected exception not thrown', 1

END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Update same driver entry (no duplication)
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test06: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

PRINT 'Test06: updating same driver record (valid)'
EXEC UpdateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

PRINT 'Test06: succeeded'
ROLLBACK
GO