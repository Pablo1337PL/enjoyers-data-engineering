-- PROCEDURA: Atrybuty Umowy (z API Adzuny)
CREATE PROCEDURE usp_04_Load_DimAtributes_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    WITH SourceData AS (
        SELECT DISTINCT contract_time, category_label 
        FROM stg_parsed_jobs 
        WHERE contract_time IS NOT NULL OR category_label IS NOT NULL
    )
    INSERT INTO DimAtributes (ContractTypeName, ContractTime, JobCategory, ValidFrom, ValidTo, IsCurrent)
    SELECT 'Dane z API', contract_time, category_label, @CurrentDate, NULL, 1
    FROM SourceData s
    WHERE NOT EXISTS (
        SELECT 1 FROM DimAtributes t 
        WHERE t.ContractTime = s.contract_time AND t.JobCategory = s.category_label AND t.IsCurrent = 1
    );
END;