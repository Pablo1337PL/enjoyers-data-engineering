-- 1. Zrzucamy starą tabelę (upewnij się, że nie ma twardych kluczy obcych blokujących usunięcie,
-- jeśli są, usuń je najpierw komendą ALTER TABLE fact_job_postings DROP CONSTRAINT...)
DROP TABLE IF EXISTS DimDate;

-- 2. Tworzymy ostateczną, potężną strukturę tabeli DimDate
CREATE TABLE DimDate (
    DateID INT PRIMARY KEY,           -- Smart Key: np. 20260604
    [Date] DATE NOT NULL,             -- Prawdziwa data: '2026-06-04'
    [Year] INT NOT NULL,              -- 2026
    [Month] INT NOT NULL,             -- 6
    [Day] INT NOT NULL,               -- 4
    [Quarter] INT NOT NULL,           -- 2
    DayOfWeekNumber INT NOT NULL,     -- 1 do 7
    DayOfWeekName NVARCHAR(20) NOT NULL, -- np. 'Thursday'
    MonthName NVARCHAR(20) NOT NULL,  -- np. 'June'
    IsWeekend BIT NOT NULL            -- 0 (roboczy) lub 1 (weekend)
);
GO

-- 3. Generowanie danych z użyciem CTE (Rekurencji)
DECLARE @StartDate DATE = '2025-01-01';
DECLARE @EndDate DATE = '2027-12-31';

WITH DateGenerator AS (
    -- Wartość startowa
    SELECT @StartDate AS DateValue
    UNION ALL
    -- Dodajemy po jednym dniu aż dojdziemy do EndDate
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateGenerator
    WHERE DateValue < @EndDate
)
-- 4. Wstawiamy wygenerowane dni z wyciągniętymi atrybutami do naszej tabeli
INSERT INTO DimDate (DateID, [Date], [Year], [Month], [Day], [Quarter], DayOfWeekNumber, DayOfWeekName, MonthName, IsWeekend)
SELECT 
    CAST(CONVERT(VARCHAR(8), DateValue, 112) AS INT) AS DateID,
    DateValue AS [Date],
    YEAR(DateValue) AS [Year],
    MONTH(DateValue) AS [Month],
    DAY(DateValue) AS [Day],
    DATEPART(QQ, DateValue) AS [Quarter],
    DATEPART(DW, DateValue) AS DayOfWeekNumber,
    DATENAME(WEEKDAY, DateValue) AS DayOfWeekName,
    DATENAME(MONTH, DateValue) AS MonthName,
    CASE 
        WHEN DATEPART(DW, DateValue) IN (1, 7) THEN 1 -- (Zależne od ustawień serwera, domyślnie 1=Niedziela, 7=Sobota)
        ELSE 0 
    END AS IsWeekend
FROM DateGenerator
OPTION (MAXRECURSION 0); -- Zabezpieczenie wyłączające limit rekurencji
GO