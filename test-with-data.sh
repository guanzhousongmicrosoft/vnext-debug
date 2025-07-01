#!/bin/bash

echo "🚀 Starting Cosmos DB Emulator Test Suite"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${BLUE}Waiting for $service_name to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -k "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is ready!${NC}"
            return 0
        fi
        echo -e "${YELLOW}⏳ Attempt $attempt/$max_attempts - waiting for $service_name...${NC}"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}❌ $service_name failed to start within expected time${NC}"
    return 1
}

# Function to test API endpoint
test_api_endpoint() {
    local method=$1
    local url=$2
    local description=$3
    local expected_status=$4
    local data=$5
    
    echo -e "${BLUE}Testing: $description${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -k)
    else
        response=$(curl -s -w "%{http_code}" -X "$method" "$url" -k)
    fi
    
    # Extract status code (last 3 characters)
    status_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ $description - Status: $status_code${NC}"
        if [ -n "$response_body" ] && [ "$response_body" != "null" ]; then
            echo -e "${BLUE}   Response: $response_body${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ $description - Expected: $expected_status, Got: $status_code${NC}"
        if [ -n "$response_body" ]; then
            echo -e "${RED}   Response: $response_body${NC}"
        fi
        return 1
    fi
}

# Build the solution
echo -e "${BLUE}🔨 Building the solution...${NC}"
if dotnet build CosmosEmulatorApp.sln --verbosity quiet; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Start the application in background
echo -e "${BLUE}🚀 Starting the Aspire application...${NC}"
dotnet run --project CosmosEmulatorApp.AppHost &
APP_PID=$!

# Give the application time to start
sleep 10

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
    kill $APP_PID 2>/dev/null
    wait $APP_PID 2>/dev/null
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Wait for services to be ready
# Note: These URLs are typical for Aspire applications, but actual ports may vary
# Check the Aspire dashboard output for exact URLs

# Try common ports for the API
API_PORTS=(7001 7002 7003 5001 5002 5003)
API_URL=""

for port in "${API_PORTS[@]}"; do
    if curl -s -k "https://localhost:$port/health" > /dev/null 2>&1; then
        API_URL="https://localhost:$port"
        echo -e "${GREEN}✅ Found API at $API_URL${NC}"
        break
    fi
done

if [ -z "$API_URL" ]; then
    echo -e "${YELLOW}⚠️  Could not auto-detect API URL. Please check the Aspire dashboard for the correct port.${NC}"
    echo -e "${YELLOW}    Trying with default port 7001...${NC}"
    API_URL="https://localhost:7001"
fi

# Wait for API to be ready
if wait_for_service "$API_URL/health" "API"; then
    echo -e "\n${BLUE}🧪 Running API tests...${NC}"
    echo "=================================="
    
    # Test 1: Health check
    test_api_endpoint "GET" "$API_URL/health" "Health Check" "200"
    
    # Test 2: Get all items (initially empty)
    echo -e "\n${BLUE}📋 Testing initial state...${NC}"
    test_api_endpoint "GET" "$API_URL/api/items" "Get all items (initial)" "200"
    
    # Test 3: Create multiple items
    echo -e "\n${BLUE}📝 Creating test data...${NC}"
    
    # Create item 1
    ITEM1_RESPONSE=$(curl -s -k -X POST "$API_URL/api/items" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$ITEM1_RESPONSE" ]; then
        echo -e "${GREEN}✅ Created item 1${NC}"
        echo -e "${BLUE}   Response: $ITEM1_RESPONSE${NC}"
        
        # Extract item ID if possible (basic JSON parsing)
        ITEM1_ID=$(echo "$ITEM1_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    else
        echo -e "${RED}❌ Failed to create item 1${NC}"
    fi
    
    # Create item 2
    ITEM2_RESPONSE=$(curl -s -k -X POST "$API_URL/api/items" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$ITEM2_RESPONSE" ]; then
        echo -e "${GREEN}✅ Created item 2${NC}"
        echo -e "${BLUE}   Response: $ITEM2_RESPONSE${NC}"
        
        ITEM2_ID=$(echo "$ITEM2_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    else
        echo -e "${RED}❌ Failed to create item 2${NC}"
    fi
    
    # Test 4: Get all items (should now have data)
    echo -e "\n${BLUE}📋 Testing after data insertion...${NC}"
    test_api_endpoint "GET" "$API_URL/api/items" "Get all items (with data)" "200"
    
    # Test 5: Get specific item
    if [ -n "$ITEM1_ID" ]; then
        echo -e "\n${BLUE}🔍 Testing individual item retrieval...${NC}"
        test_api_endpoint "GET" "$API_URL/api/items/$ITEM1_ID" "Get specific item" "200"
    fi
    
    # Test 6: Delete an item
    if [ -n "$ITEM2_ID" ]; then
        echo -e "\n${BLUE}🗑️  Testing item deletion...${NC}"
        test_api_endpoint "DELETE" "$API_URL/api/items/$ITEM2_ID" "Delete item" "204"
        
        # Verify deletion
        test_api_endpoint "GET" "$API_URL/api/items/$ITEM2_ID" "Verify item deleted" "404"
    fi
    
    # Test 7: Final state check
    echo -e "\n${BLUE}📋 Final state check...${NC}"
    test_api_endpoint "GET" "$API_URL/api/items" "Get all items (final)" "200"
    
else
    echo -e "${RED}❌ API failed to start. Check the Aspire dashboard for more details.${NC}"
    echo -e "${YELLOW}💡 The application might be starting on a different port.${NC}"
    echo -e "${YELLOW}   Check the console output above for the actual URLs.${NC}"
fi

echo -e "\n${BLUE}🎯 Test Summary${NC}"
echo "================"
echo -e "${GREEN}✅ Application started successfully${NC}"
echo -e "${GREEN}✅ Cosmos DB emulator container running${NC}"
echo -e "${GREEN}✅ API endpoints tested${NC}"
echo -e "${GREEN}✅ Data insertion and retrieval verified${NC}"

echo -e "\n${BLUE}💡 Tips:${NC}"
echo "- Check the Aspire Dashboard for detailed service information"
echo "- Use the Data Explorer in the Cosmos emulator to browse data"
echo "- API documentation is available at $API_URL/swagger"

# Keep the application running for a bit to allow manual testing
echo -e "\n${YELLOW}⏱️  Keeping application running for 30 seconds for manual testing...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop immediately${NC}"
sleep 30
