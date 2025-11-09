# Helm Charts

Two standalone Helm charts are provided for deploying the collaborative editing sample to Azure Kubernetes Service (AKS) or any Kubernetes cluster.

- `syncfusion-collab-api`: Packages the ASP.NET Core API + SignalR hub. Configure `redis.connectionString` (or `redis.existingSecret`) so the service can reach your Redis instance, and supply the Syncfusion license via `licenseSecret` values or an existing secret.
- `syncfusion-collab-ui`: Packages the React client served from NGINX. Set `env.apiBaseUrl` to the external URL of the API (or rebuild the client container with the correct base URL). Optionally provide the Syncfusion license key if your image reads it at runtime.

Run `helm install` separately for each chart, for example:

```powershell
helm upgrade --install collab-api ./syncfusion-collab-api `\
  --set image.repository=<server-image> `\
  --set redis.connectionString=<redis-connection-string> `\
  --set licenseSecret.value="<syncfusion-license-key>"

helm upgrade --install collab-ui ./syncfusion-collab-ui `
  --set image.repository=<client-image> `
  --set env.apiBaseUrl="https://collab-api.example.com"
```

Supply additional values or YAML files as needed for production settings (ingress, TLS, resource limits, etc.).

## POC Script (AKS + Redis + Images)

For a quick proof-of-concept, use the PowerShell script to build/push images to ACR, deploy Redis into AKS, deploy the API (LoadBalancer), wait for its external IP, then build and deploy the UI (LoadBalancer):

```
pwsh ./deploy/scripts/deploy-aks-poc.ps1 `
  -AcrName crsyncfusion `
  -AksName aks-syncfusion `
  -SyncfusionLicenseKey "<your-syncfusion-license-key>" `
  -UseAcrBuild
```

Notes:
- Requires Azure CLI, kubectl, and helm. If you omit `-UseAcrBuild`, you also need Docker.
- The script creates/uses the `collab` namespace and tags images with a `poc-<timestamp>` by default.
- Both API and UI services are exposed as `LoadBalancer` for simplicity in a POC.
