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
