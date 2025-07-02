#pragma warning disable ASPIRECOSMOSDB001
using Aspire.Hosting;
using Aspire.Hosting.Testing;

var builder = DistributedApplicationTestingBuilder.CreateAsync<Program>().GetAwaiter().GetResult();

builder.Services.ConfigureHttpClientDefaults(clientBuilder =>
{
    clientBuilder.AddStandardResilienceHandler();
});

var app = builder.BuildAsync().GetAwaiter().GetResult();

try
{
    Console.WriteLine("Starting the application...");
    app.StartAsync().GetAwaiter().GetResult();
    
    Console.WriteLine("App started successfully! Waiting 30 seconds...");
    await Task.Delay(30000);
    
    await app.StopAsync();
    Console.WriteLine("Test completed successfully");
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
    if (ex.Message.Contains("cosmos_api"))
    {
        Console.WriteLine("REPRODUCED: Found the cosmos_api schema error!");
    }
    throw;
}

public class Program 
{
    public static void Main(string[] args)
    {
        var builder = DistributedApplication.CreateBuilder(args);

        var cosmos = builder
            .AddAzureCosmosDB("database")
            .RunAsPreviewEmulator(options =>
            {
                options.WithLifetime(ContainerLifetime.Persistent);
            });

        var database = cosmos.AddCosmosDatabase("MyDb");
        var container = database.AddContainer("Users", "/emailAddress");

        builder.Build().Run();
    }
}
