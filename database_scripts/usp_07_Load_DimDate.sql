-- PROCEDURA: Wymiar Daty (Generowany z dat ofert pracy)
CREATE PROCEDURE usp_07_Load_DimDate
AS
BEGIN
    SET NOCOUNT ON;
    WITH SourceData AS (
        SELECT DISTINCT CAST(created_at AS DATE) AS JobDate
        FROM stg_parsed_jobs WHERE created_at IS NOT NULL
    )
    INSERT INTO DimDate (DateID, Date)
    SELECT 
        CAST(FORMAT(JobDate, 'yyyyMMdd') AS BIGINT),
        CAST(JobDate AS VARCHAR(50))
    FROM SourceData s
    WHERE NOT EXISTS (
        SELECT 1 FROM DimDate d WHERE d.DateID = CAST(FORMAT(s.JobDate, 'yyyyMMdd') AS BIGINT)
    );
END;