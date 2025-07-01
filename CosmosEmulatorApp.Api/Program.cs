using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Add Azure Cosmos DB client
builder.AddAzureCosmosClient("cosmos-db");

// Add API explorer and Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// API endpoints
app.MapGet("/api/items", async (CosmosClient cosmosClient) =>
{
    try
    {
        var database = cosmosClient.GetDatabase("SampleDB");
        var container = database.GetContainer("Items");
        
        var query = new QueryDefinition("SELECT * FROM c");
        var iterator = container.GetItemQueryIterator<dynamic>(query);
        
        var items = new List<dynamic>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            items.AddRange(response);
        }
        
        return Results.Ok(items);
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error retrieving items: {ex.Message}");
    }
})
.WithName("GetTodoItems")
.WithOpenApi();

app.MapGet("/api/items/{id}", async (string id, CosmosClient cosmosClient) =>
{
    try
    {
        var database = cosmosClient.GetDatabase("SampleDB");
        var container = database.GetContainer("Items");
        
        var response = await container.ReadItemAsync<dynamic>(id, new PartitionKey(id));
        return Results.Ok(response.Resource);
    }
    catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
    {
        return Results.NotFound();
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error retrieving item: {ex.Message}");
    }
})
.WithName("GetTodoItem")
.WithOpenApi();

app.MapPost("/api/items", async (CosmosClient cosmosClient) =>
{
    try
    {
        // Ensure database and container exist
        var database = await cosmosClient.CreateDatabaseIfNotExistsAsync("SampleDB");
        var container = await database.Database.CreateContainerIfNotExistsAsync("Items", "/id");
        
        var item = new 
        {
            id = Guid.NewGuid().ToString(),
            title = "Sample Todo Item",
            isCompleted = false,
            createdAt = DateTime.UtcNow
        };
        
        var response = await container.Container.CreateItemAsync(item, new PartitionKey(item.id));
        return Results.Created($"/api/items/{item.id}", response.Resource);
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error creating item: {ex.Message}");
    }
})
.WithName("CreateTodoItem")
.WithOpenApi();

app.MapDelete("/api/items/{id}", async (string id, CosmosClient cosmosClient) =>
{
    try
    {
        var database = cosmosClient.GetDatabase("SampleDB");
        var container = database.GetContainer("Items");
        
        await container.DeleteItemAsync<dynamic>(id, new PartitionKey(id));
        return Results.NoContent();
    }
    catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
    {
        return Results.NotFound();
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error deleting item: {ex.Message}");
    }
})
.WithName("DeleteTodoItem")
.WithOpenApi();

// Health check endpoint to verify Cosmos DB connectivity
app.MapGet("/health", async (CosmosClient cosmosClient) =>
{
    try
    {
        var databaseResponse = await cosmosClient.CreateDatabaseIfNotExistsAsync("SampleDB");
        return Results.Ok(new { Status = "Healthy", Database = "SampleDB", Timestamp = DateTime.UtcNow });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Unhealthy: {ex.Message}");
    }
})
.WithName("HealthCheck")
.WithOpenApi();

app.Run();

// Make the implicit Program class public so test projects can reference it
public partial class Program { }
