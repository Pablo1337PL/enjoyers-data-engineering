import os
import requests
import sqlite3
import pandas as pd
import time
import numpy as np
from dotenv import load_dotenv
import urllib
from sqlalchemy import create_engine


load_dotenv()  # Ładuje zmienne środowiskowe z pliku .env

# --- KONFIGURACJA ---
APP_ID = os.getenv("APP_ID", "ADZUNA_APP_ID")
APP_KEY = os.getenv("APP_KEY", "ADZUNA_APP_KEY")

DB_NAME = "study_and_work_roi.db"
CSV_PATH = "education_costs.csv"

# Słownik: Kod kraju API -> Pełna nazwa z pliku Kaggle
COUNTRY_MAPPING = {
    'us': 'USA', 'gb': 'UK', 'ca': 'Canada', 'au': 'Australia', 'de': 'Germany',
    'jp': 'Japan', 'nl': 'Netherlands', 'sg': 'Singapore', 'fr': 'France', 
    'ch': 'Switzerland', 'se': 'Sweden', 'dk': 'Denmark', 'cn': 'China', 
    'kr': 'South Korea', 'ie': 'Ireland', 'nz': 'New Zealand', 'at': 'Austria', 
    'be': 'Belgium', 'hk': 'Hong Kong', 'pt': 'Portugal', 'il': 'Israel', 
    'tw': 'Taiwan', 'cz': 'Czech Republic', 'in': 'India', 'pl': 'Poland', 
    'my': 'Malaysia', 'es': 'Spain', 'it': 'Italy', 'fi': 'Finland', 'no': 'Norway', 
    'br': 'Brazil', 'tr': 'Turkey', 'ru': 'Russia', 'mx': 'Mexico', 'gr': 'Greece', 
    'th': 'Thailand', 'ae': 'UAE', 'za': 'South Africa', 'eg': 'Egypt', 'ar': 'Argentina', 
    'id': 'Indonesia', 'sa': 'Saudi Arabia', 'ng': 'Nigeria', 'vn': 'Vietnam', 
    'hu': 'Hungary', 'is': 'Iceland', 'co': 'Colombia', 'ro': 'Romania', 'lu': 'Luxembourg', 
    'tn': 'Tunisia', 'cy': 'Cyprus', 'hr': 'Croatia', 'do': 'Dominican Republic', 
    'ma': 'Morocco', 'pe': 'Peru', 'ec': 'Ecuador', 'lb': 'Lebanon', 'bh': 'Bahrain', 
    'uy': 'Uruguay', 'bg': 'Bulgaria', 'gh': 'Ghana', 'dz': 'Algeria', 'pa': 'Panama', 
    'bd': 'Bangladesh', 'kw': 'Kuwait', 'ua': 'Ukraine', 'si': 'Slovenia', 'rs': 'Serbia', 
    'ir': 'Iran', 'uz': 'Uzbekistan', 'sv': 'El Salvador'
}

COUNTRIES = list(COUNTRY_MAPPING.keys())
REVERSE_MAPPING = {v: k for k, v in COUNTRY_MAPPING.items()}
MAX_PAGES_PER_COUNTRY = 5  # Zwiększ tę liczbę, aby pobrać jeszcze więcej ofert (np. 10 lub 20)

# DODANO: Słownik walut do ujednolicenia podczas pobierania API
CURRENCY_MAPPING = {
    'us': 'USD', 'gb': 'GBP', 'ca': 'CAD', 'au': 'AUD', 'de': 'EUR',
    'pl': 'PLN', 'in': 'INR', 'nl': 'EUR', 'fr': 'EUR', 'jp': 'JPY',
    'sg': 'SGD', 'ch': 'CHF', 'se': 'SEK', 'dk': 'DKK', 'cn': 'CNY',
    'kr': 'KRW', 'ie': 'EUR', 'nz': 'NZD', 'at': 'EUR', 'be': 'EUR',
    'es': 'EUR', 'it': 'EUR', 'fi': 'EUR', 'pt': 'EUR', 'gr': 'EUR'
}

def fetch_jobs_by_city(country_code, city):
    """Pobiera oferty dla konkretnego miasta w danym kraju."""
    all_city_jobs = []
    print(f"   -> Pobieranie ofert dla: {city} ({country_code.upper()})...")
    
    for page in range(1, MAX_PAGES_PER_COUNTRY + 1): 
        url = f"https://api.adzuna.com/v1/api/jobs/{country_code}/search/{page}"
        params = {
            'app_id': APP_ID,
            'app_key': APP_KEY,
            'results_per_page': 50,
            'what': 'data',
            'where': city,
            'content-type': 'application/json'
        }
        
        try:
            response = requests.get(url, params=params)
            if response.status_code == 404: break
            response.raise_for_status()
            results = response.json().get('results', [])
            
            if not results: break
            all_city_jobs.extend(results)
            time.sleep(1) # Rate limiting
            
        except Exception as e:
            print(f"      Błąd: {e}")
            break
            
    return all_city_jobs

def process_api_jobs(raw_jobs, country_name, city_name, country_code):
    """Pakuje dane, dodając nazwy z CSV dla łatwego JOINa."""
    local_currency = CURRENCY_MAPPING.get(country_code, 'USD') # Awaryjnie USD
    processed = []
    for job in raw_jobs:
        processed.append({
            'job_id': job.get('id'),
            'country_name': country_name,
            'city_name': city_name,
            'title': job.get('title', 'Unknown'),
            'company': job.get('company', {}).get('display_name', 'Unknown'),
            'salary_min': job.get('salary_min'),
            'salary_max': job.get('salary_max'),
            'salary_currency': job.get('salary_currency_code', local_currency),
            'latitude': job.get('latitude'),
            'longitude': job.get('longitude'),
            'contract_time': job.get('contract_time', 'unknown'),
            'category': job.get('category', {}).get('label', 'unknown'),
            'created_at': job.get('created'),
            'url': job.get('redirect_url')
        })
    return processed

if __name__ == "__main__":
    if not os.path.exists(CSV_PATH):
        print(f"BŁĄD: Brak pliku {CSV_PATH}")
    else:
        # 1. Wczytaj miasta z CSV
        df_edu = pd.read_csv(CSV_PATH)
        # Standaryzacja brakujących kolumn bazowych
        for col in ['Visa_Fee_USD', 'Insurance_USD', 'Rent_USD', 'Tuition_USD']:
            if col not in df_edu.columns: df_edu[col] = 0

        relevant_locations = df_edu[df_edu['Country'].isin(REVERSE_MAPPING.keys())][['Country', 'City']].drop_duplicates()
        relevant_locations = relevant_locations.sample(frac=1).reset_index(drop=True)
        
        all_jobs_data = []

        # 2. Iteruj po miastach z pliku
        print(f"Znaleziono {len(relevant_locations)} unikalnych lokalizacji do sprawdzenia.")
        for _, row in relevant_locations.iterrows():
            c_name = row['Country']
            city = row['City']
            c_code = REVERSE_MAPPING.get(c_name)
            
            if c_code:
                raw_data = fetch_jobs_by_city(c_code, city)
                processed = process_api_jobs(raw_data, c_name, city, c_code)
                all_jobs_data.extend(processed)

        # =============== ETAP ETL I BUDOWA HURTOWNI ===============
        if all_jobs_data:
            print("\nRozpoczęto procesowanie i budowę modelu gwiazdy (ETL)...")
            df_jobs = pd.DataFrame(all_jobs_data)

            # --- A. PRZEWALUTOWANIE WYNAGRODZEŃ (USD) ---
            # Pobranie kursu wymiany dla danego kraju z pliku CSV
            rates = df_edu[['Country', 'Exchange_Rate']].drop_duplicates(subset=['Country'])
            df_jobs = df_jobs.merge(rates, left_on='country_name', right_on='Country', how='left')
            df_jobs['Exchange_Rate'] = pd.to_numeric(df_jobs['Exchange_Rate'], errors='coerce').fillna(1.0)
            
            # Przeliczenie na USD (Zakładamy Local / Exchange_Rate) i rzutowanie na INT
            df_jobs['salary_min_usd'] = (df_jobs['salary_min'] / df_jobs['Exchange_Rate']).fillna(0).astype(int)
            df_jobs['salary_max_usd'] = (df_jobs['salary_max'] / df_jobs['Exchange_Rate']).fillna(0).astype(int)

            # Obliczanie średniej z wartości w USD
            df_jobs['salary_mean_usd'] = df_jobs[['salary_min_usd', 'salary_max_usd']].mean(axis=1).fillna(0).astype(int)
            # Logika uzupełniająca średnią, gdy brakuje jednego z widełek
            df_jobs.loc[(df_jobs['salary_min_usd'] > 0) & (df_jobs['salary_max_usd'] == 0), 'salary_mean_usd'] = df_jobs['salary_min_usd']
            df_jobs.loc[(df_jobs['salary_max_usd'] > 0) & (df_jobs['salary_min_usd'] == 0), 'salary_mean_usd'] = df_jobs['salary_max_usd']

            # --- B. BUDOWA TABEL WYMIARÓW ---
            # 1. DimTerritory
            dim_territory = df_edu[['Country', 'City', 'Living_Cost_Index']].drop_duplicates().reset_index(drop=True)
            dim_territory['TeritoryID'] = dim_territory.index + 1
            city_coords = df_jobs.groupby('city_name')[['latitude', 'longitude']].mean().reset_index()
            dim_territory = dim_territory.merge(city_coords, left_on='City', right_on='city_name', how='left')
            dim_territory.rename(columns={'latitude': 'Latitude', 'longitude': 'Longitude'}, inplace=True)
            dim_territory = dim_territory[['TeritoryID', 'Country', 'City', 'Longitude', 'Latitude', 'LivingCostIndex']]

            # 2. DimMajor
            dim_major = df_edu[['University', 'Program', 'Level', 'Duration_Years']].drop_duplicates().reset_index(drop=True)
            dim_major['UniversitiesID'] = dim_major.index + 1
            dim_major.rename(columns={'University': 'UniversityName', 'Level': 'Degree'}, inplace=True)
            dim_major = dim_major[['UniversitiesID', 'UniversityName', 'Program', 'Degree', 'Duration_Years']]

            # 3. DimCompanies
            dim_companies = pd.DataFrame({'CompanyName': df_jobs['company'].dropna().unique()}).reset_index(drop=True)
            dim_companies['CompaniesID'] = dim_companies.index + 1

            # 4. DimAtributes (Zachowana pisownia ze schematu SQL)
            dim_attributes = df_jobs[['contract_time', 'category']].drop_duplicates().reset_index(drop=True)
            dim_attributes['ContractTypeID'] = dim_attributes.index + 1
            dim_attributes['ContractTypeName'] = 'Pobrane z API'
            dim_attributes.rename(columns={'contract_time': 'ContractTime', 'category': 'JobCategory'}, inplace=True)
            dim_attributes = dim_attributes[['ContractTypeID', 'ContractTypeName', 'ContractTime', 'JobCategory']]

            # 5. DimCurrency
            dim_currency = df_edu[['Exchange_Rate']].drop_duplicates().reset_index(drop=True)
            dim_currency['CurrencyID'] = dim_currency.index + 1
            dim_currency.rename(columns={'Exchange_Rate': 'Money'}, inplace=True)
            # Mapowanie z powrotem by odzyskać kod waluty
            curr_map = df_jobs[['Exchange_Rate', 'salary_currency']].drop_duplicates()
            dim_currency = dim_currency.merge(curr_map, left_on='Money', right_on='Exchange_Rate', how='left')
            dim_currency['CurrencyCode'] = dim_currency['salary_currency'].fillna('USD')
            dim_currency = dim_currency[['CurrencyID', 'Money', 'CurrencyCode']].drop_duplicates(subset=['CurrencyID'])

            # 6. DimDate
            df_jobs['created_at_dt'] = pd.to_datetime(df_jobs['created_at']).dt.date
            dim_date = pd.DataFrame({'Date': df_jobs['created_at_dt'].dropna().unique()}).reset_index(drop=True)
            dim_date['DateID'] = pd.to_datetime(dim_date['Date']).dt.strftime('%Y%m%d').astype(int)
            dim_date['Date'] = dim_date['Date'].astype(str)

            # --- C. BUDOWA TABEL FAKTÓW ---
            # FACT: education_cost
            fact_edu = df_edu.merge(dim_territory, on=['Country', 'City'], how='left')
            fact_edu = fact_edu.merge(dim_major, left_on=['University', 'Program', 'Level', 'Duration_Years'],
                                      right_on=['UniversityName', 'Program', 'Degree', 'Duration_Years'], how='left')
            fact_edu = fact_edu.merge(dim_currency, left_on='Exchange_Rate', right_on='Money', how='left')
            
            fact_edu['EducationID'] = fact_edu.index + 1
            fact_edu.rename(columns={
                'UniversitiesID': 'University',
                'TeritoryID': 'location',
                'CurrencyID': 'Exchange_Rate_FK' # Klucz obcy dla SQL Servera
            }, inplace=True)
            
            fact_edu = fact_edu[['EducationID', 'University', 'location', 'Tuition_USD', 'Visa_Fee_USD', 'Insurance_USD', 'Rent_USD', 'Exchange_Rate_FK']]
            fact_edu.rename(columns={'Exchange_Rate_FK': 'Exchange_Rate'}, inplace=True)

            # FACT: job_postings
            fact_jobs = df_jobs.merge(dim_territory, on=['Country', 'City'], how='left')
            fact_jobs = fact_jobs.merge(dim_companies, left_on='company', right_on='CompanyName', how='left')
            fact_jobs = fact_jobs.merge(dim_attributes, left_on=['contract_time', 'category'], right_on=['ContractTime', 'JobCategory'], how='left')
            
            fact_jobs['created_at_id'] = fact_jobs['created_at_dt'].apply(lambda x: int(x.strftime('%Y%m%d')) if pd.notnull(x) else 0)
            
            fact_jobs.rename(columns={
                'TeritoryID': 'location',
                'ContractTypeID': 'contract_attributes',
                'CompaniesID': 'company_fk',
                'created_at_id': 'created_at'
            }, inplace=True)
            
            # W SQL Server masz typ BOOL/BIT, ustawiamy to na wartość 1 (Aktywne)
            fact_jobs['is_active'] = 1

            fact_jobs = fact_jobs[['job_id', 'title', 'location', 'contract_attributes', 'salary_min_usd', 'salary_mean_usd', 'salary_max_usd', 'url', 'company_fk', 'created_at', 'is_active']]
            fact_jobs.rename(columns={
                'company_fk': 'company',
                'salary_min_usd': 'salary_min',
                'salary_mean_usd': 'salary_mean',
                'salary_max_usd': 'salary_max'
            }, inplace=True)
            
            # Czyszczenie z brakujących kluczy
            fact_jobs.dropna(subset=['location', 'company', 'contract_attributes'], inplace=True)

            

            # ==========================================
            # ETAP 4: ŁADOWANIE DO AZURE SQL
            # ==========================================
            print("Łączenie z bazą Azure SQL...")
            
            AZURE_SERVER = "enjoyers-database-server.database.windows.net"
            AZURE_DB = "Enjoyers_database"
            AZURE_USER = "enjoyer"
            AZURE_PASS = os.getenv("AZURE_DB_PASS")

            params = urllib.parse.quote_plus(
                "Driver={ODBC Driver 18 for SQL Server};"
                f"Server=tcp:{AZURE_SERVER},1433;"
                f"Database={AZURE_DB};"
                f"Uid={AZURE_USER};"
                f"Pwd={AZURE_PASS};"
                "Encrypt=yes;"
                "TrustServerCertificate=no;"
                "Connection Timeout=30;"
            )

            engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")

            # KRYTYCZNE: Zmieniamy if_exists='replace' na 'append'. 
            # 'replace' usunęłoby Twoje pieczołowicie zaplanowane tabele i klucze obce!
            print("Eksport wymiarów...")
            dim_territory.to_sql('DimTerritory', engine, if_exists='append', index=False)
            dim_major.to_sql('DimMajor', engine, if_exists='append', index=False)
            dim_companies.to_sql('DimCompanies', engine, if_exists='append', index=False)
            dim_attributes.to_sql('DimAtributes', engine, if_exists='append', index=False)
            dim_date.to_sql('DimDate', engine, if_exists='append', index=False)
            dim_currency.to_sql('DimCurrency', engine, if_exists='append', index=False)
            
            print("Eksport faktów...")
            fact_edu.to_sql('fact_education_cost', engine, if_exists='append', index=False)
            fact_jobs.to_sql('fact_job_postings', engine, if_exists='append', index=False)
            
            print(f"\n[SUKCES] Dane wylądowały w chmurze Azure!")