CREATE PROCEDURE usp_03_Load_DimCompanies_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    CREATE PROCEDURE usp_03_Load_DimCompanies_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    WITH SourceData AS (
        SELECT DISTINCT company_name FROM stg_parsed_jobs WHERE company_name IS NOT NULL
    )
    
    INSERT INTO DimCompanies (CompanyName, ValidFrom, ValidTo, IsCurrent)
    SELECT s.company_name, @CurrentDate, NULL, 1
    FROM SourceData s

    WHERE NOT EXISTS (
        SELECT 1 FROM DimCompanies t 
        WHERE t.CompanyName = s.company_name AND t.IsCurrent = 1
    );
END;
