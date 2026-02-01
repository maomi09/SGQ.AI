# Create key.properties file
# This script helps you create the key.properties file for Android signing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create key.properties File" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$keystorePath = "$env:USERPROFILE\sgq-release-key.jks"

# Check if keystore exists
if (-not (Test-Path $keystorePath)) {
    Write-Host "Error: Keystore file not found at: $keystorePath" -ForegroundColor Red
    Write-Host "Please run create-keystore.ps1 first to create the keystore." -ForegroundColor Yellow
    exit 1
}

Write-Host "Keystore found at: $keystorePath" -ForegroundColor Green
Write-Host ""

# Get passwords
$storePassword = Read-Host "Enter keystore password" -AsSecureString
$keyPasswordInput = Read-Host "Enter key password (or press Enter to use same as keystore password)"

# Convert secure string to plain text
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword)
$storePasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Use same password if key password is empty
if ([string]::IsNullOrWhiteSpace($keyPasswordInput)) {
    $keyPasswordPlain = $storePasswordPlain
} else {
    $keyPasswordPlain = $keyPasswordInput
}

# Create key.properties content
$keyPropertiesContent = @"
# Android signing configuration
# This file is used by build.gradle.kts for release signing
# DO NOT commit this file to version control

# Keystore password
storePassword=$storePasswordPlain

# Key password (usually same as storePassword)
keyPassword=$keyPasswordPlain

# Key alias (used when creating keystore)
keyAlias=sgq

# Keystore file path
storeFile=$keystorePath
"@

# Write to file
$keyPropertiesPath = ".\key.properties"
$keyPropertiesContent | Out-File -FilePath $keyPropertiesPath -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "key.properties created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "File location: $((Get-Location).Path)\key.properties" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Build your app bundle with:" -ForegroundColor Yellow
Write-Host "  flutter build appbundle --release" -ForegroundColor White
Write-Host ""
