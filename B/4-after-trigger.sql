-- Create the trigger
CREATE OR ALTER TRIGGER ResultNumberDriverTrigger
    ON Result
    AFTER INSERT, UPDATE
    AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted
                        INNER JOIN Race ON Race.RaceId = inserted.RaceId
                        INNER JOIN Result ON Result.ResultNumber = inserted.ResultNumber
                   AND Result.DriverId <> inserted.DriverId
                        INNER JOIN Race AS RaceResult ON RaceResult.RaceId = Result.RaceId
                   AND RaceResult.RaceYear = Race.RaceYear
               WHERE Race.RaceYear >= 2014
                 AND inserted.ResultNumber IS NOT NULL)
        BEGIN
            THROW 50001, 'ResultNumber already used by another driver in this season', 1;
        END
END
GO

------------------------------------------------------------------------------------------------------------------------
-- Test00 (Should succeed) - Same driver, same number, same season.
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

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900000, 900000, 900000, 44)

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900001, 900001, 900000, 44)

PRINT 'Test00: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test01 (Should fail) - Same number, different drivers, same season.
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

    INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
    VALUES (900000, 900000, 900000, 44)

    INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
    VALUES (900001, 900001, 900001, 44);

    THROW 50001, 'Test failed: expected exception not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test01: expected exception occurred'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test02 (Should succeed) - Same number, different drivers, different seasons.
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

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900000, 900000, 900000, 44)

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900001, 900001, 900001, 44)

PRINT 'Test02: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test03 (Should succeed) - Same number, different drivers, before 2014.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test03: performing'

INSERT INTO Circuit(CircuitId)
VALUES (900000)

INSERT INTO Driver(DriverId)
VALUES (900000),
       (900001)

INSERT INTO Season(RaceYear, SeasonUrl)
VALUES (1700, 'https://example.com')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900000, 2000, 1, 900000, 'Race1', '1700-03-01')

INSERT INTO Race(RaceId, RaceYear, NrOfRound, CircuitId, RaceName, RaceDate)
VALUES (900001, 2000, 2, 900000, 'Race2', '1700-03-02')

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900000, 900000, 900000, 44)

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900001, 900001, 900001, 44)

PRINT 'Test03: succeeded'
ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test04 (Should fail) - Update causes conflict.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test04: performing'

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

    INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
    VALUES (900000, 900000, 900000, 44)

    INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
    VALUES (900001, 900001, 900001, 33)

    UPDATE Result
    SET ResultNumber = 44
    WHERE ResultId = 900001;

    THROW 50001, 'Test failed: expected exception not thrown', 1
END TRY
BEGIN CATCH
    PRINT 'Test04: expected exception occurred'
END CATCH

ROLLBACK
GO

------------------------------------------------------------------------------------------------------------------------
-- Test05 (Should succeed) - Update to unique ResultNumber.
------------------------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION
PRINT 'Test05: performing'

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

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900000, 900000, 900000, 44)

INSERT INTO Result(ResultId, RaceId, DriverId, ResultNumber)
VALUES (900001, 900001, 900001, 33)

UPDATE Result
SET ResultNumber = 55
WHERE ResultId = 900001

PRINT 'Test05: succeeded'
ROLLBACK
GO