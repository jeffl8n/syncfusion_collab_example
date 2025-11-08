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
