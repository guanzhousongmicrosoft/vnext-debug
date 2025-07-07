#!/bin/bash

# Script to verify the configuration is correct for CI

echo "=== Verifying Configuration ==="

echo "Checking Aspire application configuration..."
if grep -q "WithGatewayPort(7777)" AspireCosmosSimple/AspireCosmosSimple/Program.cs; then
    echo "✓ Aspire is configured to use port 7777"
else
    echo "✗ Aspire is NOT configured to use port 7777"
    echo "Current Aspire configuration:"
    grep -n "WithGatewayPort\|AddAzureCosmosDB" AspireCosmosSimple/AspireCosmosSimple/Program.cs || echo "No gateway port configuration found"
fi

echo "Checking test application configuration..."
if grep -q "http://localhost:7777" AspireCosmosSimple/CosmosDBTest/Program.cs; then
    echo "✓ Test application is configured to use HTTP on port 7777"
elif grep -q "https://localhost:7777" AspireCosmosSimple/CosmosDBTest/Program.cs; then
    echo "⚠ Test application is using HTTPS on port 7777 - should be HTTP"
elif grep -q "localhost:7777" AspireCosmosSimple/CosmosDBTest/Program.cs; then
    echo "⚠ Test application is using port 7777 but protocol may be incorrect"
else
    echo "✗ Test application is NOT configured to use port 7777"
    echo "Current test application endpoint:"
    grep -n "EndpointUri" AspireCosmosSimple/CosmosDBTest/Program.cs || echo "No endpoint configuration found"
fi

echo "Checking for OpenTcpConnectionTimeout issue..."
if grep -q "OpenTcpConnectionTimeout" AspireCosmosSimple/CosmosDBTest/Program.cs; then
    echo "✗ Test application has OpenTcpConnectionTimeout which conflicts with Gateway mode"
else
    echo "✓ Test application does not have OpenTcpConnectionTimeout conflict"
fi

echo "=== Configuration Check Complete ==="
