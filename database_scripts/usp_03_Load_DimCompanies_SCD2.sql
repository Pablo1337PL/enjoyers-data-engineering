CREATE PROCEDURE usp_03_Load_DimCompanies_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    UPDATE dim
    SET 
        dim.ValidTo = @CurrentDate,
        dim.IsCurrent = 0
    FROM DimCompanies dim
    INNER JOIN (
        SELECT DISTINCT company_name, industry 
        FROM stg_parsed_jobs 
        WHERE company_name IS NOT NULL
    ) stg ON dim.CompanyName = stg.company_name
    WHERE dim.IsCurrent = 1 
      AND (dim.Industry <> stg.industry OR dim.Industry IS NULL AND stg.industry IS NOT NULL); 

    INSERT INTO DimCompanies (CompanyName, Industry, ValidFrom, ValidTo, IsCurrent)
    SELECT 
        stg.company_name, 
        stg.industry, 
        @CurrentDate, 
        NULL, 
        1
    FROM (
        SELECT DISTINCT company_name, industry 
        FROM stg_parsed_jobs 
        WHERE company_name IS NOT NULL
    ) stg
    WHERE NOT EXISTS (
        SELECT 1 
        FROM DimCompanies dim 
        WHERE dim.CompanyName = stg.company_name 
          AND dim.IsCurrent = 1
    );
END;