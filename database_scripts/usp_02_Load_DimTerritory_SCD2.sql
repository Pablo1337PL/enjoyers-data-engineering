CREATE PROCEDURE usp_02_Load_DimTerritory_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    -- A. Zabezpieczenie unikalnych danych do TABELI TYMCZASOWEJ (#SourceData)
    -- Usuwamy ją, jeśli z jakiegoś powodu została z poprzedniego uruchomienia
    IF OBJECT_ID('tempdb..#SourceData') IS NOT NULL DROP TABLE #SourceData;
    
    SELECT DISTINCT 
        Country, 
        City, 
        Living_Cost_Index
    INTO #SourceData  -- <--- Tworzy tabelę tymczasową w locie
    FROM stg_education_costs;
    
    -- B. Zakończenie "życia" starych rekordów, jeśli zmienił się np. koszt życia
    UPDATE target
    SET target.IsCurrent = 0, target.ValidTo = @CurrentDate
    FROM DimTerritory target
    JOIN #SourceData source ON target.Country = source.Country AND target.City = source.City
    WHERE target.IsCurrent = 1 
      AND ISNULL(target.LivingCostIndex, -1) <> ISNULL(source.Living_Cost_Index, -1);

    -- C. Wstawienie nowych miast lub nowych wersji istniejących miast
    INSERT INTO DimTerritory (Country, City, LivingCostIndex, ValidFrom, ValidTo, IsCurrent)
    SELECT 
        s.Country, 
        s.City, 
        s.Living_Cost_Index, 
        @CurrentDate, 
        NULL, 
        1
    FROM #SourceData s
    WHERE NOT EXISTS (
        -- Nie wstawiaj, jeśli aktualna wersja jest identyczna z tą, która już istnieje
        SELECT 1 FROM DimTerritory t 
        WHERE t.Country = s.Country AND t.City = s.City AND t.IsCurrent = 1
    );

    -- D. Sprzątanie (dobra praktyka)
    DROP TABLE #SourceData;
END;
GO