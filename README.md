# powershell-data-quality-automation
PowerShell scripts for automating data quality checks and file handling for CSV-based credentialing data feeds.

This project demonstrates how to use PowerShell to automate basic data quality checks and file handling for credentialing-related CSV files.  
It simulates a common data operations scenario: validating daily data feeds, logging issues, and organizing processed files.

The goal is to show practical scripting skills that support data reliability, automation, and production readiness.

---

## Project Overview

This project assumes a process where credentialing or provider data files are delivered daily into an input folder.  
The PowerShell scripts:

1. Validate that required columns exist.
2. Check for missing key values (such as ProviderID).
3. Identify expired credentials still marked as active.
4. Log all issues into a timestamped log file.
5. Move successfully processed files into an archive folder.

This setup reflects how a data team can catch issues early before loading data into a database or analytics platform.

**My Notes:**  
I built this to practice automating the type of checks that a data or credentialing team would normally do manually before loading files into a system.

---

## Technologies Used

| Category    | Tools/Technologies              |
|-------------|---------------------------------|
| Scripting   | PowerShell                      |
| Data Format | CSV                             |
| Logging     | Plain text log files            |
| Platform    | Windows-compatible environment  |

**My Notes:**  
I chose PowerShell because it is widely used in enterprise environments for automation, especially with Windows-based systems and file workflows.

---

## Folder Structure

Recommended repository structure:

powershell-data-quality-automation/
│
├─ README.md
├─ scripts/
│ ├─ Invoke-DataQualityChecks.ps1
│ ├─ Move-ProcessedFiles.ps1
│
├─ config/
│ ├─ data-config.json
│
└─ sample_data/
├─ providers_sample.csv
├─ credentials_sample.csv

pgsql

You can adjust paths as needed, but this structure keeps scripts, configuration, and sample data organized.

---

## Configuration File

File: `config/data-config.json`

This file defines input, archive, and log paths so the scripts are easier to maintain.

```json
{
  "InputFolder": "./sample_data",
  "ArchiveFolder": "./archive",
  "LogFolder": "./logs",
  "ProviderFilePattern": "providers_*.csv",
  "CredentialFilePattern": "credentials_*.csv"
}
My Notes:
Using a JSON config allows the script to be reused in different environments without changing the PowerShell code.

Sample Data Files
File: sample_data/providers_sample.csv

csv
Copy code
ProviderID,FirstName,LastName,NPI,Specialty,Status
1,Sarah,Coleman,1234567890,Pediatrics,Active
2,James,Lee,2345678901,Cardiology,Active
3,Mia,Davis,3456789012,Dermatology,Inactive
4,,Nguyen,9876543210,Oncology,Active
File: sample_data/credentials_sample.csv

csv
CredentialID,ProviderID,CredentialType,CredentialNumber,IssueDate,ExpiryDate,Status
1,1,License,LIC-001,2022-01-10,2024-01-10,Active
2,1,BoardCert,BC-101,2022-02-01,2025-02-01,Active
3,2,License,LIC-002,2021-11-05,2023-11-05,Expired
4,3,License,LIC-003,2020-06-18,2022-06-18,Expired
5,5,License,LIC-999,2023-01-01,2025-01-01,Active
This sample data intentionally includes:

A row with missing ProviderID-related information.

A credential with a ProviderID that does not exist.

Expired and inactive records for validation logic.

Script 1: Data Quality Checks
File: scripts/Invoke-DataQualityChecks.ps1

This script:

Loads configuration.

Scans provider and credential CSV files.

Performs basic validation checks.

Writes issues to a log file.

powershell
Copy code
param(
    [string]$ConfigPath = "./config/data-config.json"
)

# Load configuration
if (-Not (Test-Path $ConfigPath)) {
    Write-Host "Configuration file not found at $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath | ConvertFrom-Json

$inputFolder     = $config.InputFolder
$logFolder       = $config.LogFolder
$providerPattern = $config.ProviderFilePattern
$credPattern     = $config.CredentialFilePattern

if (-Not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = Join-Path $logFolder "data_quality_log_$timestamp.txt"

function Write-Log {
    param([string]$Message)
    $Message | Out-File -FilePath $logFile -Append -Encoding utf8
    Write-Host $Message
}

Write-Log "Starting data quality checks at $(Get-Date)"
Write-Log "Input folder: $inputFolder"

# Load provider files
$providerFiles = Get-ChildItem -Path $inputFolder -Filter $providerPattern -ErrorAction SilentlyContinue
$credentialFiles = Get-ChildItem -Path $inputFolder -Filter $credPattern -ErrorAction SilentlyContinue

if (-Not $providerFiles) {
    Write-Log "No provider files found matching pattern $providerPattern"
} else {
    foreach ($file in $providerFiles) {
        Write-Log "Checking provider file: $($file.Name)"
        $data = Import-Csv $file.FullName

        # Required column check
        $requiredColumns = @("ProviderID","FirstName","LastName","NPI","Specialty","Status")
        foreach ($col in $requiredColumns) {
            if (-Not ($data | Get-Member -Name $col -MemberType NoteProperty)) {
                Write-Log "Missing required column '$col' in provider file: $($file.Name)"
            }
        }

        # Missing ProviderID
        $missingIdRows = $data | Where-Object { -Not $_.ProviderID }
        if ($missingIdRows.Count -gt 0) {
            Write-Log "Found $($missingIdRows.Count) rows with missing ProviderID in $($file.Name)"
        }
    }
}

# Check credentials
if (-Not $credentialFiles) {
    Write-Log "No credential files found matching pattern $credPattern"
} else {
    foreach ($file in $credentialFiles) {
        Write-Log "Checking credential file: $($file.Name)"
        $data = Import-Csv $file.FullName

        # Required column check
        $requiredColumns = @("CredentialID","ProviderID","CredentialType","CredentialNumber","IssueDate","ExpiryDate","Status")
        foreach ($col in $requiredColumns) {
            if (-Not ($data | Get-Member -Name $col -MemberType NoteProperty)) {
                Write-Log "Missing required column '$col' in credential file: $($file.Name)"
            }
        }

        # Missing ProviderID
        $missingProvider = $data | Where-Object { -Not $_.ProviderID }
        if ($missingProvider.Count -gt 0) {
            Write-Log "Found $($missingProvider.Count) rows with missing ProviderID in $($file.Name)"
        }

        # Expired but Active
        $today = Get-Date
        $expiredActive = $data | Where-Object {
            ($_."Status" -eq "Active") -and ([datetime]$_.ExpiryDate -lt $today)
        }

        if ($expiredActive.Count -gt 0) {
            Write-Log "Found $($expiredActive.Count) credentials marked Active but expired in $($file.Name)"
        }
    }
}

Write-Log "Data quality checks completed."
My Notes:
This script simulates what I would run before loading daily files into a database to make sure key fields are present and basic rules are respected.

Script 2: Move Processed Files
File: scripts/Move-ProcessedFiles.ps1

This script moves processed files into an archive folder after validation.

powershell
param(
    [string]$ConfigPath = "./config/data-config.json"
)

if (-Not (Test-Path $ConfigPath)) {
    Write-Host "Configuration file not found at $ConfigPath"
    exit 1
}

$config = Get-Content $ConfigPath | ConvertFrom-Json

$inputFolder   = $config.InputFolder
$archiveFolder = $config.ArchiveFolder

if (-Not (Test-Path $archiveFolder)) {
    New-Item -ItemType Directory -Path $archiveFolder | Out-Null
}

$files = Get-ChildItem -Path $inputFolder -Filter "*.csv" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $dest = Join-Path $archiveFolder $file.Name
    Move-Item -Path $file.FullName -Destination $dest -Force
    Write-Host "Moved $($file.Name) to archive."
}
My Notes:
Archiving files after validation keeps the input folder clean and makes the process feel more production-ready.

Run:

powershell
pwsh ./scripts/Invoke-DataQualityChecks.ps1
pwsh ./scripts/Move-ProcessedFiles.ps1
(Use powershell instead of pwsh on Windows if required.)

Results
-Automatically validates credentialing CSV files for structure and basic rules.
-Logs all findings to a timestamped log file for review.
-Helps prevent invalid or incomplete data from entering downstream systems.
-Demonstrates practical PowerShell scripting for file handling and data quality.

Personal Reflection
This project is a practical example of how scripting can support data teams by catching issues early and standardizing routine checks.
It connects directly to real-world tasks such as feed validation, pre-load checks, and automated file workflows in enterprise environments.

My Notes:
Working on this helped me become more comfortable with PowerShell syntax, loops, and working with CSV data in an automated way.

Author
Telma Anika
New Carrollton, Maryland
Email: tellyannika@gmail.com
Focus Areas: SQL Development, Data Operations, Automation, and Data Quality
Education: AAS in Cybersecurity (PGCC) – Continuing studies at UMGC


