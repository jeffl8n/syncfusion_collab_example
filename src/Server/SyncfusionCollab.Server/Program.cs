using StackExchange.Redis;
using SyncfusionCollab.Server.Hubs;
using SyncfusionCollab.Server.Service;

var builder = WebApplication.CreateBuilder(args);

var syncfusionLicenseKey = builder.Configuration["Syncfusion:LicenseKey"]
    ?? builder.Configuration["SyncfusionLicenseKey"]
    ?? Environment.GetEnvironmentVariable("SYNCFUSION_LICENSE_KEY");

if (string.IsNullOrWhiteSpace(syncfusionLicenseKey))
{
    throw new InvalidOperationException("Syncfusion license key is not configured. Set the Syncfusion__LicenseKey secret in Aspire or provide the SYNCFUSION_LICENSE_KEY environment variable.");
}

Syncfusion.Licensing.SyncfusionLicenseProvider.RegisterLicense(syncfusionLicenseKey);

builder.Services.AddControllersWithViews();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAllOrigins", builder =>
    {
        builder.AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader();
    });
});

var connectionString = builder.Configuration.GetConnectionString("Redis")
    ?? builder.Configuration.GetConnectionString("RedisConnectionString")
    ?? builder.Configuration["ConnectionStrings:RedisConnectionString"]
    ?? throw new InvalidOperationException("Redis connection string is not configured.");

//Configure SignalR
builder.Services.AddSignalR().AddStackExchangeRedis(connectionString, options =>
{
    options.Configuration.ChannelPrefix = RedisChannel.Literal("docedit");
});


builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = connectionString;
});

builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
{
    var configuration = ConfigurationOptions.Parse(connectionString, true);
    return ConnectionMultiplexer.Connect(configuration);
});

builder.Services.AddSingleton<IBackgroundTaskQueue>(ctx =>
{
    //Configure maximum queue capacity.
    return new BackgroundTaskQueue(200);
});
builder.Services.AddHostedService<QueuedHostedService>();

var app = builder.Build();

app.UseStaticFiles();

app.UseRouting();

app.UseCors();
app.UseAuthorization();

app.MapControllers();

app.MapHub<DocumentEditorHub>("/documenteditorhub");

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=LogIn}/{userName?}/{id?}");

app.Run();
