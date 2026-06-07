CREATE OR ALTER PROCEDURE usp_99_Load_FactJobPostings
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    -- =========================================================================
    -- 1. PRZYGOTOWANIE DANYCH (Tabela Tymczasowa dla wydajności)
    -- =========================================================================
    IF OBJECT_ID('tempdb..#DeduplicatedJobs') IS NOT NULL DROP TABLE #DeduplicatedJobs;

    SELECT *
    INTO #DeduplicatedJobs
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER(PARTITION BY job_id ORDER BY created_at DESC) as rn
        FROM stg_parsed_jobs
    ) t
    WHERE rn = 1;

    -- =========================================================================
    -- 2. AKTUALIZACJA STATUSU OFERT (is_active)
    -- =========================================================================

    -- A. Dezaktywacja
    UPDATE f
    SET is_active = 0
    FROM fact_job_postings f
    WHERE f.is_active = 1
    AND NOT EXISTS (
        SELECT 1 FROM #DeduplicatedJobs p WHERE p.job_id = f.job_id
    );

    -- B. Reaktywacja
    UPDATE f
    SET is_active = 1
    FROM fact_job_postings f
    WHERE f.is_active = 0
    AND EXISTS (
        SELECT 1 FROM #DeduplicatedJobs p WHERE p.job_id = f.job_id
    );
    -- =========================================================================
    -- 4. ŁADOWANIE NOWYCH FAKTÓW
    -- =========================================================================

    WITH UniqueCityRates AS (
        SELECT DISTINCT City, Exchange_Rate
        FROM stg_education_costs
        WHERE City IS NOT NULL
    ),
    
    JoinedData AS (
        SELECT 
            p.job_id,
            p.title,
            dt.TeritoryID AS location,
            da.ContractTypeID AS contract_attributes,
            
            CAST((p.salary_min / ISNULL(sec.Exchange_Rate, 1.0)) AS INT) AS salary_min,
            CAST(((p.salary_min + p.salary_max) / 2 / ISNULL(sec.Exchange_Rate, 1.0)) AS INT) AS salary_mean,
            CAST((p.salary_max / ISNULL(sec.Exchange_Rate, 1.0)) AS INT) AS salary_max,
            
            p.redirect_url AS url,
            dcomp.CompaniesID AS company, 
            dd.DateID AS created_at,
            1 AS is_active,
            dc.CurrencyID,
            
            ROW_NUMBER() OVER(PARTITION BY p.job_id ORDER BY dt.TeritoryID DESC) as final_rn
            
        FROM #DeduplicatedJobs p
        LEFT JOIN UniqueCityRates sec ON p.SourceFileName LIKE '%' + sec.City + '%'
        LEFT JOIN DimTerritory dt ON dt.City = sec.City AND dt.IsCurrent = 1
        LEFT JOIN DimCompanies dcomp ON dcomp.CompanyName = p.company_name AND dcomp.IsCurrent = 1
        LEFT JOIN DimAtributes da ON ISNULL(da.ContractTime, '') = ISNULL(p.contract_time, '') AND ISNULL(da.JobCategory, '') = ISNULL(p.category_label, '') AND da.IsCurrent = 1
        LEFT JOIN DimDate dd ON dd.DateID = TRY_CAST(REPLACE(LEFT(p.created_at, 10), '-', '') AS INT)
        LEFT JOIN DimCurrency dc ON dc.Money = sec.Exchange_Rate AND dc.IsCurrent = 1
    )

    INSERT INTO fact_job_postings (
        job_id, title, location, contract_attributes, 
        salary_min, salary_mean, salary_max, url, company, created_at, is_active, CurrencyID
    )
    SELECT 
        job_id, 
        title, 
        location, 
        contract_attributes, 
        salary_min, 
        salary_mean, 
        salary_max, 
        url, 
        company, 
        created_at, 
        is_active,
        CurrencyID
    FROM JoinedData
    WHERE final_rn = 1 
      AND NOT EXISTS (
        SELECT 1 FROM fact_job_postings f WHERE f.job_id = JoinedData.job_id
    );

    -- Sprzątanie
    DROP TABLE #DeduplicatedJobs;
END;
GO