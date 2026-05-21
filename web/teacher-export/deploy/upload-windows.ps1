# 從 Windows 上傳教師匯出網站到 EC2
# 用法：在 PowerShell 於本 deploy 資料夾執行
#   powershell -ExecutionPolicy Bypass -File .\upload-windows.ps1

$ErrorActionPreference = "Stop"
$DeployDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebRoot = Split-Path -Parent $DeployDir
$ParamsFile = Join-Path $DeployDir "deploy-params.ps1"

if (-not (Test-Path $ParamsFile)) {
    Write-Host "請先建立 deploy-params.ps1" -ForegroundColor Red
    Write-Host "  Copy-Item deploy-params.example.ps1 deploy-params.ps1" -ForegroundColor Yellow
    Write-Host "  並填入 EC2 IP、.pem 路徑" -ForegroundColor Yellow
    exit 1
}

. $ParamsFile

if (-not (Test-Path $SshKeyPath)) {
    Write-Host "找不到 SSH 金鑰: $SshKeyPath" -ForegroundColor Red
    exit 1
}

$files = @(
    "index.html",
    "app.js",
    "styles.css",
    "config.js",
    "assets/sgq-logo.png"
)

Write-Host "上傳到 $Ec2UserAtHost : $RemoteWebRoot" -ForegroundColor Cyan

ssh -i $SshKeyPath -o StrictHostKeyChecking=accept-new $Ec2UserAtHost "sudo mkdir -p $RemoteWebRoot/assets && sudo chown -R `$(whoami):`$(whoami) $RemoteWebRoot"

foreach ($f in $files) {
    $local = Join-Path $WebRoot $f
    if (-not (Test-Path $local)) {
        Write-Host "缺少檔案: $local" -ForegroundColor Red
        exit 1
    }
    $remoteDir = Split-Path "${RemoteWebRoot}/$f" -Parent
    ssh -i $SshKeyPath $Ec2UserAtHost "mkdir -p $remoteDir" | Out-Null
    scp -i $SshKeyPath $local "${Ec2UserAtHost}:${RemoteWebRoot}/$f"
    Write-Host "  OK $f" -ForegroundColor Green
}

Write-Host ""
Write-Host "上傳完成。請在 EC2 執行 install-on-ec2.sh 設定 Nginx（見 DEPLOY_完整教學.md）" -ForegroundColor Green
