using Aspire.Hosting;
using Aspire.Hosting.Azure;

var builder = DistributedApplication.CreateBuilder(args);

var cosmos = builder
    .AddAzureCosmosDB("database")
    .RunAsPreviewEmulator(options =>
    {
        options.WithLifetime(ContainerLifetime.Persistent);
    });

var database = cosmos.AddCosmosDatabase("MyDb");
var container = database.AddContainer("Users", "/emailAddress");

var app = builder.Build();
await app.StartAsync();
