using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;
using Projects;

// Run all local resources with Aspire for testing (issue #199 pattern)
var builder = DistributedApplicationTestingBuilder
    .CreateAsync<AspireCosmosSimple>().GetAwaiter().GetResult();

builder.Services.ConfigureHttpClientDefaults(clientBuilder =>
{
    clientBuilder.AddStandardResilienceHandler();
});

var app = builder.BuildAsync().GetAwaiter().GetResult();

// Start app; if the emulator triggers the schema error, this is where it shows
app.StartAsync().GetAwaiter().GetResult();

Console.WriteLine("TEST_OK: App started");
