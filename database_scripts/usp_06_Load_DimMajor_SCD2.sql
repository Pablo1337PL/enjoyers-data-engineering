-- PROCEDURA: Kierunki Studiów (Z pliku CSV)
CREATE PROCEDURE usp_06_Load_DimMajor_SCD2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATETIME2 = GETDATE();

    WITH SourceData AS (
        SELECT DISTINCT University, Program, Level, Duration_Years
        FROM stg_education_costs
    )
    INSERT INTO DimMajor (UniversityName, Program, Degree, Duration_Years, ValidFrom, ValidTo, IsCurrent)
    SELECT s.University, s.Program, s.Level, s.Duration_Years, @CurrentDate, NULL, 1
    FROM SourceData s
    WHERE NOT EXISTS (
        SELECT 1 FROM DimMajor t 
        WHERE t.UniversityName = s.University 
          AND t.Program = s.Program 
          AND ISNULL(t.Degree,'') = ISNULL(s.Level,'') 
          AND t.IsCurrent = 1
    );
END;