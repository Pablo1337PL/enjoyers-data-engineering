CREATE PROCEDURE usp_01_Parse_JSON_To_Staging
AS
BEGIN
    SET NOCOUNT ON;
    
    TRUNCATE TABLE stg_parsed_jobs;

    INSERT INTO stg_parsed_jobs
    SELECT 
        job.job_id,
        job.title,
        job.company_name,
        job.salary_min,
        job.salary_max,
        job.contract_time,
        job.category_label,
        job.latitude,
        job.longitude,
        job.created_at,
        job.redirect_url,
        SUBSTRING(stg.SourceFileName, 1, CHARINDEX('_', stg.SourceFileName) - 1) AS country_code,
        stg.SourceFileName,
        stg.LoadDate
    FROM (
        -- [ZMIANA KLUCZOWA]: Podzapytanie izolujące TYLKO poprawne JSONy
        SELECT SourceFileName, LoadDate, RawJsonData
        FROM stg_job_postings
        WHERE ISJSON(RawJsonData) = 1
    ) stg
    CROSS APPLY OPENJSON(stg.RawJsonData, '$.results')
    WITH (
        job_id BIGINT '$.id',
        title NVARCHAR(255) '$.title',
        company_name NVARCHAR(255) '$.company.display_name',
        salary_min FLOAT '$.salary_min',
        salary_max FLOAT '$.salary_max',
        contract_time VARCHAR(255) '$.contract_time',
        category_label VARCHAR(255) '$.category.label',
        latitude FLOAT '$.latitude',
        longitude FLOAT '$.longitude',
        created_at DATETIME2 '$.created',
        redirect_url NVARCHAR(1000) '$.redirect_url'
    ) AS job
    WHERE job.salary_min IS NOT NULL AND job.salary_max IS NOT NULL;
END;