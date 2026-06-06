SELECT 
    COUNT(*) AS CalkowitaLiczbaTerytoriow,
    SUM(CASE WHEN Latitude IS NULL OR Longitude IS NULL THEN 1 ELSE 0 END) AS LiczbaBrakow,
    CAST(
        SUM(CASE WHEN Latitude IS NULL OR Longitude IS NULL THEN 1 ELSE 0 END) * 100.0 
        / NULLIF(COUNT(*), 0) 
    AS DECIMAL(5,2)) AS ProcentBrakow
FROM DimTerritory;