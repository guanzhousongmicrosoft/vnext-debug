#!/bin/bash

echo "🧪 Cosmos DB Emulator Test Runner"
echo "================================="

echo "Available test options:"
echo "1. Run automated integration tests (requires app to be running)"
echo "2. Run unit tests"
echo "3. Run live application test with data insertion"
echo "4. Run all tests"

read -p "Select option (1-4): " choice

case $choice in
    1)
        echo "Running integration tests..."
        dotnet test CosmosEmulatorApp.Tests --filter "FullyQualifiedName~CosmosIntegrationTests"
        ;;
    2)
        echo "Running unit tests..."
        dotnet test CosmosEmulatorApp.Tests --filter "FullyQualifiedName~DirectCosmosTests"
        ;;
    3)
        echo "Running live application test..."
        ./test-with-data.sh
        ;;
    4)
        echo "Running all tests..."
        echo "Step 1: Unit tests"
        dotnet test CosmosEmulatorApp.Tests --filter "FullyQualifiedName~DirectCosmosTests"
        echo ""
        echo "Step 2: Live application test"
        ./test-with-data.sh
        ;;
    *)
        echo "Invalid option. Please select 1-4."
        exit 1
        ;;
esac
