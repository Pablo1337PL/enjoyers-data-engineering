SELECT job_id, title, 'Brak mapowania waluty' AS TypBledu
FROM fact_job_postings
WHERE CurrencyID IS NULL;