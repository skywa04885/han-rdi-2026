-- Option 1 (could not find an alternative).
SELECT CONCAT_WS(' ', Driver.Firstname, Driver.Lastname) AS Coureur
     , DriverYearRanges.Ranges                           AS Periodes
FROM Driver
         INNER JOIN DriverYearRanges ON DriverYearRanges.DriverId = Driver.DriverId
ORDER BY Coureur;
