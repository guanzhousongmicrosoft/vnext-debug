#!/bin/bash

echo "🧪 Simple Cosmos DB Test"
echo "========================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting the application manually...${NC}"
echo -e "${YELLOW}Please open another terminal and run:${NC}"
echo -e "${YELLOW}  cd /home/song/vnext-debug${NC}"
echo -e "${YELLOW}  dotnet run --project CosmosEmulatorApp.AppHost${NC}"
echo ""
echo -e "${YELLOW}Then check the output for the API URL and press Enter to continue...${NC}"
read -p "Press Enter when the application is running and you know the API URL: "

# Get API URL from user
read -p "Enter the API URL (e.g., https://localhost:7001): " API_URL

if [ -z "$API_URL" ]; then
    API_URL="https://localhost:7001"
    echo -e "${YELLOW}Using default URL: $API_URL${NC}"
fi

echo -e "\n${BLUE}Testing API endpoints...${NC}"

# Function to test endpoint
test_endpoint() {
    local method=$1
    local url=$2
    local description=$3
    local expected_status=$4
    
    echo -e "${BLUE}Testing: $description${NC}"
    response=$(curl -s -w "%{http_code}" -X "$method" "$url" -k 2>/dev/null)
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
        return 1
    fi
}

# Test health endpoint
test_endpoint "GET" "$API_URL/health" "Health Check" "200"

# Test get all items
test_endpoint "GET" "$API_URL/api/items" "Get All Items (Initial)" "200"

# Test create item
echo -e "\n${BLUE}Creating test items...${NC}"
for i in {1..3}; do
    response=$(curl -s -X POST "$API_URL/api/items" -H "Content-Type: application/json" -k 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Created item $i${NC}"
        echo -e "${BLUE}   Response: $response${NC}"
    else
        echo -e "${RED}❌ Failed to create item $i${NC}"
    fi
done

# Test get all items again
echo -e "\n${BLUE}Checking items after creation...${NC}"
test_endpoint "GET" "$API_URL/api/items" "Get All Items (After Creation)" "200"

echo -e "\n${GREEN}✅ Manual test completed!${NC}"
echo -e "${BLUE}You can now test the API manually at: $API_URL/swagger${NC}"
