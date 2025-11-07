var builder = DistributedApplication.CreateBuilder(args);

var redis = builder.AddRedis("redis")
					.WithRedisInsight();

var syncfusionLicenseKey = builder.AddParameter("syncfusion-license-key", secret: true);

var server = builder.AddProject<Projects.SyncfusionCollab_Server>("server")
	.WithReference(redis, "RedisConnectionString")
	.WaitFor(redis)
	.WithExternalHttpEndpoints()
	.WithEnvironment("Syncfusion__LicenseKey", syncfusionLicenseKey);

var clientWorkingDirectory = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "Client", "SyncfusionCollab.Client"));

var client = builder.AddNpmApp("client", clientWorkingDirectory)
	.WithHttpEndpoint(targetPort: 3000)
	.WithEnvironment("PORT", "3000")
	.WithEnvironment("REACT_APP_API_BASE", server.GetEndpoint("http"))
	.WithEnvironment("REACT_APP_SYNCFUSION_LICENSE_KEY", syncfusionLicenseKey);

client.WithReference(server);

builder.Build().Run();
