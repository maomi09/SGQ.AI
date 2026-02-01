# Android Keystore Creation Script
# This script helps you create a keystore for Google Play publishing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Keystore Creation Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if keytool exists
$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (-not (Test-Path $keytoolPath)) {
    Write-Host "Error: keytool.exe not found" -ForegroundColor Red
    Write-Host "Please make sure Android Studio is installed correctly" -ForegroundColor Yellow
    exit 1
}

# Set keystore path
$keystorePath = "$env:USERPROFILE\sgq-release-key.jks"

Write-Host "Keystore will be created at: $keystorePath" -ForegroundColor Green
Write-Host ""

# Check if already exists
if (Test-Path $keystorePath) {
    Write-Host "Warning: keystore file already exists!" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Please enter the following information to create keystore:" -ForegroundColor Cyan
Write-Host ""

# Execute keytool command
& $keytoolPath -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias sgq

$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Keystore created successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Keystore location: $keystorePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Create key.properties file in app/android/ directory" -ForegroundColor White
    Write-Host "2. Refer to key.properties.example and fill in your information" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Error: Failed to create keystore" -ForegroundColor Red
    exit 1
}
