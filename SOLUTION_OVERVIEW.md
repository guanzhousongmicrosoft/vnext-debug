# .NET Aspire Azure Cosmos DB Integration Summary

## What This Solution Provides

This solution demonstrates a complete .NET Aspire application that:

1. **Uses Azure Cosmos DB Linux Emulator** with the `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview` image
2. **Implements proper Aspire integration** using the official Azure Cosmos DB hosting and client packages
3. **Provides a RESTful API** for managing todo items with full CRUD operations
4. **Includes health checks** and observability features
5. **Uses modern .NET 9.0** features and minimal APIs

## Key Components

### AppHost Project (`CosmosEmulatorApp.AppHost`)
- Orchestrates the entire application
- Configures the Cosmos DB emulator container with:
  - Data Explorer UI enabled
  - Data persistence volume
  - Custom partition count
  - vnext-preview Linux image
- Sets up service discovery and networking

### API Project (`CosmosEmulatorApp.Api`)
- Web API built with minimal APIs
- Integrates with Cosmos DB using Aspire client integration
- Provides Swagger/OpenAPI documentation
- Implements proper error handling

### Database Structure
- **Database**: `SampleDB`
- **Container**: `Items`
- **Partition Key**: `/id`

## API Endpoints

```
GET    /api/items      - Get all items
GET    /api/items/{id} - Get item by ID
POST   /api/items      - Create new item
DELETE /api/items/{id} - Delete item
GET    /health         - Health check
```

## How to Run

1. **Start the application:**
   ```bash
   ./run-manual-test.sh
   ```
   or
   ```bash
   dotnet run --project CosmosEmulatorApp.AppHost
   ```

2. **Access services:**
   - Aspire Dashboard: Check console output for URL
   - API Swagger: Available through the dashboard
   - Cosmos Data Explorer: Available through the emulator

## Testing the Setup

### Using the API
```bash
# Create an item
curl -X POST "https://localhost:{port}/api/items" -H "Content-Type: application/json"

# Get all items
curl "https://localhost:{port}/api/items"

# Check health
curl "https://localhost:{port}/health"
```

### Using the Standalone Test
```bash
# Test direct connection to emulator (requires emulator to be running)
dotnet run --project CosmosTest.csproj
```

## Configuration Notes

- The solution uses the **preview emulator** which requires disabling the `ASPIRECOSMOSDB001` warning
- **Data persistence** is enabled via volumes
- **Self-signed certificates** are handled automatically in development
- **Service discovery** connects the API to the emulator automatically

## Benefits of This Approach

1. **Container orchestration** - Aspire handles starting/stopping containers
2. **Service discovery** - Automatic connection string management
3. **Observability** - Built-in logging, metrics, and tracing
4. **Development experience** - Single command to start entire stack
5. **Production readiness** - Easy transition from emulator to Azure Cosmos DB

This solution provides a complete, production-ready pattern for developing applications with Azure Cosmos DB using .NET Aspire.
