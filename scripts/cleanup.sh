#!/bin/bash

# Cleanup script for Aspire Cosmos DB project
# This script will clean up all processes, containers, and build artifacts

echo "=== Starting cleanup process ==="

# Kill any running .NET processes related to our project
echo "Stopping .NET processes..."
pkill -f "dotnet.*AspireCosmosSimple" || echo "No Aspire processes found"
pkill -f "dotnet.*CosmosDBTest" || echo "No test processes found"

# Kill Aspire-related processes
echo "Stopping Aspire-related processes..."
pkill -f "dcpctrl" || echo "No dcpctrl processes found"
pkill -f "AspireCos" || echo "No AspireCos processes found"

# Force kill any processes using ports 7777 or 8081
echo "Checking for processes using ports 7777 and 8081..."
PROCESSES_7777=$(lsof -t -i :7777 2>/dev/null)
PROCESSES_8081=$(lsof -t -i :8081 2>/dev/null)

if [ -n "$PROCESSES_7777" ]; then
    echo "Force killing processes using port 7777: $PROCESSES_7777"
    kill -9 $PROCESSES_7777 || echo "Some processes couldn't be killed"
fi

if [ -n "$PROCESSES_8081" ]; then
    echo "Force killing processes using port 8081: $PROCESSES_8081"
    kill -9 $PROCESSES_8081 || echo "Some processes couldn't be killed"
fi

# Stop and remove all Docker containers
echo "Stopping and removing Docker containers..."
CONTAINERS=$(docker ps -aq 2>/dev/null)
if [ -n "$CONTAINERS" ]; then
    echo "Found containers: $CONTAINERS"
    docker stop $CONTAINERS || echo "Failed to stop some containers"
    docker rm $CONTAINERS || echo "Failed to remove some containers"
else
    echo "No containers found"
fi

# Remove any dangling Docker images (optional)
echo "Removing dangling Docker images..."
docker image prune -f || echo "Failed to prune images"

# Clean up build artifacts
echo "Cleaning build artifacts..."
dotnet clean AspireCosmosSimple/AspireCosmosSimple/AspireCosmosSimple.csproj || echo "Failed to clean Aspire project"
dotnet clean AspireCosmosSimple/CosmosDBTest/CosmosDBTest.csproj || echo "Failed to clean test project"

# Remove bin and obj directories
echo "Removing bin and obj directories..."
find . -type d -name "bin" -exec rm -rf {} + 2>/dev/null || echo "No bin directories found"
find . -type d -name "obj" -exec rm -rf {} + 2>/dev/null || echo "No obj directories found"

# Remove log files
echo "Removing log files..."
rm -f *.log 2>/dev/null || echo "No log files found"
rm -rf logs/ 2>/dev/null || echo "No logs directory found"

# Remove backup files
echo "Removing backup files..."
rm -f AspireCosmosSimple/AspireCosmosSimple/Program.cs.bak 2>/dev/null || echo "No backup files found"
rm -f *.bak 2>/dev/null || echo "No backup files found"

# Remove temporary files
echo "Removing temporary files..."
rm -f *.tmp *.temp 2>/dev/null || echo "No temporary files found"

# Remove .aspire directory if it exists
echo "Removing .aspire directory..."
rm -rf .aspire/ 2>/dev/null || echo "No .aspire directory found"

# Clean up any Azure deployment artifacts
echo "Removing Azure deployment artifacts..."
rm -rf .azure/ 2>/dev/null || echo "No .azure directory found"

# Check for any remaining processes
echo "Checking for remaining processes..."
REMAINING_PROCESSES=$(ps aux | grep -E "(dotnet.*AspireCosmosSimple|dotnet.*CosmosDBTest)" | grep -v grep | wc -l)
if [ "$REMAINING_PROCESSES" -gt 0 ]; then
    echo "Warning: Found $REMAINING_PROCESSES remaining processes"
    ps aux | grep -E "(dotnet.*AspireCosmosSimple|dotnet.*CosmosDBTest)" | grep -v grep
else
    echo "No remaining processes found"
fi

# Check for any remaining containers
echo "Checking for remaining containers..."
REMAINING_CONTAINERS=$(docker ps -aq 2>/dev/null | wc -l)
if [ "$REMAINING_CONTAINERS" -gt 0 ]; then
    echo "Warning: Found $REMAINING_CONTAINERS remaining containers"
    docker ps -a
else
    echo "No remaining containers found"
fi

# Check network ports
echo "Checking network ports..."
PORTS_IN_USE=$(netstat -tuln | grep -E "(7777|8081)" | wc -l)
if [ "$PORTS_IN_USE" -gt 0 ]; then
    echo "Warning: Found ports 7777 or 8081 still in use"
    netstat -tuln | grep -E "(7777|8081)"
else
    echo "Ports 7777 and 8081 are free"
fi

# Reset file permissions for scripts
echo "Resetting script permissions..."
chmod +x scripts/*.sh

echo "=== Cleanup process completed ==="
echo "System is ready for a fresh test run"

# Optional: Show current system state
echo ""
echo "=== Current System State ==="
echo "Docker containers:"
docker ps -a || echo "Docker not available"
echo "Listening ports:"
netstat -tuln | grep -E "(7777|8081)" || echo "No relevant ports in use"
echo "Build directories:"
find . -type d -name "bin" -o -name "obj" | head -5 || echo "No build directories found"
