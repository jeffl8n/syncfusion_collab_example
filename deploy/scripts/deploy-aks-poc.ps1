<#
.SYNOPSIS
Deploys a full POC stack to AKS: Redis (Bitnami), API (ASP.NET), and UI (React via NGINX).

.DESCRIPTION
Builds and pushes Docker images to ACR, deploys Redis to AKS, deploys the API as a LoadBalancer,
waits for the API external IP, then builds the UI image with that API base URL and deploys the UI
as a LoadBalancer. Works best for quick POCs.

.PARAMETER AcrName
Azure Container Registry name (e.g., crsyncfusion).

.PARAMETER AksName
AKS cluster name (e.g., aks-syncfusion).

.PARAMETER ResourceGroup
Resource group of the AKS cluster. If omitted, resolved from AKS.

.PARAMETER Namespace
Kubernetes namespace to deploy into. Default: collab

.PARAMETER Tag
Image tag for both images. Default: poc-<yyyyMMdd-HHmm>

.PARAMETER SyncfusionLicenseKey
Syncfusion license key for both API and UI.

.PARAMETER UseAcrBuild
If set, builds images in ACR (no local Docker required). Otherwise uses local Docker.

.EXAMPLE
./deploy-aks-poc.ps1 -AcrName crsyncfusion -AksName aks-syncfusion -SyncfusionLicenseKey "<key>"

.EXAMPLE
./deploy-aks-poc.ps1 -AcrName crsyncfusion -AksName aks-syncfusion -ResourceGroup rg-collab -Namespace collab -Tag 1.0.0 -UseAcrBuild -SyncfusionLicenseKey "<key>"
#>

[CmdletBinding(SupportsShouldProcess=$false)]
param(
  [Parameter(Mandatory=$true)] [string]$AcrName,
  [Parameter(Mandatory=$true)] [string]$AksName,
  [Parameter(Mandatory=$false)] [string]$ResourceGroup,
  [Parameter(Mandatory=$false)] [string]$Namespace = "collab",
  [Parameter(Mandatory=$false)] [string]$Tag = $(Get-Date -Format "'poc-'yyyyMMdd-HHmm"),
  [Parameter(Mandatory=$false)] [string]$SyncfusionLicenseKey,
  [Parameter(Mandatory=$false)] [string]$KeyVaultName,
  [Parameter(Mandatory=$false)] [string]$KeyVaultSecretName = "syncfusion-license",
  [switch]$UseAcrBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Cli($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required CLI '$cmd' not found in PATH."
  }
}

function Ensure-DockerRunning() {
  try {
    docker info 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) { throw "docker info failed" }
  } catch {
    throw "Docker engine is not running or inaccessible. Start Docker Desktop (or your Docker service) or re-run with -UseAcrBuild to avoid local Docker."
  }
}

function Wait-ForAcrTag {
  param(
    [Parameter(Mandatory=$true)] [string]$AcrName,
    [Parameter(Mandatory=$true)] [string]$Repository,
    [Parameter(Mandatory=$true)] [string]$Tag,
    [int]$TimeoutSeconds = 300
  )
  Write-Host ("Waiting for ACR tag '{0}:{1}' to be available..." -f $Repository, $Tag) -ForegroundColor Cyan
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $found = az acr repository show-tags -n $AcrName --repository $Repository --query "[?@=='$Tag']" -o tsv 2>$null
    if ($found) { Write-Host ("Tag available: {0}:{1}" -f $Repository, $Tag) -ForegroundColor Green; return }
    Start-Sleep -Seconds 5
  } while ((Get-Date) -lt $deadline)
  throw ("Timed out waiting for ACR tag '{0}:{1}' to be available." -f $Repository, $Tag)
}

Write-Host "Validating CLIs..." -ForegroundColor Cyan
Assert-Cli az
Assert-Cli kubectl
Assert-Cli helm
if (-not $UseAcrBuild) { Assert-Cli docker }

Write-Host "Resolving ACR login server..." -ForegroundColor Cyan
$AcrLoginServer = az acr show -n $AcrName --query loginServer -o tsv
if (-not $AcrLoginServer) { throw "Failed to resolve ACR login server for $AcrName" }

if (-not $ResourceGroup) {
  Write-Host "Resolving AKS resource group..." -ForegroundColor Cyan
  $ResourceGroup = az aks list --query "[?name=='$AksName'].resourceGroup | [0]" -o tsv
  if (-not $ResourceGroup) { throw "Failed to resolve resource group for AKS '$AksName'" }
}

Write-Host "Checking if ACR '$AcrName' is already attached to AKS '$AksName'..." -ForegroundColor Cyan
$acrId = az acr show -n $AcrName --query id -o tsv
$principal = az aks show -n $AksName -g $ResourceGroup --query "identityProfile.kubeletidentity.objectId" -o tsv
if (-not $principal) {
  # Fallback to legacy service principal clientId
  $principal = az aks show -n $AksName -g $ResourceGroup --query "servicePrincipalProfile.clientId" -o tsv
}
$hasAcrPull = az role assignment list --assignee $principal --scope $acrId --query "[?roleDefinitionName=='AcrPull'] | length(@)" -o tsv
if ([string]::IsNullOrWhiteSpace($hasAcrPull)) { $hasAcrPull = "0" }
if ([int]$hasAcrPull -gt 0) {
  Write-Host "ACR already attached (AcrPull role exists). Skipping attach." -ForegroundColor Yellow
} else {
  Write-Host "Attaching ACR '$AcrName' to AKS '$AksName' in RG '$ResourceGroup'..." -ForegroundColor Cyan
  az aks update -n $AksName -g $ResourceGroup --attach-acr $AcrName | Out-Null
}

Write-Host "Getting AKS credentials (may merge kubeconfig)..." -ForegroundColor Cyan
az aks get-credentials -n $AksName -g $ResourceGroup --overwrite-existing | Out-Null

Write-Host "Ensuring namespace '$Namespace' exists..." -ForegroundColor Cyan
kubectl get ns $Namespace 2>$null 1>$null; if ($LASTEXITCODE -ne 0) { kubectl create ns $Namespace | Out-Null }

Write-Host "Ensuring Redis exists in namespace '$Namespace'..." -ForegroundColor Cyan
helm repo add bitnami https://charts.bitnami.com/bitnami 1>$null 2>$null
helm repo update 1>$null 2>$null

$redisReleaseExists = $false
helm status redis -n $Namespace 1>$null 2>$null
if ($LASTEXITCODE -eq 0) { $redisReleaseExists = $true }

if (-not $redisReleaseExists) {
  Write-Host "Installing Redis (Bitnami) as release 'redis'..." -ForegroundColor Cyan
  helm upgrade --install redis bitnami/redis `
    -n $Namespace `
    --set architecture=standalone `
    --set auth.enabled=true `
    --set master.persistence.enabled=false | Out-Null

  Write-Host "Waiting for Redis pod to be ready..." -ForegroundColor Cyan
  kubectl rollout status statefulset/redis-master -n $Namespace --timeout=180s | Out-Null
} else {
  Write-Host "Redis release 'redis' already exists. Skipping install." -ForegroundColor Yellow
  # If the standard Bitnami statefulset exists, wait for it to be ready; otherwise continue.
  kubectl get statefulset/redis-master -n $Namespace 1>$null 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Ensuring existing Redis is ready..." -ForegroundColor Cyan
    kubectl rollout status statefulset/redis-master -n $Namespace --timeout=180s | Out-Null
  }
}

Write-Host "Retrieving Redis password..." -ForegroundColor Cyan
kubectl get secret redis -n $Namespace 1>$null 2>$null
if ($LASTEXITCODE -ne 0) {
  throw "Kubernetes Secret 'redis' not found in namespace '$Namespace'. If you installed Redis with a different release name, create a secret named 'redis' with key 'redis-password' or adjust the script."
}
$b64 = kubectl get secret redis -n $Namespace -o jsonpath='{.data.redis-password}'
$REDIS_PASSWORD = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
if (-not $REDIS_PASSWORD) { throw "Failed to retrieve Redis password." }

# License key handling: prefer Key Vault, fallback to provided parameter
$uiLicenseSecretName = "syncfusion-license"
if ($KeyVaultName) {
  Write-Host "Fetching license key from Key Vault '$KeyVaultName' (secret '$KeyVaultSecretName')..." -ForegroundColor Cyan
  $kvValue = az keyvault secret show --vault-name $KeyVaultName --name $KeyVaultSecretName --query value -o tsv
  if (-not $kvValue) { throw "Key Vault secret not found or empty: $KeyVaultName/$KeyVaultSecretName" }
  Write-Host "Creating/updating Kubernetes secret '$uiLicenseSecretName' in namespace '$Namespace' from Key Vault..." -ForegroundColor Cyan
  $tmp = New-TemporaryFile
  try {
    @(
      "apiVersion: v1",
      "kind: Secret",
      "metadata:",
      "  name: $uiLicenseSecretName",
      "  namespace: $Namespace",
      "type: Opaque",
      "stringData:",
      "  licenseKey: '$kvValue'"
    ) | Set-Content -NoNewline:$false -Path $tmp.FullName -Encoding UTF8
    kubectl apply -f $tmp.FullName | Out-Null
  } finally { Remove-Item -Force $tmp.FullName -ErrorAction SilentlyContinue }
} elseif ($SyncfusionLicenseKey) {
  Write-Host "Creating/updating Kubernetes secret '$uiLicenseSecretName' in namespace '$Namespace' from provided license..." -ForegroundColor Cyan
  kubectl create secret generic $uiLicenseSecretName -n $Namespace --from-literal=licenseKey=$SyncfusionLicenseKey --dry-run=client -o yaml | kubectl apply -f - | Out-Null
} else {
  throw "No license provided. Supply -KeyVaultName/-KeyVaultSecretName or -SyncfusionLicenseKey."
}

# Build and push API image
$ApiImage = "$AcrLoginServer/syncfusion-collab-server:$Tag"
$UiImage  = "$AcrLoginServer/syncfusion-collab-client:$Tag"

if ($UseAcrBuild) {
  Write-Host "Building API image in ACR: $ApiImage" -ForegroundColor Cyan
  az acr build -r $AcrName -t $ApiImage -f src/Server/SyncfusionCollab.Server/Dockerfile . | Out-Null
} else {
  Ensure-DockerRunning
  Write-Host "Logging into ACR..." -ForegroundColor Cyan
  az acr login -n $AcrName | Out-Null
  Write-Host "Building API image locally: $ApiImage" -ForegroundColor Cyan
  docker build -f src/Server/SyncfusionCollab.Server/Dockerfile -t $ApiImage .
  Write-Host "Pushing API image: $ApiImage" -ForegroundColor Cyan
  docker push $ApiImage
}

# Ensure API image tag exists in ACR before deploying
$ServerRepo = "syncfusion-collab-server"
Wait-ForAcrTag -AcrName $AcrName -Repository $ServerRepo -Tag $Tag -TimeoutSeconds 600

Write-Host "Deploying API via Helm (LoadBalancer)..." -ForegroundColor Cyan
$redisConn = "redis-master.$Namespace.svc.cluster.local:6379,password=$REDIS_PASSWORD,ssl=False"

# Avoid CLI parsing of commas by storing the Redis connection string in a Secret
$redisConnSecretName = "redis-conn"
kubectl create secret generic $redisConnSecretName -n $Namespace `
  --from-literal=connectionString=$redisConn `
  --dry-run=client -o yaml | kubectl apply -f - | Out-Null

helm upgrade --install collab-api deploy/helm/syncfusion-collab-api `
  -n $Namespace `
  --set image.repository="$AcrLoginServer/syncfusion-collab-server" `
  --set image.tag="$Tag" `
  --set image.pullPolicy=Always `
  --set redis.existingSecret="$redisConnSecretName" `
  --set licenseSecret.existing="$uiLicenseSecretName" `
  --set service.type=LoadBalancer | Out-Null

Write-Host "Waiting for API service external address (IP or hostname)..." -ForegroundColor Cyan
$ApiSvcName = "collab-api-syncfusion-collab-api"
$apiAddr = $null
for ($i=0; $i -lt 60 -and -not $apiAddr; $i++) {
  Start-Sleep -Seconds 10
  $ip = kubectl get svc $ApiSvcName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
  $apiHostname = kubectl get svc $ApiSvcName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
  if ($ip) { $apiAddr = $ip }
  elseif ($apiHostname) { $apiAddr = $apiHostname }
}
if (-not $apiAddr) {
  Write-Host "Service status (debug):" -ForegroundColor Yellow
  kubectl get svc $ApiSvcName -n $Namespace -o yaml | Select-String -Pattern "type:|status:" -Context 2,2 | ForEach-Object { $_ }
  throw "API external address not assigned after timeout. Ensure a Public LoadBalancer is available and service.type=LoadBalancer."
}
$ApiBaseUrl = "http://$apiAddr"
Write-Host "API external URL: $ApiBaseUrl" -ForegroundColor Green

# Build and push UI image (needs API URL baked at build time)
if ($UseAcrBuild) {
  Write-Host "Building UI image in ACR: $UiImage" -ForegroundColor Cyan
  az acr build -r $AcrName -t $UiImage -f src/Client/SyncfusionCollab.Client/Dockerfile . | Out-Null
} else {
  Ensure-DockerRunning
  Write-Host "Building UI image locally: $UiImage" -ForegroundColor Cyan
  docker build -f src/Client/SyncfusionCollab.Client/Dockerfile -t $UiImage .
  Write-Host "Pushing UI image: $UiImage" -ForegroundColor Cyan
  docker push $UiImage
}

# Ensure UI image tag exists in ACR before deploying
$ClientRepo = "syncfusion-collab-client"
Wait-ForAcrTag -AcrName $AcrName -Repository $ClientRepo -Tag $Tag -TimeoutSeconds 600

Write-Host "Deploying UI via Helm (LoadBalancer)..." -ForegroundColor Cyan
Write-Host "Preparing UI Helm values for secret-based license injection..." -ForegroundColor Cyan
$uiValuesFile = New-TemporaryFile
@(
  "env:",
  "  extra:",
  "    - name: REACT_APP_SYNCFUSION_LICENSE_KEY",
  "      valueFrom:",
  "        secretKeyRef:",
  "          name: $uiLicenseSecretName",
  "          key: licenseKey"
) | Set-Content -NoNewline:$false -Path $uiValuesFile.FullName -Encoding UTF8

helm upgrade --install collab-ui deploy/helm/syncfusion-collab-ui `
  -n $Namespace `
  --set image.repository="$AcrLoginServer/syncfusion-collab-client" `
  --set image.tag="$Tag" `
  --set image.pullPolicy=Always `
  --set service.type=LoadBalancer `
  --set env.apiBaseUrl="$ApiBaseUrl" `
  -f $uiValuesFile.FullName | Out-Null

Remove-Item -Force $uiValuesFile.FullName -ErrorAction SilentlyContinue

Write-Host "Waiting for UI service external address (IP or hostname)..." -ForegroundColor Cyan
$UiSvcName = "collab-ui-syncfusion-collab-ui"
$uiAddr = $null
for ($i=0; $i -lt 60 -and -not $uiAddr; $i++) {
  Start-Sleep -Seconds 10
  $ip = kubectl get svc $UiSvcName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
  $uiHostname = kubectl get svc $UiSvcName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
  if ($ip) { $uiAddr = $ip }
  elseif ($uiHostname) { $uiAddr = $uiHostname }
}
if (-not $uiAddr) {
  Write-Host "Service status (debug):" -ForegroundColor Yellow
  kubectl get svc $UiSvcName -n $Namespace -o yaml | Select-String -Pattern "type:|status:" -Context 2,2 | ForEach-Object { $_ }
  throw "UI external address not assigned after timeout. Ensure a Public LoadBalancer is available and service.type=LoadBalancer."
}
$UiUrl = "http://$uiAddr"

Write-Host ""; Write-Host "POC deployment complete" -ForegroundColor Green
Write-Host "- Namespace:        $Namespace"
Write-Host "- ACR login server: $AcrLoginServer"
Write-Host "- API image:        $ApiImage"
Write-Host "- UI image:         $UiImage"
Write-Host "- Redis conn str:   $redisConn"
Write-Host "- API URL:          $ApiBaseUrl" -ForegroundColor Green
Write-Host "- UI URL:           $UiUrl" -ForegroundColor Green
