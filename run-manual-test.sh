#!/bin/bash

echo "Starting .NET Aspire Cosmos DB Emulator Demo..."
echo "=========================================="

# Restore packages
echo "Restoring NuGet packages..."
dotnet restore

# Build the solution
echo "Building the solution..."
dotnet build

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful! Starting the application..."
    echo ""
    echo "The application will start the following services:"
    echo "- Azure Cosmos DB Linux Emulator (vnext-preview)"
    echo "- Web API with Swagger UI"
    echo "- Aspire Dashboard"
    echo ""
    echo "Access the Aspire Dashboard to see all running services and their endpoints."
    echo "Press Ctrl+C to stop all services."
    echo ""
    
    # Run the AppHost
    dotnet run --project CosmosEmulatorApp.AppHost
else
    echo "Build failed! Please check the errors above."
    exit 1
fi