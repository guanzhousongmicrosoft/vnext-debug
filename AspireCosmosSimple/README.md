# Aspire Cosmos DB Simple

A minimal .NET Aspire project that starts the Azure Cosmos DB emulator using Aspire. This project demonstrates how to use .NET Aspire to launch the Cosmos DB emulator for local development and testing.

## Project Structure

- **AspireCosmosSimple**: The main Aspire host application that launches the Cosmos DB emulator.
- **CosmosDBTest**: A test application that demonstrates how to insert and query data from the Cosmos DB emulator.

## Requirements

- .NET 9.0 SDK or later
- Docker (for running Cosmos DB emulator)

## Getting Started

### Running Locally

1. Clone this repository
2. Navigate to the repository root
3. Run the Aspire application:

```bash
cd AspireCosmosSimple
dotnet run
```

4. Open a new terminal and run the test application:

```bash
cd CosmosDBTest
dotnet run
```

### GitHub Actions Workflow

This repository includes a GitHub Actions workflow that:

1. Builds both the Aspire application and the test application.
2. Runs the Aspire application to start the Cosmos DB emulator.
3. Executes the test application to verify data insertion and querying.

The workflow runs automatically on push to the main/master branch and on pull requests, and can also be triggered manually from the Actions tab in GitHub.

## Cosmos DB Connection Details

- **Endpoint**: `https://localhost:8081`
- **Key**: `C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==`
- **Database**: `MyDb`
- **Container**: `Users`
- **Partition Key**: `/emailAddress`

## Notes

- The Aspire application is configured to suppress the Cosmos DB emulator preview warning.
- The dashboard is disabled in the application for simplicity.
- The test application disables SSL certificate validation, which is required for connecting to the Cosmos DB emulator locally.
