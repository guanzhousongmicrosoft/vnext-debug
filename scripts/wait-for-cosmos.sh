#!/bin/bash

# Script to wait for Cosmos DB emulator to be ready
# This script will attempt to connect to the emulator and verify it's responding

echo "Starting Cosmos DB emulator health check..."

MAX_ATTEMPTS=60
ATTEMPT=0
CONTAINER_ID=""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "Attempt $ATTEMPT of $MAX_ATTEMPTS: Checking Cosmos DB emulator..."
    
    # Find the cosmos container
    CONTAINER_ID=$(docker ps -q --filter "ancestor=mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview" 2>/dev/null || echo "")
    
    if [ -z "$CONTAINER_ID" ]; then
        # Try to find any running container that might be the emulator
        CONTAINER_ID=$(docker ps -q | head -1)
        if [ -n "$CONTAINER_ID" ]; then
            echo "Found running container: $CONTAINER_ID"
            # Check if it's cosmos-related
            if docker inspect $CONTAINER_ID 2>/dev/null | grep -qi cosmos; then
                echo "Container appears to be cosmos-related"
            else
                echo "Container doesn't appear to be cosmos-related"
            fi
        fi
    fi
    
    if [ -n "$CONTAINER_ID" ]; then
        echo "Found container: $CONTAINER_ID"
        
        # Check container status
        CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' $CONTAINER_ID 2>/dev/null || echo "unknown")
        echo "Container status: $CONTAINER_STATUS"
        
        if [ "$CONTAINER_STATUS" = "running" ]; then
            # Check if port 7777 is mapped or accessible
            echo "Testing connection to Cosmos DB emulator on host port 7777..."
            if curl -s --max-time 5 http://localhost:7777/ > /dev/null 2>&1; then
                echo "Cosmos DB emulator is accessible on host port 7777!"
                exit 0
            else
                echo "Port 7777 not responding yet"
            fi
            
            # Also check if port 8081 is accessible inside container (for diagnostics)
            echo "Testing connection inside container on port 8081..."
            if docker exec $CONTAINER_ID curl -k -s --max-time 5 https://localhost:8081/_explorer/emulator.pem > /dev/null 2>&1; then
                echo "Cosmos DB emulator is responding inside container on port 8081!"
            else
                echo "Emulator not ready inside container yet"
                # Get some logs to help diagnose
                echo "Recent container logs:"
                docker logs $CONTAINER_ID --tail 10 2>/dev/null || echo "Could not get container logs"
                
                # Check if the emulator process is running inside the container
                echo "Checking processes inside container..."
                docker exec $CONTAINER_ID ps aux 2>/dev/null | grep -i cosmos || echo "No cosmos processes found"
            fi
        else
            echo "Container is not running (status: $CONTAINER_STATUS)"
        fi
    else
        echo "No container found"
    fi
    
    # Check if port 7777 is available on host
    if netstat -tuln | grep -q ":7777"; then
        echo "Port 7777 is in use on host"
        # Try to connect directly
        if curl -s --max-time 5 http://localhost:7777/ > /dev/null 2>&1; then
            echo "Cosmos DB emulator is accessible on host port 7777!"
            exit 0
        else
            echo "Port 7777 is in use but emulator not responding"
        fi
    else
        echo "Port 7777 is not in use"
    fi
    
    echo "Waiting 10 seconds before next attempt..."
    sleep 10
done

echo "Cosmos DB emulator failed to become ready after $MAX_ATTEMPTS attempts"
echo "Final diagnostic information:"
echo "Docker containers:"
docker ps -a
echo "Port 7777 usage:"
netstat -tuln | grep 7777 || echo "Port 7777 is not in use"
echo "Port 8081 usage:"
netstat -tuln | grep 8081 || echo "Port 8081 is not in use"
if [ -n "$CONTAINER_ID" ]; then
    echo "Container logs:"
    docker logs $CONTAINER_ID --tail 50 2>/dev/null || echo "Could not get container logs"
    echo "Container inspection:"
    docker inspect $CONTAINER_ID 2>/dev/null || echo "Could not inspect container"
fi

exit 1
