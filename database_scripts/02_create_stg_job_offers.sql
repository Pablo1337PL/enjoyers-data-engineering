CREATE TABLE stg_job_postings (
    StagingId INT IDENTITY(1,1) PRIMARY KEY,
    RawJsonData NVARCHAR(MAX),
    SourceFileName NVARCHAR(255),
    LoadDate DATETIME DEFAULT GETDATE()
);