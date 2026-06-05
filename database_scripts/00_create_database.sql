DROP TABLE IF EXISTS fact_education_cost;
DROP TABLE IF EXISTS fact_job_postings;
DROP TABLE IF EXISTS DimAtributes;
DROP TABLE IF EXISTS DimCompanies;
DROP TABLE IF EXISTS DimCountryMapping;
DROP TABLE IF EXISTS DimCurrency;
DROP TABLE IF EXISTS DimMajor;
DROP TABLE IF EXISTS DimTerritory;
DROP TABLE IF EXISTS DimDate;

CREATE TABLE DimAtributes (
    ContractTypeID INT IDENTITY(1,1) NOT NULL,
    ContractTime NVARCHAR(100) NULL,
    JobCategory NVARCHAR(100) NULL,
    ValidFrom DATETIME2 NULL,
    ValidTo DATETIME2 NULL,
    IsCurrent BIT NULL,
    CONSTRAINT PK_DimAtributes PRIMARY KEY (ContractTypeID)
);

CREATE TABLE DimCompanies (
    CompaniesID INT IDENTITY(1,1) NOT NULL,
    CompanyName NVARCHAR(255) NULL,
    ValidFrom DATETIME2 NULL,
    ValidTo DATETIME2 NULL,
    IsCurrent BIT NULL,
    CONSTRAINT PK_DimCompanies PRIMARY KEY (CompaniesID)
);

CREATE TABLE DimCountryMapping (
    CountryCode VARCHAR(10) NOT NULL,
    CountryName VARCHAR(100) NOT NULL,
    IsSupportedByAdzuna BIT NULL,
    CONSTRAINT PK_DimCountryMapping PRIMARY KEY (CountryCode)
);

CREATE TABLE DimCurrency (
    CurrencyID INT IDENTITY(1,1) NOT NULL,
    Money FLOAT NULL,
    CurrencyCode NVARCHAR(10) NULL,
    ValidFrom DATETIME2 NULL,
    ValidTo DATETIME2 NULL,
    IsCurrent BIT NULL,
    CONSTRAINT PK_DimCurrency PRIMARY KEY (CurrencyID)
);

CREATE TABLE DimMajor (
    UniversitiesID INT IDENTITY(1,1) NOT NULL,
    UniversityName NVARCHAR(255) NULL,
    Program NVARCHAR(255) NULL,
    Degree NVARCHAR(100) NULL,
    Duration_Years INT NULL,
    ValidFrom DATETIME2 NULL,
    ValidTo DATETIME2 NULL,
    IsCurrent BIT NULL,
    CONSTRAINT PK_DimMajor PRIMARY KEY (UniversitiesID)
);

CREATE TABLE DimTerritory (
    TeritoryID INT IDENTITY(1,1) NOT NULL,
    Country NVARCHAR(100) NULL,
    City NVARCHAR(100) NULL,
    Longitude FLOAT NULL,
    Latitude FLOAT NULL,
    LivingCostIndex FLOAT NULL,
    ValidFrom DATETIME2 NULL,
    ValidTo DATETIME2 NULL,
    IsCurrent BIT NULL,
    CONSTRAINT PK_DimTerritory PRIMARY KEY (TeritoryID)
);

-- Tabela Czasu (niezbędna dla referencji z fact_job_postings)
CREATE TABLE DimDate (
    DateID INT NOT NULL, 
    [Date] DATE NOT NULL,
    [Year] INT NOT NULL,
    [Month] INT NOT NULL,
    [Day] INT NOT NULL,
    [Quarter] INT NOT NULL,
    DayOfWeekNumber INT NOT NULL,
    DayOfWeekName NVARCHAR(20) NOT NULL,
    MonthName NVARCHAR(20) NOT NULL,
    IsWeekend BIT NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY (DateID)
);

CREATE TABLE fact_education_cost (
    EducationID INT IDENTITY(1,1) NOT NULL,
    University INT NULL,
    location INT NULL,
    Tuition_USD INT NULL,
    Visa_Fee_USD INT NULL,
    Insurance_USD INT NULL,
    Rent_USD INT NULL,
    Exchange_Rate INT NULL,
    CONSTRAINT PK_fact_education_cost PRIMARY KEY (EducationID)
);

CREATE TABLE fact_job_postings (
    job_id BIGINT NOT NULL, -- ID pochodzące prosto z API
    title NVARCHAR(255) NULL,
    location INT NULL,
    contract_attributes INT NULL,
    salary_min INT NULL,
    salary_mean INT NULL,
    salary_max INT NULL,
    url NVARCHAR(MAX) NULL,
    company INT NULL,
    created_at INT NULL,
    is_active BIT NULL,
    CONSTRAINT PK_fact_job_postings PRIMARY KEY (job_id)
);

ALTER TABLE fact_education_cost
ADD CONSTRAINT FK_Education_Major FOREIGN KEY (University) REFERENCES DimMajor(UniversitiesID);

ALTER TABLE fact_education_cost
ADD CONSTRAINT FK_Education_Territory FOREIGN KEY (location) REFERENCES DimTerritory(TeritoryID);

-- Relacje dla fact_job_postings
ALTER TABLE fact_job_postings
ADD CONSTRAINT FK_JobPostings_Territory FOREIGN KEY (location) REFERENCES DimTerritory(TeritoryID);

ALTER TABLE fact_job_postings
ADD CONSTRAINT FK_JobPostings_Atributes FOREIGN KEY (contract_attributes) REFERENCES DimAtributes(ContractTypeID);

ALTER TABLE fact_job_postings
ADD CONSTRAINT FK_JobPostings_Company FOREIGN KEY (company) REFERENCES DimCompanies(CompaniesID);

ALTER TABLE fact_job_postings
ADD CONSTRAINT FK_JobPostings_Date FOREIGN KEY (created_at) REFERENCES DimDate(DateID);
GO