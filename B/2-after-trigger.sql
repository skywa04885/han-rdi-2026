-- Create the trigger that checks for duplicate DriverId per Race.
CREATE OR ALTER TRIGGER ResultDuplicateDriverTrigger
    ON Result
    AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variable for duplicate info
    DECLARE @DuplicateInfo NVARCHAR(500);

    -- Detect duplicate DriverId within the same Race (only for races from 1979 onwards)
    SELECT TOP 1
        @DuplicateInfo = CONCAT(
            'Duplicate driver detected: RaceId = ', CAST(r.RaceId AS NVARCHAR(20)),
            ', DriverId = ', CAST(r.DriverId AS NVARCHAR(20)),
            ', Count = ', CAST(COUNT(1) AS NVARCHAR(20))
        )
    FROM Result r
    INNER JOIN Race ra ON ra.RaceId = r.RaceId
    WHERE ra.RaceYear >= 1979
      AND r.RaceId IN (SELECT RaceId FROM inserted)
      AND r.DriverId IN (SELECT DriverId FROM inserted)
    GROUP BY r.RaceId, r.DriverId
    HAVING COUNT(1) > 1;

    -- Throw error if duplicate detected
    IF @DuplicateInfo IS NOT NULL
    BEGIN
        THROW 50001, @DuplicateInfo, 1;
    END
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should succeed) - Insert two results for same race with different drivers, after year 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test01: performing'

PRINT 'Test01: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000);

PRINT 'Test01: creating test drivers'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001);

PRINT 'Test01: creating test season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com');

PRINT 'Test01: creating test race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02');

PRINT 'Test01: inserting first result'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1);

PRINT 'Test01: inserting second result (different driver)'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900001, 900000, 900001, 2);

PRINT 'Test01: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Duplicate DriverId allowed before 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test02: performing'

PRINT 'Test02: creating test circuit'
INSERT INTO Circuit(CircuitId)
VALUES (900000);

PRINT 'Test02: creating test drivers'
INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001);

PRINT 'Test02: creating old season'
INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (1600, 'https://example.com');

PRINT 'Test02: creating old race'
INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 1600, 1, 900000, 'Test race', '1600-03-02');

PRINT 'Test02: inserting first result'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1);

PRINT 'Test02: inserting duplicate driver (allowed pre-1979)'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900001, 900000, 900000, 2);

PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should fail) - Duplicate DriverId after 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

BEGIN TRY

    PRINT 'Test03: creating test data'
    INSERT INTO Circuit(CircuitId) VALUES (900000);

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001);

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com');

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02');

    PRINT 'Test03: inserting first result'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1);

    PRINT 'Test03: inserting duplicate driver (should fail)'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900001, 900000, 900000, 2);

    THROW 50001, 'Test failed: expected exception not thrown', 1;

END TRY
BEGIN CATCH
    PRINT 'Test03: expected exception occurred';
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should succeed) - Batch insert duplicates before 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test04: performing'

INSERT INTO Circuit(CircuitId) VALUES (900000);

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001);

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (1600, 'https://example.com');

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 1600, 1, 900000, 'Test race', '1600-03-02');

PRINT 'Test04: batch insert same driver allowed pre-1979'
INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1),
       (900001, 900000, 900000, 2);

PRINT 'Test04: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should fail) - Batch insert duplicate DriverId after 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test05: performing'

BEGIN TRY

    INSERT INTO Circuit(CircuitId) VALUES (900000);

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001);

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com');

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02');

    PRINT 'Test05: batch insert duplicate driver (should fail)'
    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1),
           (900001, 900000, 900000, 2);

    THROW 50001, 'Test failed: expected exception not thrown', 1;

END TRY
BEGIN CATCH
    PRINT 'Test05: expected exception occurred';
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test06 (Should succeed) - Update result to a new unique DriverId.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test06: performing'

INSERT INTO Circuit(CircuitId) VALUES (900000);

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001),
       (900002);

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (2030, 'https://example.com');

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02');

INSERT INTO Result(ResultId, RaceId, DriverId, Position)
VALUES (900000, 900000, 900000, 1),
       (900001, 900000, 900001, 2);

PRINT 'Test06: updating driver to unique value'
UPDATE Result
SET DriverId = 900002
WHERE ResultId = 900001;

PRINT 'Test06: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test07 (Should fail) - Update creates duplicate DriverId after 1979.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test07: performing'

BEGIN TRY

    INSERT INTO Circuit(CircuitId) VALUES (900000);

    INSERT INTO Driver(DriverId)
    VALUES (900000),
           (900001);

    INSERT INTO Season(RaceYear, SeasonUrl)
    VALUES (2030, 'https://example.com');

    INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
    VALUES (900000, 2030, 1, 900000, 'Test race', '2030-03-02');

    INSERT INTO Result(ResultId, RaceId, DriverId, Position)
    VALUES (900000, 900000, 900000, 1),
           (900001, 900000, 900001, 2);

    PRINT 'Test07: updating to duplicate driver (should fail)'
    UPDATE Result
    SET DriverId = 900000
    WHERE ResultId = 900001;

    THROW 50001, 'Test failed: expected exception not thrown', 1;

END TRY
BEGIN CATCH
    PRINT 'Test07: expected exception occurred';
END CATCH

ROLLBACK
GO