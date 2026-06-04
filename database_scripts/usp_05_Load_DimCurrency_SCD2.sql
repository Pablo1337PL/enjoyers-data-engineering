-- PROCEDURA: Waluty (Koszty życia z pliku CSV)
CREATE PROCEDURE usp_05_Load_DimCurrency_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    WITH SourceData AS (
        SELECT DISTINCT Exchange_Rate FROM stg_education_costs WHERE Exchange_Rate IS NOT NULL
    )
    INSERT INTO DimCurrency (Money, CurrencyCode, ValidFrom, ValidTo, IsCurrent)
    SELECT s.Exchange_Rate, 'Local', @CurrentDate, NULL, 1
    FROM SourceData s
    WHERE NOT EXISTS (
        SELECT 1 FROM DimCurrency t WHERE t.Money = s.Exchange_Rate AND t.IsCurrent = 1
    );
END;