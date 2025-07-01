#pragma warning disable ASPIRECOSMOSDB001 // Disable warning for preview emulator

var builder = DistributedApplication.CreateBuilder(args);

// Add Azure Cosmos DB using the Linux-based emulator with the vnext-preview image
var cosmos = builder.AddAzureCosmosDB("cosmos-db")
    .RunAsPreviewEmulator(emulator =>
    {
        // Enable Data Explorer UI - allows viewing data via web interface
        emulator.WithDataExplorer();
        
        // Enable data persistence - data survives container restarts
        emulator.WithDataVolume();
        
        // Configure specific gateway port for consistent access
        emulator.WithGatewayPort(8081);
        
        // Set persistent lifetime so container persists across app restarts
        emulator.WithLifetime(ContainerLifetime.Persistent);
    });

// Add a database and container
var database = cosmos.AddCosmosDatabase("SampleDB");
var container = database.AddContainer("Items", "/id");

// Add the API project
var api = builder.AddProject<Projects.CosmosEmulatorApp_Api>("api")
    .WithReference(cosmos);

builder.Build().Run();
