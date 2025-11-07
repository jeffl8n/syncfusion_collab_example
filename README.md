# Syncfusion Collaborative Editing Sample

This workspace combines a collaborative editing ASP.NET Core API, a React client, and a .NET Aspire AppHost that orchestrates both services together with a Redis cache.

## Projects

- `src/Server/SyncfusionCollab.Server` – ASP.NET Core 8 Web API that hosts the Syncfusion Document Editor collaborative editing endpoints and SignalR hub. Redis is used to synchronize operations between users.
- `src/Client/SyncfusionCollab.Client` – React (TypeScript) single-page application providing the document editor UI. The API base URL is read from the `REACT_APP_API_BASE` environment variable.
- `src/AppHost/SyncfusionCollab.AppHost` – .NET Aspire AppHost that runs the API, client, and a Redis container from a single dashboard experience.

## Prerequisites

- .NET 8 SDK or later
- Node.js 20 (includes npm)
- Docker Desktop (required by Aspire to launch the Redis container)
- A Syncfusion Document Editor license (set the license key via `Syncfusion.Licensing.SyncfusionLicenseProvider.RegisterLicense` before building if your environment requires it)

## Getting Started

1. **Restore dependencies**
   ```pwsh
   dotnet restore SyncfusionCollab.sln
   ```
   The AppHost project runs `npm install` for the React client automatically before the first build.

2. **Run everything with Aspire**
   ```pwsh
   dotnet run --project src/AppHost/SyncfusionCollab.AppHost
   ```
   The Aspire dashboard opens in the browser. From the dashboard you can start or stop the API (`server`), Redis, and the React client (`client`). The client is exposed through the dashboard and is already configured to call the API through the `REACT_APP_API_BASE` environment variable.

3. **Direct runs (optional)**
   - API only:
     ```pwsh
     dotnet run --project src/Server/SyncfusionCollab.Server
     ```
     Ensure the `ConnectionStrings:RedisConnectionString` value is set (for example to an external Redis instance).
   - Client only:
     ```pwsh
     cd src/Client/SyncfusionCollab.Client
     npm start
     ```
     Set `REACT_APP_API_BASE` before launching if the API is not running through Aspire.

## Configuration

- **Redis** – When orchestrated through Aspire, the Redis container name is `redis` and its connection string is injected into the API as `ConnectionStrings:RedisConnectionString`. To connect to an external cache, update `appsettings.json` or override the `ConnectionStrings__RedisConnectionString` environment variable.
- **Document templates** – Sample documents are stored in `src/Server/SyncfusionCollab.Server/wwwroot`. Replace these files with your own templates as needed.

## Tests

No automated tests ship with the sample. After making changes you can validate the build with:
```pwsh
dotnet build SyncfusionCollab.sln
```

## Next Steps

- Configure authentication/authorization appropriate for your environment.
- Set up CI pipelines to run `dotnet build` and `npm test`.
- Add telemetry or logging integrations supported by .NET Aspire.
