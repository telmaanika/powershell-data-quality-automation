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
