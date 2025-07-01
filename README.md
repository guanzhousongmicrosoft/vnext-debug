# .NET Aspire Azure Cosmos DB Emulator Demo

This project demonstrates how to use .NET Aspire with Azure Cosmos DB Linux emulator using the `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview` image.

## Prerequisites

- .NET 9.0 SDK
- Docker Desktop or Docker engine
- Visual Studio 2022 or VS Code with C# extension

## Project Structure

- `CosmosEmulatorApp.AppHost` - Aspire host project that orchestrates the containers and services
- `CosmosEmulatorApp.Api` - Web API project that connects to Cosmos DB emulator

## Features

- **Linux-based Cosmos DB Emulator**: Uses the latest vnext-preview Linux container
- **Data Explorer**: Web UI for browsing and managing Cosmos DB data
- **Data Persistence**: Container data persists between restarts
- **RESTful API**: CRUD operations for todo items
- **Health Checks**: Endpoint to verify Cosmos DB connectivity
- **Swagger UI**: API documentation and testing interface

## Running the Application

1. **Clone and navigate to the project:**
   ```bash
   cd /home/song/vnext-debug
   ```

2. **Quick Start - Run comprehensive test:**
   ```bash
   ./comprehensive-test.sh
   ```
   This will build, start, and test the entire application automatically.

3. **Manual start:**
   ```bash
   dotnet run --project CosmosEmulatorApp.AppHost
   ```

4. **Access the services:**
   - **Aspire Dashboard**: Check console output for URL (typically https://localhost:15888)
   - **API Swagger UI**: Check dashboard for actual port (typically https://localhost:7001/swagger)
   - **Cosmos DB Data Explorer**: Available through the emulator container

## Testing the Application

### Automated Testing
```bash
# Comprehensive test (recommended)
./comprehensive-test.sh

# Manual test with prompts
./manual-test.sh

# Original test script
./test-with-data.sh
```

### Manual API Testing
1. **Create a todo item:**
   ```bash
   curl -X POST "https://localhost:7001/api/items" \
        -H "Content-Type: application/json" -k
   ```

2. **Get all items:**
   ```bash
   curl "https://localhost:7001/api/items" -k
   ```

3. **Check health:**
   ```bash
   curl "https://localhost:7001/health" -k
   ```

Note: Replace `7001` with the actual port shown in the Aspire dashboard.

## Troubleshooting

- **Container startup issues**: Ensure Docker is running and has sufficient resources
- **Port conflicts**: Check the Aspire dashboard for actual assigned ports
- **Connection issues**: Verify the Cosmos DB emulator container is healthy in the dashboard

## Notes

- The preview emulator requires the `#pragma warning disable ASPIRECOSMOSDB001` directive
- Data persistence is enabled, so your data will survive container restarts
- The emulator uses self-signed certificates in development mode
