SELECT job_id, title, salary_min, salary_max, 'Błąd logiki widełek' AS TypBledu
FROM fact_job_postings
WHERE salary_min > salary_max;

SELECT 
    COUNT(*) AS CalkowitaLiczbaOfert,
    
    -- Liczymy oferty ze stawką godzinową/dzienną (zakładamy poniżej 500 USD)
    SUM(CASE WHEN salary_mean > 0 AND salary_mean < 500 THEN 1 ELSE 0 END) AS PodejrzaneGodzinowe,
    
    -- Liczymy oferty ze stawką miesięczną (zakładamy od 500 do 10 000 USD)
    SUM(CASE WHEN salary_mean >= 500 AND salary_mean < 10000 THEN 1 ELSE 0 END) AS PodejrzaneMiesieczne,
    
    -- Łączny procent błędnych ofert (wszystko poniżej 10k)
    CAST(
        SUM(CASE WHEN salary_mean > 0 AND salary_mean < 10000 THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS ProcentBledow
FROM fact_job_postings
WHERE salary_mean IS NOT NULL;