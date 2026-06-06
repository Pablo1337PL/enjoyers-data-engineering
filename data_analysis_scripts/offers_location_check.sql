SELECT 
    COUNT(*) AS CalkowitaLiczbaRekordow,

    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) AS LiczbaNieprzypisanychMiast,

    CAST(
        SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS ProcentBrakow
FROM fact_job_postings;