# Deploy app landing to https://app.sagp-qp.com
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$DeployDir = Join-Path $Root "deploy"
$ParamsFile = Join-Path $DeployDir "deploy-params.ps1"
$AppDomain = "app.sagp-qp.com"
$RemoteWebRoot = "/var/www/sgq-app-landing"

function Ensure-Params {
  if (Test-Path $ParamsFile) { return }
  Write-Host ""
  Write-Host "=== First-time setup (creates deploy\deploy-params.ps1) ===" -ForegroundColor Cyan
  $ip = Read-Host "EC2 public IP [default: 3.80.19.9]"
  if ([string]::IsNullOrWhiteSpace($ip)) { $ip = "3.80.19.9" }
  $key = Read-Host "Full path to your .pem SSH key file"
  while (-not (Test-Path $key)) {
    Write-Host "File not found: $key" -ForegroundColor Red
    $key = Read-Host "Enter .pem path again"
  }
  @"
`$Ec2UserAtHost = "ubuntu@$ip"
`$SshKeyPath = "$key"
`$AppDomain = "app.sagp-qp.com"
`$RemoteWebRoot = "/var/www/sgq-app-landing"
"@ | Set-Content -Path $ParamsFile -Encoding ASCII
  Write-Host "Saved deploy\deploy-params.ps1" -ForegroundColor Green
}

Ensure-Params
. $ParamsFile

if ([string]::IsNullOrWhiteSpace($SshKeyPath) -or -not (Test-Path $SshKeyPath)) {
  Write-Host "SSH key not found: $SshKeyPath" -ForegroundColor Red
  exit 1
}

$webFiles = @(
  "index.html", "privacy.html", "student.html",
  "student.js", "app.js", "i18n.js", "sgq-recaptcha.js",
  "styles.css", "config.js", "robots.txt", "sitemap.xml"
)
# Optional: copy google*.html Search Console verification into web\app-landing\ before deploy
$googleVerify = Get-ChildItem -Path $Root -Filter "google*.html" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($googleVerify) { $webFiles += $googleVerify.Name }
$assetFiles = @(
  "assets/sgq-logo.png",
  "assets/google-play-badge.png",
  "assets/app-store-badge.svg"
)
$deployFiles = @("nginx-app.sagp-qp.com.conf", "install-on-ec2.sh")

Write-Host ""
Write-Host "Target: https://$AppDomain" -ForegroundColor Cyan
Write-Host "Uploading to $Ec2UserAtHost : $RemoteWebRoot" -ForegroundColor Cyan

ssh -i $SshKeyPath -o StrictHostKeyChecking=accept-new $Ec2UserAtHost `
  "sudo mkdir -p $RemoteWebRoot/assets && sudo chown -R `$(whoami):`$(whoami) $RemoteWebRoot"

foreach ($f in $webFiles) {
  scp -i $SshKeyPath (Join-Path $Root $f) "${Ec2UserAtHost}:${RemoteWebRoot}/$f"
  Write-Host "  OK $f" -ForegroundColor Green
}

foreach ($f in $assetFiles) {
  $local = Join-Path $Root $f
  if (Test-Path $local) {
    scp -i $SshKeyPath $local "${Ec2UserAtHost}:${RemoteWebRoot}/$f"
    Write-Host "  OK $f" -ForegroundColor Green
  }
}

$remoteDeploy = "/tmp/sgq-app-landing-deploy"
ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p $remoteDeploy"
foreach ($f in $deployFiles) {
  scp -i $SshKeyPath (Join-Path $DeployDir $f) "${Ec2UserAtHost}:${remoteDeploy}/$f"
  Write-Host "  OK deploy/$f" -ForegroundColor Green
}

Write-Host ""
Write-Host "Configuring Nginx + HTTPS..." -ForegroundColor Cyan
ssh -i $SshKeyPath $Ec2UserAtHost "chmod +x $remoteDeploy/install-on-ec2.sh && sudo bash $remoteDeploy/install-on-ec2.sh $AppDomain"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done (if no errors above)" -ForegroundColor Green
Write-Host "Site: https://$AppDomain" -ForegroundColor Green
Write-Host ""
Write-Host "Next: edit config.js with Play Store / App Store URLs" -ForegroundColor Yellow
Write-Host "  web\app-landing\config.js" -ForegroundColor Yellow
Write-Host "Then run this script again to upload." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
