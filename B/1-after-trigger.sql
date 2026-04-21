-- Create the trigger that checks for duplicates.
CREATE OR ALTER TRIGGER ResultDuplicatePositionTrigger
    ON Result
    AFTER INSERT, UPDATE
    AS
BEGIN
    SET NOCOUNT ON

    -- Declare the variable that will contain the info about the duplicates.
    DECLARE @DuplicateInfo NVARCHAR(500)

    -- Select the first duplicate that was capable of being detected.
    SELECT TOP 1 @DuplicateInfo = CONCAT('Duplicate position detected: RaceId = ', CAST(Result.RaceId AS NVARCHAR(20)),
                                         ', Position = ', CAST(Result.Position AS NVARCHAR(20)),
                                         ', Count = ', CAST(COUNT(1) AS NVARCHAR(20)))
    FROM Result
             INNER JOIN Race ON Race.RaceId = Result.RaceId
    WHERE Result.Position IS NOT NULL
      AND Race.RaceYear >= 1962
      AND Result.RaceId IN (SELECT RaceId FROM inserted)
    GROUP BY Result.RaceId, Result.Position
    HAVING COUNT(1) > 1

    -- Throw an error if there is a duplicate detected.
    IF @DuplicateInfo IS NOT NULL
        BEGIN
            THROW 50001, @DuplicateInfo, 1
        END
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Insert two results for the same race with different positions, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
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
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1);

-- Create the second result at position 2 (should work due to no conflict).
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900001, 900000, 900001, 2);

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Insert two results for the same race with same position, before year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
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
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1);

-- Create the second result at position 1 (should work due to the fact its before 1962).
PRINT 'Test02: inserting second result for first position'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900001, 900000, 900001, 1);

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should fail) - Insert two results for the same race with same position, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
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
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1);

    -- Second insert (EXPECTED to fail)
    PRINT 'Test03: inserting second result for first position'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900001, 900000, 900001, 1);

    -- If we reach here, the test failed (no exception thrown)
    THROW 50001, 'Test failed: expected exception was not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test03: expected exception occurred'
    PRINT 'Test03: succeeded (conflict was expected)'
END CATCH

-- Always rollback test data
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Insert two results at once for the same race with same position, before year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
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
VALUES (1600, 'https://example.com')

-- Create the test race.
PRINT 'Test04: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 1600, 1, 900000, 'Test race', '02-03-1600')

-- Create the results.
PRINT 'Test04: inserting results'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1),
       (900001, 900000, 900001, 1)

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Insert two results at once for the same race with same position, after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
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

    -- Inserting the results
    PRINT 'Test05: inserting the results'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1),
           (900001, 900000, 900001, 1);

    -- If we reach here, the test failed (no exception thrown)
    THROW 50001, 'Test failed: expected exception was not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred'
    PRINT 'Test05: succeeded (conflict was expected)'
END CATCH

-- Always rollback test data
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Update a result to a new unique position (no conflict), after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
BEGIN TRANSACTION
PRINT 'Test06: performing'

-- Create the test circuit.
PRINT 'Test06: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000)

-- Create the test drivers.
PRINT 'Test06: creating test driver'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

-- Create the test season.
PRINT 'Test06: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com')

-- Create the test race.
PRINT 'Test06: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

-- Insert initial results.
PRINT 'Test06: inserting initial results'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1),
       (900001, 900000, 900001, 2);

-- Update second result to a new non-conflicting position.
PRINT 'Test06: updating position (no conflict expected)'
UPDATE Result
SET Position = 3
WHERE ResultId = 900001;

-- The test was successful, perform rollback to prevent persisting test data.
PRINT 'Test06: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test07 (Should fail) - Update a result to a duplicate position (conflict introduced), after year 1962.
------------------------------------------------------------------------------------------------------------------------

-- Begin the transaction of the test.
BEGIN TRANSACTION
PRINT 'Test07: performing'

BEGIN TRY
    -- Create the test circuit.
    PRINT 'Test07: creating test circuit'
    INSERT INTO Circuit(CircuitId)
    VALUES (900000)

    -- Create the test drivers.
    PRINT 'Test07: creating test driver'
    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001)

    -- Create the test season.
    PRINT 'Test07: creating test season'
    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com')

    -- Create the test race.
    PRINT 'Test07: creating test race'
    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02')

    -- Insert initial results.
    PRINT 'Test07: inserting initial results'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1),
           (900001, 900000, 900001, 2);

    -- Update second result to conflicting position.
    PRINT 'Test07: updating position to duplicate (should fail)'
    UPDATE Result
    SET Position = 1
    WHERE ResultId = 900001;

    -- If we reach here, the test failed (no exception thrown)
    THROW 50001, 'Test failed: expected exception was not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test07: expected exception occurred'
    PRINT 'Test07: succeeded (conflict was expected)'
END CATCH

-- Always rollback test data
ROLLBACK
GO