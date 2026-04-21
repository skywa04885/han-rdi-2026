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

    -- If the season equals or is after 1962, make sure the position is still available.
    IF @RaceYear >= 1962 AND EXISTS(SELECT 1 FROM Result WHERE RaceId = @RaceId AND Position = @Position)
        BEGIN
            THROW 50001, 'Position is already occupied in race', 2
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

    -- Enforce position uniqueness after 1962 (excluding itself!)
    IF @RaceYear >= 1962 AND EXISTS (
        SELECT 1
        FROM Result
        WHERE RaceId = @RaceId
          AND Position = @Position
          AND ResultId <> @ResultId
    )
    BEGIN
        THROW 50001, 'Position is already occupied in race', 2;
    END

    -- Perform update
    UPDATE Result
    SET RaceId = @RaceId,
        DriverId = @DriverId,
        ConstructorId = @ConstructorId,
        ResultNumber = @ResultNumber,
        Grid = @Grid,
        Position = @Position,
        PositionText = @PositionText,
        PositionOrder = @PositionOrder,
        Points = @Points,
        Laps = @Laps,
        Time = @Time,
        Milliseconds = @Milliseconds,
        FastestLap = @FastestLap,
        Rank = @Rank,
        FastestLapTime = @FastestLapTime,
        FastestLapSpeed = @FastestLapSpeed,
        ResultStatusId = @ResultStatusId
    WHERE ResultId = @ResultId;
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Insert two results for the same race with different positions, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the first test.
BEGIN TRANSACTION
PRINT 'Test01: performing'

-- Create the test circuit.
PRINT 'Test01: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create the test drivers.
PRINT 'Test01: creating test driver'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

-- Create the test season.
PRINT 'Test01: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

-- Create the test race.
PRINT 'Test01: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '02-03-2030')

-- Create the first result at position 1.
PRINT 'Test01: inserting first position'
EXECUTE CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

-- Create the second result at position 2 (should work due to no conflict).
PRINT 'Test01: inserting second position'
EXECUTE CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900000, @Position = 2;

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Insert two results for the same race with same position, before year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the second test.
BEGIN TRANSACTION
PRINT 'Test02: performing'

-- Create the test circuit.
PRINT 'Test02: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create the test drivers.
PRINT 'Test02: creating test driver'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

-- Create the test season.
PRINT 'Test02: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (1600, 'https://example.com')

-- Create the test race.
PRINT 'Test02: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 1600, 1, 900000, 'Test race', '02-03-1600')

-- Create the first result at position 1.
PRINT 'Test02: inserting first result for first position'
EXECUTE CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

-- Create the second result at position 1 (should work due to the fact its before 1962).
PRINT 'Test02: inserting second result for first position'
EXECUTE CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900000, @Position = 1;

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should fail) - Insert two results for the same race with same position, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the second test.
BEGIN TRANSACTION
PRINT 'Test03: performing'

BEGIN TRY
    -- Create the test circuit.
    PRINT 'Test03: creating test circuit'
    INSERT INTO Circuit(CircuitId)
    VALUES (900000)

    -- Create the test drivers.
    PRINT 'Test03: creating test driver'
    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    -- Create the test season.
    PRINT 'Test03: creating test season'
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    -- Create the test race.
    PRINT 'Test03: creating test race'
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

    -- First insert (expected to succeed)
    PRINT 'Test03: inserting first result for first position'
    EXEC CreateResultProcedure
         @ResultId = 900000,
         @RaceId = 900000,
         @DriverId = 900000,
         @Position = 1;

    -- Second insert (EXPECTED to fail)
    PRINT 'Test03: inserting second result for first position'

    EXEC CreateResultProcedure
         @ResultId = 900001,
         @RaceId = 900000,
         @DriverId = 900000,
         @Position = 1;

    -- If we reach here, the test failed (no exception thrown)
    THROW 50001, 'Test failed: expected exception was not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test03: expected exception occurred'
    PRINT 'Test03: succeeded (exception was expected)'
END CATCH

-- Always rollback test data
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Update a result to a free position, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the fourth test.
BEGIN TRANSACTION
PRINT 'Test04: performing'

-- Create the test circuit.
PRINT 'Test04: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create the test drivers.
PRINT 'Test04: creating test driver'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

-- Create the test season.
PRINT 'Test04: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

-- Create the test race.
PRINT 'Test04: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

-- Create two results with different positions.
PRINT 'Test04: inserting initial results'
EXECUTE CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;
EXECUTE CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 2;

-- Update second result to a free position (should succeed).
PRINT 'Test04: updating to free position'
EXECUTE UpdateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 3;

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Update a result to an already occupied position, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the fifth test.
BEGIN TRANSACTION
PRINT 'Test05: performing'

BEGIN TRY
    -- Create the test circuit.
    PRINT 'Test05: creating test circuit'
    INSERT INTO Circuit(CircuitId)
    VALUES (900000)

    -- Create the test drivers.
    PRINT 'Test05: creating test driver'
    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    -- Create the test season.
    PRINT 'Test05: creating test season'
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    -- Create the test race.
    PRINT 'Test05: creating test race'
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

    -- Create two results with different positions.
    PRINT 'Test05: inserting initial results'
    EXECUTE CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;
    EXECUTE CreateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 2;

    -- Attempt to update to an occupied position (should fail).
    PRINT 'Test05: updating to occupied position'
    EXECUTE UpdateResultProcedure @ResultId = 900001, @RaceId = 900000, @DriverId = 900001, @Position = 1;

    -- If we reach here, the test failed.
    THROW 50001, 'Test failed: expected exception was not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred'
    PRINT 'Test05: succeeded (exception was expected)'
END CATCH

-- Always rollback test data.
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Update a result keeping the same position (no conflict), after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the sixth test.
BEGIN TRANSACTION
PRINT 'Test06: performing'

-- Create the test circuit.
PRINT 'Test06: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create the test driver.
PRINT 'Test06: creating test driver'
INSERT INTO Driver(DriverId)
VALUES (900000)

-- Create the test season.
PRINT 'Test06: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

-- Create the test race.
PRINT 'Test06: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

-- Create a result at position 1.
PRINT 'Test06: inserting initial result'
EXECUTE CreateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

-- Update the result with the same position (should succeed).
PRINT 'Test06: updating with same position'
EXECUTE UpdateResultProcedure @ResultId = 900000, @RaceId = 900000, @DriverId = 900000, @Position = 1;

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test06: succeeded'
ROLLBACK
GO