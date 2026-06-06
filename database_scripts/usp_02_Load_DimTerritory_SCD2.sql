CREATE OR ALTER PROCEDURE usp_02_Load_DimTerritory_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    IF OBJECT_ID('tempdb..#SourceData') IS NOT NULL DROP TABLE #SourceData;
    
    -- Wyliczamy średnie współrzędne z ofert pracy
    WITH CityCoordinates AS (
        SELECT 
            sec.City,
            ROUND(AVG(pj.latitude), 3) AS AvgLatitude,
            ROUND(AVG(pj.longitude), 3) AS AvgLongitude
        FROM stg_education_costs sec
        JOIN stg_parsed_jobs pj ON pj.SourceFileName LIKE '%' + sec.City + '%'
        WHERE pj.latitude IS NOT NULL AND pj.longitude IS NOT NULL
        GROUP BY sec.City
    ),
    -- Wyliczamy jeden, uśredniony Living Cost Index dla miasta
    AggregatedSource AS (
        SELECT 
            Country, 
            City, 
            ROUND(AVG(Living_Cost_Index), 2) AS Living_Cost_Index
        FROM stg_education_costs
        WHERE City IS NOT NULL
        GROUP BY Country, City
    )
    
    -- Łączymy uśrednione koszty z uśrednionymi współrzędnymi
    SELECT 
        sec.Country, 
        sec.City, 
        sec.Living_Cost_Index,
        cc.AvgLatitude AS Latitude,
        cc.AvgLongitude AS Longitude
    INTO #SourceData
    FROM AggregatedSource sec
    LEFT JOIN CityCoordinates cc ON sec.City = cc.City;
    
    -- ==========================================
    -- LOGIKA SCD 1 i 2
    -- ==========================================

    UPDATE target
    SET target.Latitude = source.Latitude,
        target.Longitude = source.Longitude
    FROM DimTerritory target
    JOIN #SourceData source ON target.Country = source.Country AND target.City = source.City
    WHERE target.IsCurrent = 1 
      AND (
          ISNULL(target.Latitude, -999) <> ISNULL(source.Latitude, -999)
          OR ISNULL(target.Longitude, -999) <> ISNULL(source.Longitude, -999)
      )
      AND ISNULL(target.LivingCostIndex, -1) = ISNULL(source.Living_Cost_Index, -1);

    UPDATE target
    SET target.IsCurrent = 0, target.ValidTo = @CurrentDate
    FROM DimTerritory target
    JOIN #SourceData source ON target.Country = source.Country AND target.City = source.City
    WHERE target.IsCurrent = 1 
      AND ISNULL(target.LivingCostIndex, -1) <> ISNULL(source.Living_Cost_Index, -1);

    INSERT INTO DimTerritory (Country, City, LivingCostIndex, Latitude, Longitude, ValidFrom, ValidTo, IsCurrent)
    SELECT 
        s.Country, 
        s.City, 
        s.Living_Cost_Index, 
        s.Latitude,
        s.Longitude,
        @CurrentDate, 
        NULL, 
        1
    FROM #SourceData s
    WHERE NOT EXISTS (
        SELECT 1 FROM DimTerritory t 
        WHERE t.Country = s.Country 
          AND t.City = s.City 
          AND t.IsCurrent = 1
    );

    DROP TABLE #SourceData;
END;
GO