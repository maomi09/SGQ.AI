# Deploy teacher export to https://export.sagp-qp.com (does NOT touch Python backend)
# Run: double-click run-export-domain.bat

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$DeployDir = Join-Path $Root "deploy"
$ParamsFile = Join-Path $DeployDir "deploy-params.ps1"
$RemoteWebRoot = "/var/www/sgq-teacher-export"
$ExportDomain = "export.sagp-qp.com"

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
# Auto-generated - SGQ teacher export deploy
`$Ec2UserAtHost = "ubuntu@$ip"
`$SshKeyPath = "$key"
`$ExportDomain = "export.sagp-qp.com"
`$RemoteWebRoot = "/var/www/sgq-teacher-export"
"@ | Set-Content -Path $ParamsFile -Encoding ASCII
  Write-Host "Saved deploy\deploy-params.ps1" -ForegroundColor Green
}

Ensure-Params
. $ParamsFile

if ([string]::IsNullOrWhiteSpace($SshKeyPath) -or -not (Test-Path $SshKeyPath)) {
  Write-Host "SSH key not found: $SshKeyPath" -ForegroundColor Red
  exit 1
}

$webFiles = @("index.html", "app.js", "styles.css", "config.js")
$assetFiles = @("assets/sgq-logo.png")
$deployFiles = @(
  "nginx-export.sagp-qp.com.conf",
  "install-on-ec2.sh"
)

Write-Host ""
Write-Host "Target: https://$ExportDomain" -ForegroundColor Cyan
Write-Host "Uploading to $Ec2UserAtHost : $RemoteWebRoot" -ForegroundColor Cyan
Write-Host "(Python API at api.sagp-qp.com is NOT modified)" -ForegroundColor DarkGray

ssh -i $SshKeyPath -o StrictHostKeyChecking=accept-new $Ec2UserAtHost `
  "sudo mkdir -p $RemoteWebRoot && sudo chown -R `$(whoami):`$(whoami) $RemoteWebRoot"

ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p ${RemoteWebRoot}/assets"

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

$remoteDeploy = "/tmp/sgq-teacher-export-deploy"
ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p $remoteDeploy"
foreach ($f in $deployFiles) {
  scp -i $SshKeyPath (Join-Path $DeployDir $f) "${Ec2UserAtHost}:${remoteDeploy}/$f"
  Write-Host "  OK deploy/$f" -ForegroundColor Green
}

Write-Host ""
Write-Host "Configuring Nginx + HTTPS on EC2..." -ForegroundColor Cyan
ssh -i $SshKeyPath $Ec2UserAtHost "chmod +x $remoteDeploy/install-on-ec2.sh && sudo bash $remoteDeploy/install-on-ec2.sh $ExportDomain"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done (if no errors above)" -ForegroundColor Green
Write-Host "Teacher URL: https://$ExportDomain" -ForegroundColor Green
Write-Host ""
Write-Host "Supabase: Authentication -> URL Configuration" -ForegroundColor Yellow
Write-Host "  Site URL: https://$ExportDomain" -ForegroundColor Yellow
Write-Host "  Redirect URLs: https://$ExportDomain" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
