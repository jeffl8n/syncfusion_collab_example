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

var config = builder.Configuration;
var redisConfig = config.GetSection("ConnectionStrings");
var connectionString = redisConfig["RedisConnectionString"];

//Configure SignalR
builder.Services.AddSignalR().AddStackExchangeRedis(connectionString, options =>
{
    options.Configuration.ChannelPrefix = "docedit";
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

app.MapHub<DocumentEditorHub>("/documenteditorhub");

app.MapControllers();

app.UseAuthorization();

app.UseEndpoints(endpoints =>
{
    endpoints.MapControllerRoute(
        name: "default",
        pattern: "{controller=Home}/{action=LogIn}/{userName?}/{id?}");
});

app.Run();
