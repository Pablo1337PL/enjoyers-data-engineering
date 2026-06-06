SELECT 
    COUNT(f.job_id) AS CalkowitaLiczbaOfert,

    SUM(CASE WHEN da.ContractTime IS NULL THEN 1 ELSE 0 END) AS OfertBezCzasuPracy,

    CAST(
        SUM(CASE WHEN da.ContractTime IS NULL THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(f.job_id), 0) 
    AS DECIMAL(5,2)) AS ProcentBrakowCzasuPracy
FROM fact_job_postings f
LEFT JOIN DimAtributes da ON f.contract_attributes = da.ContractTypeID
WHERE f.is_active = 1;