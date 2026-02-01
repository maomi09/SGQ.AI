# Verify Android Signing Configuration
# This script verifies that all signing configuration is correct

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Signing Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()

# Check 1: key.properties file exists
Write-Host "[1/5] Checking key.properties file..." -ForegroundColor Yellow
$keyPropertiesPath = ".\key.properties"
if (Test-Path $keyPropertiesPath) {
    Write-Host "  ✓ key.properties exists" -ForegroundColor Green
    
    # Read and check content
    $content = Get-Content $keyPropertiesPath
    $hasStorePassword = $false
    $hasKeyPassword = $false
    $hasKeyAlias = $false
    $hasStoreFile = $false
    
    foreach ($line in $content) {
        if ($line -match "^storePassword=") {
            $hasStorePassword = $true
            if ($line -match "^storePassword=$") {
                $errors += "storePassword is empty in key.properties"
            }
        }
        if ($line -match "^keyPassword=") {
            $hasKeyPassword = $true
            if ($line -match "^keyPassword=$") {
                $errors += "keyPassword is empty in key.properties"
            }
        }
        if ($line -match "^keyAlias=") {
            $hasKeyAlias = $true
            if ($line -match "^keyAlias=$") {
                $errors += "keyAlias is empty in key.properties"
            }
        }
        if ($line -match "^storeFile=") {
            $hasStoreFile = $true
            if ($line -match "^storeFile=$") {
                $errors += "storeFile is empty in key.properties"
            } else {
                # Extract path and check if it uses double backslashes
                $pathMatch = $line -match "storeFile=(.+)"
                if ($pathMatch) {
                    $filePath = $matches[1]
                    if ($filePath -notmatch "\\\\") {
                        $warnings += "storeFile path should use double backslashes (\\\\) for Windows paths"
                    }
                }
            }
        }
    }
    
    if (-not $hasStorePassword) {
        $errors += "storePassword is missing in key.properties"
    }
    if (-not $hasKeyPassword) {
        $errors += "keyPassword is missing in key.properties"
    }
    if (-not $hasKeyAlias) {
        $errors += "keyAlias is missing in key.properties"
    }
    if (-not $hasStoreFile) {
        $errors += "storeFile is missing in key.properties"
    }
} else {
    $errors += "key.properties file not found in app/android/ directory"
}

# Check 2: Keystore file exists
Write-Host "[2/5] Checking keystore file..." -ForegroundColor Yellow
if ($hasStoreFile) {
    # Try to extract path from key.properties
    $content = Get-Content $keyPropertiesPath
    foreach ($line in $content) {
        if ($line -match "^storeFile=(.+)") {
            $filePath = $matches[1]
            # Convert double backslashes to single for Test-Path
            $filePath = $filePath -replace "\\\\", "\"
            if (Test-Path $filePath) {
                Write-Host "  ✓ Keystore file exists: $filePath" -ForegroundColor Green
            } else {
                $errors += "Keystore file not found: $filePath"
            }
            break
        }
    }
} else {
    $warnings += "Cannot check keystore file (storeFile not found in key.properties)"
}

# Check 3: build.gradle.kts has signing config
Write-Host "[3/5] Checking build.gradle.kts..." -ForegroundColor Yellow
$buildGradlePath = ".\app\build.gradle.kts"
if (Test-Path $buildGradlePath) {
    $buildGradleContent = Get-Content $buildGradlePath -Raw
    if ($buildGradleContent -match "signingConfigs") {
        Write-Host "  ✓ signingConfigs found in build.gradle.kts" -ForegroundColor Green
        if ($buildGradleContent -match "key\.properties") {
            Write-Host "  ✓ key.properties reference found" -ForegroundColor Green
        } else {
            $errors += "build.gradle.kts does not reference key.properties"
        }
    } else {
        $errors += "signingConfigs not found in build.gradle.kts"
    }
} else {
    $errors += "build.gradle.kts not found"
}

# Check 4: Verify keytool can access keystore (if possible)
Write-Host "[4/5] Checking keytool access..." -ForegroundColor Yellow
$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if (Test-Path $keytoolPath) {
    Write-Host "  ✓ keytool.exe found" -ForegroundColor Green
} else {
    $warnings += "keytool.exe not found (Android Studio may not be installed)"
}

# Check 5: Flutter environment
Write-Host "[5/5] Checking Flutter environment..." -ForegroundColor Yellow
$flutterCheck = flutter --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Flutter is available" -ForegroundColor Green
} else {
    $warnings += "Flutter may not be properly configured"
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "✓ Configuration is valid!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now build your app bundle with:" -ForegroundColor Yellow
    Write-Host "  flutter build appbundle --release" -ForegroundColor White
} else {
    Write-Host "✗ Found $($errors.Count) error(s):" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠ Found $($warnings.Count) warning(s):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
