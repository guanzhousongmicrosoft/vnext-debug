using Aspire.Hosting;
using Aspire.Hosting.Azure;

// Set required environment variables for Aspire
Environment.SetEnvironmentVariable("ASPNETCORE_URLS", "http://localhost:18888");
Environment.SetEnvironmentVariable("ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL", "http://localhost:18889");
Environment.SetEnvironmentVariable("ASPIRE_ALLOW_UNSECURED_TRANSPORT", "true");

// Create a builder for distributed application
var builder = DistributedApplication.CreateBuilder(args);

// Add Azure Cosmos DB resource and configure it to run as a preview emulator
var cosmos = builder
    .AddAzureCosmosDB("database")
    .RunAsPreviewEmulator(emulator => emulator.WithGatewayPort(7777));

// Add a database and container to the Cosmos DB resource
var database = cosmos.AddCosmosDatabase("MyDb");
var container = database.AddContainer("Users", "/emailAddress");

Console.WriteLine("Building and starting Aspire application with Cosmos DB emulator...");

// Build and run the application
var app = builder.Build();
await app.StartAsync();

Console.WriteLine("Cosmos DB emulator is starting...");

// Wait a bit for the emulator to fully initialize
await Task.Delay(10000);

Console.WriteLine("Cosmos DB emulator is running!");
Console.WriteLine("The Cosmos DB emulator connection string is: AccountEndpoint=https://localhost:7777/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==");
Console.WriteLine("Database: MyDb");
Console.WriteLine("Container: Users");
Console.WriteLine("Press any key to stop the application...");
Console.ReadKey();

// Clean up resources
await app.StopAsync();
