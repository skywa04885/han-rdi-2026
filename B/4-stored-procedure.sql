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

    DECLARE @RaceYear INT = NULL

    SELECT @RaceYear = Race.RaceYear
    FROM Race
    WHERE Race.RaceId = @RaceId

    IF @RaceYear IS NULL
        BEGIN
            THROW 50001, 'Race does not exist', 1
        END

    IF @RaceYear >= 2014 AND @ResultNumber IS NOT NULL
        AND EXISTS (SELECT 1
                    FROM Result
                             JOIN Race ON Result.RaceId = Race.RaceId
                    WHERE Race.RaceYear = @RaceYear
                      AND Result.ResultNumber = @ResultNumber
                      AND Result.DriverId <> @DriverId)
        BEGIN
            THROW 50001, 'ResultNumber already used by another driver in this season', 2
        END

    INSERT INTO Result (ResultId, RaceId, DriverId, ConstructorId, ResultNumber, Grid, Position, PositionText,
                        PositionOrder, Points, Laps, Time, Milliseconds, FastestLap, Rank, FastestLapTime,
                        FastestLapSpeed, ResultStatusId)
    VALUES (@ResultId, @RaceId, @DriverId, @ConstructorId, @ResultNumber,
            @Grid, @Position, @PositionText, @PositionOrder, @Points,
            @Laps, @Time, @Milliseconds, @FastestLap, @Rank,
            @FastestLapTime, @FastestLapSpeed, @ResultStatusId)
END
GO

------------------------------------------------------------------------------------------------------------------------

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

    SELECT @RaceYear = RaceYear
    FROM Race
    WHERE RaceId = @RaceId;

    IF @RaceYear IS NULL
        BEGIN
            THROW 50001, 'Race does not exist', 1;
        END

    IF NOT EXISTS (SELECT 1 FROM Result WHERE ResultId = @ResultId)
        BEGIN
            THROW 50001, 'Result does not exist', 1;
        END

    -- From 2014 onward: ResultNumber must belong to only one driver per season (RaceYear).
    IF @RaceYear >= 2014 AND @ResultNumber IS NOT NULL
        AND EXISTS (SELECT 1
                    FROM Result
                             JOIN Race ON Result.RaceId = Race.RaceId
                    WHERE Race.RaceYear = @RaceYear
                      AND Result.ResultNumber = @ResultNumber
                      AND Result.DriverId <> @DriverId
                      AND Result.ResultId <> @ResultId)
        BEGIN
            THROW 50001, 'ResultNumber already used by another driver in this season', 2;
        END

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
-- Test00 (Should succeed) - Same driver, same number, same season
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test00: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Race1', '2030-03-01')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900001, 2030, 2, 900000, 'Race2', '2030-03-02')

EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @ResultNumber = 44
EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900001, @DriverId = 900000, @ResultNumber = 44

PRINT 'Test00: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should fail) - Same number, different drivers, same season
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test01: performing'

BEGIN TRY
    INSERT INTO Circuit(CircuitId)
    VALUES (900000)

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Race1', '2030-03-01')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900001, 2030, 2, 900000, 'Race2', '2030-03-02')

    EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @ResultNumber = 44
    EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900001, @DriverId = 900001, @ResultNumber = 44;

    THROW 50001, 'Test failed: expected exception not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test01: expected exception occurred'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Same number, different drivers, different seasons
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test02: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2031, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Race1', '2030-03-01')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900001, 2031, 1, 900000, 'Race2', '2031-03-01')

EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @ResultNumber = 44
EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900001, @DriverId = 900001, @ResultNumber = 44

PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should fail) - Update causes conflict
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

BEGIN TRY
    INSERT INTO Circuit(CircuitId)
    VALUES (900000)

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Race1', '2030-03-01')

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900001, 2030, 2, 900000, 'Race2', '2030-03-02')

    EXEC CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @ResultNumber = 44
    EXEC CreateResultProcedure @ResultId = 900001, @RaceId = 900001, @DriverId = 900001, @ResultNumber = 33

    EXEC UpdateResultProcedure @ResultId = 900002, @RaceId = 900001, @DriverId = 900001, @ResultNumber = 44;

    THROW 50001, 'Test failed: expected exception not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test03: expected exception occurred'
END CATCH

ROLLBACK
GO