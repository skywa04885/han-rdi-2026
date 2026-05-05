create index Result_RaceId_index
    on dbo.Result (RaceId, DriverId) include (Laps)
go

create index DriverStanding_RaceId_index
    on dbo.DriverStanding (RaceId) include (DriverId, Points, Position)
go

create index Result_RaceId_FastestLapTime_index
    on dbo.Result (RaceId, FastestLapTime) include (DriverId, PositionText,
        Points, Laps, FastestLap, ResultStatusId)
go
