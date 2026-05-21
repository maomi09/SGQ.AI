# SGQ teacher export - AWS deploy (https://api.sagp-qp.com/teacher-export/)
# Run: double-click "run-aws-deploy.bat" OR: powershell -File .\deploy-aws.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$DeployDir = Join-Path $Root "deploy"
$ParamsFile = Join-Path $DeployDir "deploy-params.ps1"
$RemoteWebRoot = "/var/www/sgq-teacher-export"

function Ensure-Params {
  if (Test-Path $ParamsFile) {
    return
  }
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
  "nginx-teacher-export-subpath.snippet",
  "install-subpath-on-ec2.sh"
)

Write-Host ""
Write-Host "Uploading to $Ec2UserAtHost : $RemoteWebRoot" -ForegroundColor Cyan

ssh -i $SshKeyPath -o StrictHostKeyChecking=accept-new $Ec2UserAtHost `
  "sudo mkdir -p $RemoteWebRoot && sudo chown -R `$(whoami):`$(whoami) $RemoteWebRoot"

ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p ${RemoteWebRoot}/assets"

foreach ($f in $webFiles) {
  $local = Join-Path $Root $f
  scp -i $SshKeyPath $local "${Ec2UserAtHost}:${RemoteWebRoot}/$f"
  Write-Host "  OK $f" -ForegroundColor Green
}

foreach ($f in $assetFiles) {
  $local = Join-Path $Root $f
  if (-not (Test-Path $local)) {
    Write-Host "  SKIP missing $f" -ForegroundColor Yellow
    continue
  }
  scp -i $SshKeyPath $local "${Ec2UserAtHost}:${RemoteWebRoot}/$f"
  Write-Host "  OK $f" -ForegroundColor Green
}

$remoteDeploy = "/tmp/sgq-teacher-export-deploy"
ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p $remoteDeploy"
foreach ($f in $deployFiles) {
  $local = Join-Path $DeployDir $f
  scp -i $SshKeyPath $local "${Ec2UserAtHost}:${remoteDeploy}/$f"
  Write-Host "  OK deploy/$f" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing Nginx subpath on EC2..." -ForegroundColor Cyan
ssh -i $SshKeyPath $Ec2UserAtHost "chmod +x $remoteDeploy/install-subpath-on-ec2.sh && sudo bash $remoteDeploy/install-subpath-on-ec2.sh"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done (if no errors above)" -ForegroundColor Green
Write-Host "Teacher URL: https://api.sagp-qp.com/teacher-export/" -ForegroundColor Green
Write-Host ""
Write-Host "Supabase: Authentication -> URL Configuration" -ForegroundColor Yellow
Write-Host "  Site URL: https://api.sagp-qp.com/teacher-export/" -ForegroundColor Yellow
Write-Host "  Redirect URLs: same as above" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green
