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
    CONTAINER_ID=$(docker ps -q --filter "ancestor=mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:latest" 2>/dev/null || echo "")
    
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
            # Check if port 8081 is mapped
            PORT_MAPPING=$(docker port $CONTAINER_ID 8081 2>/dev/null || echo "")
            echo "Port 8081 mapping: $PORT_MAPPING"
            
            # Check container health if available
            HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_ID 2>/dev/null || echo "no health check")
            echo "Container health: $HEALTH_STATUS"
            
            # Try to connect to the emulator endpoint inside the container
            echo "Testing connection inside container..."
            if docker exec $CONTAINER_ID curl -k -s --max-time 5 https://localhost:8081/_explorer/emulator.pem > /dev/null 2>&1; then
                echo "Cosmos DB emulator is responding inside container!"
                
                # Also check if accessible from host
                echo "Testing connection from host..."
                if curl -k -s --max-time 5 https://localhost:8081/_explorer/emulator.pem > /dev/null 2>&1; then
                    echo "Cosmos DB emulator is accessible from host!"
                    
                    # Final verification - try to connect to the actual service
                    echo "Testing Cosmos DB service endpoint..."
                    if curl -k -s --max-time 5 https://localhost:8081/ > /dev/null 2>&1; then
                        echo "Cosmos DB service endpoint is responding!"
                        exit 0
                    else
                        echo "Cosmos DB service endpoint not responding yet"
                    fi
                else
                    echo "Emulator ready in container but not accessible from host"
                    echo "Checking port forwarding..."
                    
                    # Try to get the container's IP and connect directly
                    HOST_IP=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_ID 2>/dev/null | head -1)
                    if [ -n "$HOST_IP" ] && [ "$HOST_IP" != "<no value>" ]; then
                        echo "Container IP: $HOST_IP"
                        if curl -k -s --max-time 5 https://$HOST_IP:8081/_explorer/emulator.pem > /dev/null 2>&1; then
                            echo "Cosmos DB emulator is accessible via container IP!"
                            exit 0
                        else
                            echo "Cannot connect to container IP either"
                        fi
                    else
                        echo "Could not determine container IP"
                    fi
                    
                    # Try to check if the port is exposed correctly
                    echo "Checking container port exposure..."
                    docker inspect $CONTAINER_ID --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}' 2>/dev/null || echo "Could not check port exposure"
                fi
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
    
    # Check if port 8081 is available on host
    if netstat -tuln | grep -q ":8081"; then
        echo "Port 8081 is in use on host"
        # Try to connect directly
        if curl -k -s --max-time 5 https://localhost:8081/_explorer/emulator.pem > /dev/null 2>&1; then
            echo "Cosmos DB emulator is accessible on host!"
            exit 0
        else
            echo "Port 8081 is in use but emulator not responding"
        fi
    else
        echo "Port 8081 is not in use"
    fi
    
    echo "Waiting 10 seconds before next attempt..."
    sleep 10
done

echo "Cosmos DB emulator failed to become ready after $MAX_ATTEMPTS attempts"
echo "Final diagnostic information:"
echo "Docker containers:"
docker ps -a
echo "Port usage:"
netstat -tuln | grep 8081 || echo "Port 8081 is not in use"
if [ -n "$CONTAINER_ID" ]; then
    echo "Container logs:"
    docker logs $CONTAINER_ID --tail 50 2>/dev/null || echo "Could not get container logs"
    echo "Container inspection:"
    docker inspect $CONTAINER_ID 2>/dev/null || echo "Could not inspect container"
fi

exit 1
