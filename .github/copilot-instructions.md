# Copilot Instructions for syncfusion_collab_example
- Keep this checklist handy when implementing features so you plug into the existing collaboration flow correctly.

## Architecture
- The solution is orchestrated by `src/AppHost/SyncfusionCollab.AppHost`, which boots the ASP.NET Core API (`server`), the React client (`client`), and a Redis container via .NET Aspire.
- Aspire wires the client’s `SYNCFUSION_API_BASE` to the server’s exposed HTTP endpoint and shares the `syncfusion-license-key` secret with both tiers.
- `src/Server/SyncfusionCollab.Server` hosts REST endpoints plus the SignalR hub (`documenteditorhub`) that the React app subscribes to for real-time document updates.
- The server persists collaborative operations in Redis using Lua scripts defined in `Model/CollaborativeEditingHelper.cs`; they manage versioning, trimming, and a background save queue.
- `QueuedHostedService` drains `IBackgroundTaskQueue` to apply flushed operations back into the source `.docx` stored under `wwwroot` (default `Giant Panda.docx`).
- `src/Client/SyncfusionCollab.Client` renders the Syncfusion DocumentEditor with collaborative editing enabled and uses SignalR to sync actions.

## Critical Workflows
- End-to-end run: `dotnet run --project src/AppHost/SyncfusionCollab.AppHost` (requires Docker Desktop for Redis). Aspire auto-restores npm packages on first build.
- API-only run: `dotnet run --project src/Server/SyncfusionCollab.Server` after setting `ConnectionStrings__RedisConnectionString`.
- Client-only run: `cd src/Client/SyncfusionCollab.Client && npm start` with `SYNCFUSION_API_BASE` and `SYNCFUSION_LICENSE_KEY` exported.
- Build validation: `dotnet build SyncfusionCollab.sln`; the client relies on Create React App scripts (`npm test`, `npm run build`).

## Server Patterns
- Always ensure a Syncfusion license key is present; `Program.cs` throws early if `Syncfusion__LicenseKey`/`SYNCFUSION_LICENSE_KEY` is missing.
- Use `CollaborativeEditingController` for document lifecycle: `ImportFile` loads the base document + pending Redis ops, `UpdateAction` writes new operations, `GetActionsFromServer` backfills missed changes.
- `CollaborativeEditingHelper.SaveThreshold` (default 100) controls when Redis batches are dequeued to background save; tweak alongside Lua scripts if adjusting persistence behavior.
- Background saves enqueue `SaveInfo` objects; non-partial saves (triggered on last user disconnect) clear Redis keys to avoid replays.
- SignalR hub membership is tracked in Redis hashes (`*_user_info`, `ej_de_connection_id_room_mapping`); reuse helpers instead of rolling custom tracking.

## Client Patterns
- `DocumentEditor.tsx` configures the editor; the `contentChange` hook must call `collaborativeEditingHandler.sendActionToServer` with `Operation[]` or remote clients fall out of sync.
- Room identity comes from the `?id=` query string; new documents create a random room and push it to browser history—preserve this when adding routing.
- When extending toolbar/UI, inject modules via `DocumentEditorContainerComponent.Inject` before mount and hide tabs using the exposed `ribbon` instance.
- `TitleBar` manages presence avatars; call `addUser`/`removeUser` with `ActionInfo` payloads from SignalR to keep the UI consistent.

## Configuration Notes
- Redis connection string is read from `ConnectionStrings:Redis` or `ConnectionStrings:RedisConnectionString`; Aspire supplies it via resource references.
- Source documents live in `wwwroot`; update them when changing defaults, and keep filenames consistent with `ImportFile` parameters.
- Client license registration occurs in `src/index.tsx` via `registerLicense`; warn users if `SYNCFUSION_LICENSE_KEY` is absent rather than failing hard.
- StackExchange.Redis is configured with channel prefix `docedit`; reuse that prefix when publishing custom pub/sub messages to avoid collisions.

## Troubleshooting Tips
- If collaborative edits stop propagating, inspect Redis lists `roomName`, `roomName_actions_to_remove`, and revision keys to ensure Lua scripts are trimming correctly.
- Background saves throw if the document cannot be written; verify the hosted environment grants write access to `wwwroot` when deploying.
- Unexpected reconnect loops usually indicate the WebSocket endpoint is unreachable; confirm Aspire exposed ports or align `SYNCFUSION_API_BASE` when running components separately.
