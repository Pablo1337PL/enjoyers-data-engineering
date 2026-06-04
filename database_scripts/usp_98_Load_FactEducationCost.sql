-- PROCEDURA: Fakty Edukacyjne (Koszty życia z pliku CSV)
CREATE PROCEDURE usp_98_Load_FactEducationCost
AS
BEGIN
    SET NOCOUNT ON;

    -- Używamy tabeli tymczasowej lub CTE, aby zebrać klucze obce
    INSERT INTO fact_education_cost (
        University, location, Tuition_USD, Visa_Fee_USD, 
        Insurance_USD, Rent_USD, Exchange_Rate
    )
    SELECT 
        dm.UniversitiesID,
        dt.TeritoryID,
        ISNULL(s.Tuition_USD, 0),
        ISNULL(s.Visa_Fee_USD, 0),
        ISNULL(s.Insurance_USD, 0),
        ISNULL(s.Rent_USD, 0),
        dc.CurrencyID
    FROM stg_education_costs s
    LEFT JOIN DimMajor dm ON dm.UniversityName = s.University AND dm.Program = s.Program AND dm.IsCurrent = 1
    LEFT JOIN DimTerritory dt ON dt.City = s.City AND dt.Country = s.Country AND dt.IsCurrent = 1
    LEFT JOIN DimCurrency dc ON dc.Money = s.Exchange_Rate AND dc.IsCurrent = 1
    
    -- Zapobiega wielokrotnemu dublowaniu tych samych uczelni przy ponownym uruchomieniu potoku
    WHERE NOT EXISTS (
        SELECT 1 FROM fact_education_cost f 
        WHERE f.University = dm.UniversitiesID AND f.location = dt.TeritoryID
    );
END;