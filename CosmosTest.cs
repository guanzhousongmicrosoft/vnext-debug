using Microsoft.Azure.Cosmos;

// Simple test application to connect directly to Cosmos DB emulator
// This is a standalone test separate from the Aspire application

const string connectionString = "AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==";

try
{
    Console.WriteLine("Connecting to Cosmos DB Emulator...");
    
    using var cosmosClient = new CosmosClient(connectionString, new CosmosClientOptions
    {
        HttpClientFactory = () => new HttpClient(new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = (_, _, _, _) => true
        })
    });

    // Create database and container
    var database = await cosmosClient.CreateDatabaseIfNotExistsAsync("TestDB");
    var container = await database.Database.CreateContainerIfNotExistsAsync("TestContainer", "/id");

    Console.WriteLine("Successfully connected to Cosmos DB Emulator!");
    Console.WriteLine($"Database: {database.Database.Id}");
    Console.WriteLine($"Container: {container.Container.Id}");

    // Insert a test item
    var testItem = new
    {
        id = Guid.NewGuid().ToString(),
        name = "Test Item",
        timestamp = DateTime.UtcNow
    };

    var response = await container.Container.CreateItemAsync(testItem, new PartitionKey(testItem.id));
    Console.WriteLine($"Created item with ID: {response.Resource.id}");

    // Query the item back
    var query = new QueryDefinition("SELECT * FROM c WHERE c.id = @id")
        .WithParameter("@id", testItem.id);
    
    using var iterator = container.Container.GetItemQueryIterator<dynamic>(query);
    while (iterator.HasMoreResults)
    {
        var results = await iterator.ReadNextAsync();
        foreach (var item in results)
        {
            Console.WriteLine($"Retrieved item: {item}");
        }
    }

    Console.WriteLine("Test completed successfully!");
}
catch (Exception ex)
{
    Console.WriteLine($"Error: {ex.Message}");
    Console.WriteLine("Make sure the Cosmos DB emulator is running on https://localhost:8081");
}