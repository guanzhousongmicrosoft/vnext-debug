#!/bin/bash

set -euo pipefail

# Default values
DEBUG_LEVEL=${1:-2}
TEST_SCENARIO=${2:-basic}

# Initialize logging
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$(pwd)/$LOG_DIR/cosmos-test-ubuntu-$TIMESTAMP.log"

log() {
    local level=${2:-INFO}
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $1"
    
    # Only show DEBUG messages if DEBUG_LEVEL is 3 or higher
    if [[ "$level" == "DEBUG" && $DEBUG_LEVEL -lt 3 ]]; then
        echo "$message" >> "$LOG_FILE"
    else
        echo "$message" | tee -a "$LOG_FILE"
    fi
}

cleanup() {
    log "Performing cleanup..." "INFO"
    
    # Stop Aspire processes
    pkill -f "dotnet run" || true
    
    # Stop and remove all containers
    if command -v docker &> /dev/null; then
        sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
        sudo docker system prune -f 2>/dev/null || true
    fi
    
    # Remove test project
    if [[ -d "test-aspire-project" ]]; then
        rm -rf test-aspire-project
    fi
    
    log "Cleanup completed" "INFO"
}

trap cleanup EXIT

test_cosmos_emulator() {
    local container_lifetime=${1:-Session}
    
    log "Starting Cosmos DB Emulator test with lifetime: $container_lifetime" "INFO"
    
    # Store the original directory
    local original_dir=$(pwd)
    local absolute_log_dir="$original_dir/$LOG_DIR"
    
    # Create test Aspire project
    local test_project_dir="test-aspire-project"
    if [[ -d "$test_project_dir" ]]; then
        rm -rf "$test_project_dir"
    fi
    
    log "Creating test Aspire project..." "INFO"
    dotnet new aspire -n "$test_project_dir" || {
        log "Failed to create Aspire project" "ERROR"
        return 1
    }
    
    cd "$test_project_dir"
    
    # First, add the required NuGet package to the AppHost project
    cd "$test_project_dir.AppHost"
    log "Adding Azure Cosmos DB package to AppHost..." "INFO"
    dotnet add package Aspire.Hosting.Azure.CosmosDB --version 8.2.2 || {
        log "Failed to add Cosmos DB package" "ERROR"
        return 1
    }
    
    # Ensure the AppHost targets .NET 8.0
    log "Updating AppHost to target .NET 8.0..." "INFO"
    sed -i 's/<TargetFramework>net9.0<\/TargetFramework>/<TargetFramework>net8.0<\/TargetFramework>/g' "$test_project_dir.AppHost.csproj"
    
    # Also ensure ServiceDefaults targets .NET 8.0 if it exists
    if [[ -f "$test_project_dir.ServiceDefaults/$test_project_dir.ServiceDefaults.csproj" ]]; then
        log "Updating ServiceDefaults to target .NET 8.0..." "INFO"
        sed -i 's/<TargetFramework>net9.0<\/TargetFramework>/<TargetFramework>net8.0<\/TargetFramework>/g' "$test_project_dir.ServiceDefaults/$test_project_dir.ServiceDefaults.csproj"
    fi
    
    cd ..
    
    # Add Cosmos DB emulator configuration with enhanced error handling
    cat > "$test_project_dir.AppHost/Program.cs" << 'EOF'
using Aspire.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;

var builder = DistributedApplication.CreateBuilder(args);

// Enable detailed logging
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.SetMinimumLevel(LogLevel.Debug);
});

try
{
    Console.WriteLine("=== Starting Aspire AppHost ===");
    
    // Configure Cosmos DB emulator with detailed settings
    Console.WriteLine("Configuring Cosmos DB emulator...");
    var cosmos = builder
        .AddAzureCosmosDB("database")
        .RunAsEmulator();

    Console.WriteLine("Adding MyDb database...");
    var database = cosmos.AddDatabase("MyDb");

    // Add a simple API project that uses Cosmos with a fixed port
    Console.WriteLine("Adding TestApi project...");
    var api = builder.AddProject<Projects.TestApi>("api")
        .WithReference(cosmos)
        .WithHttpEndpoint(port: 5000, env: "HTTP_PORT")
        .WithEnvironment("ASPIRE_ALLOW_UNSECURED_TRANSPORT", "true")
        .WithEnvironment("DOTNET_ENVIRONMENT", "Development");

    Console.WriteLine("Building Aspire application...");
    var app = builder.Build();
    
    // Add startup logging
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogInformation("Starting Aspire application with Cosmos DB emulator...");
    logger.LogInformation("API should be available at: http://localhost:5000");
    
    Console.WriteLine("Starting Aspire application...");
    app.Run();
}
catch (Exception ex)
{
    Console.WriteLine($"Failed to start application: {ex}");
    Console.WriteLine($"Stack trace: {ex.StackTrace}");
    throw;
}
EOF

    # Create test API project
    log "Creating test API project..." "INFO"
    
    # Create a clean .NET 8.0 project manually to avoid compatibility issues
    mkdir -p TestApi/Controllers
    
    # Create the project file targeting .NET 8.0
    cat > TestApi/TestApi.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="8.0.11" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.4.0" />
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.49.0" />
    <PackageReference Include="Aspire.Microsoft.Azure.Cosmos" Version="9.3.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="../test-aspire-project.ServiceDefaults/test-aspire-project.ServiceDefaults.csproj" />
  </ItemGroup>

</Project>
EOF

    cd TestApi
    log "Created clean .NET 8.0 TestApi project" "INFO"
    
    # Create a comprehensive controller that tests Cosmos connectivity
    mkdir -p Controllers
    cat > Controllers/CosmosTestController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Cosmos;
using System.Net;

namespace TestApi.Controllers;

[ApiController]
[Route("[controller]")]
public class CosmosTestController : ControllerBase
{
    private readonly CosmosClient _cosmosClient;
    private readonly ILogger<CosmosTestController> _logger;

    public CosmosTestController(CosmosClient cosmosClient, ILogger<CosmosTestController> logger)
    {
        _cosmosClient = cosmosClient;
        _logger = logger;
    }

    [HttpGet("test")]
    public async Task<IActionResult> TestConnection()
    {
        var testResults = new Dictionary<string, object>();
        
        try
        {
            _logger.LogInformation("=== Starting Cosmos DB connection test ===");
            
            // Test 1: Client connectivity
            _logger.LogInformation("Test 1: Checking Cosmos client configuration...");
            testResults["client_endpoint"] = _cosmosClient.Endpoint?.ToString() ?? "null";
            
            // Test 2: List databases (this often reveals the schema issue)
            _logger.LogInformation("Test 2: Attempting to list databases...");
            try 
            {
                var databaseIterator = _cosmosClient.GetDatabaseQueryIterator<DatabaseProperties>();
                var databases = new List<string>();
                
                while (databaseIterator.HasMoreResults)
                {
                    var response = await databaseIterator.ReadNextAsync();
                    databases.AddRange(response.Select(db => db.Id));
                }
                
                testResults["existing_databases"] = databases;
                _logger.LogInformation("Found {Count} existing databases: {Databases}", 
                    databases.Count, string.Join(", ", databases));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to list databases");
                testResults["list_databases_error"] = new { 
                    Message = ex.Message, 
                    Type = ex.GetType().Name,
                    StatusCode = (ex as CosmosException)?.StatusCode.ToString()
                };
            }
            
            // Test 3: Try to get the specific database
            _logger.LogInformation("Test 3: Attempting to access MyDb database...");
            try
            {
                var database = _cosmosClient.GetDatabase("MyDb");
                var response = await database.ReadAsync();
                
                _logger.LogInformation("Successfully accessed database: {DatabaseId}", response.Resource.Id);
                testResults["database_access"] = new { 
                    Status = "Success", 
                    DatabaseId = response.Resource.Id,
                    LastModified = response.Resource.LastModified,
                    ETag = response.Resource.ETag
                };
                
                // Test 4: Try to create and access a container
                _logger.LogInformation("Test 4: Attempting to create/access Users container...");
                try
                {
                    // Try to create the container first (it might not exist)
                    var containerProperties = new ContainerProperties("Users", "/emailAddress");
                    var container = await database.CreateContainerIfNotExistsAsync(containerProperties);
                    
                    _logger.LogInformation("Successfully created/accessed container: {ContainerId}", container.Container.Id);
                    testResults["container_access"] = new { 
                        Status = "Success", 
                        ContainerId = container.Container.Id,
                        PartitionKeyPath = containerProperties.PartitionKeyPath,
                        StatusCode = container.StatusCode.ToString()
                    };
                    
                    // Test 5: Try a simple query
                    _logger.LogInformation("Test 5: Attempting to query container...");
                    try
                    {
                        var query = new QueryDefinition("SELECT * FROM c");
                        var iterator = container.Container.GetItemQueryIterator<dynamic>(query);
                        var results = await iterator.ReadNextAsync();
                        
                        testResults["query_test"] = new { 
                            Status = "Success", 
                            ItemCount = results.Count,
                            RequestCharge = results.RequestCharge
                        };
                        
                        _logger.LogInformation("Query successful. Items: {Count}, RU: {RequestCharge}", 
                            results.Count, results.RequestCharge);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Query test failed");
                        testResults["query_test"] = new { 
                            Status = "Failed", 
                            Error = ex.Message,
                            Type = ex.GetType().Name,
                            StatusCode = (ex as CosmosException)?.StatusCode.ToString()
                        };
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to create/access Users container");
                    testResults["container_access"] = new { 
                        Status = "Failed", 
                        Error = ex.Message,
                        Type = ex.GetType().Name,
                        StatusCode = (ex as CosmosException)?.StatusCode.ToString(),
                        InnerException = ex.InnerException?.Message
                    };
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to access MyDb database - THIS IS THE MAIN ISSUE");
                testResults["database_access"] = new { 
                    Status = "Failed", 
                    Error = ex.Message,
                    Type = ex.GetType().Name,
                    StatusCode = (ex as CosmosException)?.StatusCode.ToString(),
                    SubStatusCode = (ex as CosmosException)?.SubStatusCode,
                    ActivityId = (ex as CosmosException)?.ActivityId,
                    InnerException = ex.InnerException?.Message,
                    StackTrace = ex.StackTrace
                };
                
                // This is likely where we'll see the "schema cosmos_api does not exist" error
                if (ex.Message.Contains("cosmos_api") || ex.Message.Contains("schema"))
                {
                    _logger.LogCritical("FOUND THE ISSUE: Schema-related error detected!");
                    testResults["schema_issue_detected"] = true;
                }
            }
            
            testResults["overall_status"] = testResults.ContainsKey("query_test") && 
                                          testResults["query_test"] is Dictionary<string, object> queryResult &&
                                          queryResult["Status"].ToString() == "Success" ? "Success" : "Failed";
            testResults["timestamp"] = DateTime.UtcNow;
            
            _logger.LogInformation("=== Cosmos DB connection test completed ===");
            
            return Ok(testResults);
        }
        catch (Exception ex)
        {
            _logger.LogCritical(ex, "Critical error during Cosmos DB test");
            testResults["critical_error"] = new { 
                Message = ex.Message,
                Type = ex.GetType().Name,
                StackTrace = ex.StackTrace,
                InnerException = ex.InnerException?.Message
            };
            testResults["overall_status"] = "Critical Failure";
            testResults["timestamp"] = DateTime.UtcNow;
            
            return StatusCode(500, testResults);
        }
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { Status = "API is running", Timestamp = DateTime.UtcNow });
    }
}
EOF

    # Configure enhanced services and logging
    cat > Program.cs << 'EOF'
using Aspire.Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Add Aspire service defaults
builder.AddServiceDefaults();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Aspire Cosmos DB client
builder.AddAzureCosmosClient("database");

// Enhanced logging for debugging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
if (builder.Environment.IsDevelopment())
{
    builder.Logging.SetMinimumLevel(LogLevel.Debug);
}

// Add CORS for testing
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader();
    });
});

var app = builder.Build();

// Map Aspire service defaults
app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
app.UseCors();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();
app.MapControllers();

app.Logger.LogInformation("TestApi starting up...");
app.Logger.LogInformation("Listening on: {Urls}", string.Join(", ", app.Urls));

app.Run();
EOF

    cd ..
    
    # Add project reference
    dotnet sln add TestApi/TestApi.csproj
    cd "$test_project_dir.AppHost"
    dotnet add reference ../TestApi/TestApi.csproj
    cd ..
    
    log "Building Aspire project..." "INFO"
    if ! dotnet build --verbosity normal; then
        log "Failed to build Aspire project" "ERROR"
        return 1
    fi
    
    log "Starting Aspire application..." "INFO"
    
    # Set environment variables for debugging
    export ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL="http://localhost:18889"
    export DOTNET_ENVIRONMENT="Development"
    export ASPIRE_ALLOW_UNSECURED_TRANSPORT="true"
    
    if [[ $DEBUG_LEVEL -ge 3 ]]; then
        export DOTNET_LOG_LEVEL="Debug"
        export Logging__LogLevel__Default="Debug"
        export Logging__LogLevel__Microsoft="Debug"
        export Logging__LogLevel__Microsoft__Hosting__Lifetime="Information"
    fi
    
    # Start the application in background
    log "Starting Aspire host..." "INFO"
    cd "$test_project_dir.AppHost"
    dotnet run --verbosity normal > "$absolute_log_dir/aspire-output-$TIMESTAMP.log" 2>&1 &
    local aspire_pid=$!
    cd ..
    
    log "Aspire process started with PID: $aspire_pid" "INFO"
    
    # Wait for services to start up with progress indication
    log "Waiting for services to start..." "INFO"
    for i in {1..12}; do
        sleep 5
        log "Startup progress: ${i}/12 ($(($i * 5)) seconds)" "INFO"
        
        # Check if process is still running
        if ! kill -0 $aspire_pid 2>/dev/null; then
            log "Aspire process died unexpectedly!" "ERROR"
            cat "$absolute_log_dir/aspire-output-$TIMESTAMP.log" >> "$LOG_FILE"
            return 1
        fi
    done
    
    # Check Docker containers
    log "Checking Docker containers..." "INFO"
    if command -v docker &> /dev/null; then
        sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"
        
        # Collect Cosmos container logs
        local cosmos_containers=$(sudo docker ps --filter "ancestor=mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator" --format "{{.Names}}")
        if [[ -n "$cosmos_containers" ]]; then
            for container_name in $cosmos_containers; do
                log "Collecting logs from Cosmos container: $container_name" "INFO"
                sudo docker logs "$container_name" > "$absolute_log_dir/cosmos-container-$container_name-$TIMESTAMP.log" 2>&1
            done
        else
            log "No Cosmos emulator containers found!" "WARN"
            sudo docker ps -a | tee -a "$LOG_FILE"
        fi
    fi
    
    # Check if TestApi process is running
    log "Checking for TestApi processes..." "INFO"
    local testapi_processes=$(ps aux | grep -i testapi | grep -v grep || true)
    if [[ -n "$testapi_processes" ]]; then
        log "Found TestApi processes:" "INFO"
        echo "$testapi_processes" | tee -a "$LOG_FILE"
    else
        log "No TestApi processes found - this might be the issue!" "WARN"
        log "All .NET processes:" "INFO"
        ps aux | grep dotnet | grep -v grep | tee -a "$LOG_FILE"
        
        # Check Aspire logs for errors about TestApi
        if [[ -f "$absolute_log_dir/aspire-output-$TIMESTAMP.log" ]]; then
            log "Checking Aspire logs for TestApi startup issues..." "INFO"
            if grep -i "testapi\|error\|exception\|failed" "$absolute_log_dir/aspire-output-$TIMESTAMP.log" | head -20; then
                log "Found potential issues in Aspire logs" "WARN"
            else
                log "No obvious errors found in Aspire logs" "INFO"
            fi
            
            log "Full Aspire log output:" "INFO"
            cat "$absolute_log_dir/aspire-output-$TIMESTAMP.log" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Try to connect to the API and test Cosmos
    local max_retries=20
    local retry_count=0
    local test_success=false
    
    # Use the fixed port we configured in Aspire
    local api_port=5000
    local health_url="http://localhost:$api_port/CosmosTest/health"
    local test_url="http://localhost:$api_port/CosmosTest/test"
    
    log "API should be available at: $health_url" "INFO"
    
    while [[ $retry_count -lt $max_retries && "$test_success" != "true" ]]; do
        ((retry_count++))
        log "Attempt $retry_count/$max_retries: Testing API connection on port $api_port..." "INFO"
        
        if curl -f -s -m 10 "$health_url" > /dev/null 2>&1; then
            log "Found API running on port $api_port" "INFO"
            
            local response_file="$absolute_log_dir/api-response-$retry_count-$TIMESTAMP.json"
            
            log "Testing API endpoint: $test_url" "INFO"
            if curl -f -s -m 30 "$test_url" -o "$response_file" 2>/dev/null; then
                log "API test successful! Response saved to $response_file" "INFO"
                cat "$response_file" | jq '.' 2>/dev/null || cat "$response_file"
                
                # Check if the response indicates success
                if jq -e '.overall_status == "Success"' "$response_file" > /dev/null 2>&1; then
                    test_success=true
                    log "Cosmos DB test completed successfully!" "INFO"
                elif jq -e '.schema_issue_detected == true' "$response_file" > /dev/null 2>&1; then
                    log "ISSUE REPRODUCED: Schema 'cosmos_api' does not exist error detected!" "ERROR"
                    test_success="reproduced"
                else
                    log "API responded but test failed. See response file for details." "WARN"
                fi
                break
            else
                log "API request failed for URL: $test_url" "WARN"
            fi
        else
            log "API not yet available on port $api_port (attempt $retry_count)" "INFO"
            
            # Show debugging info on first and every 10th attempt
            if [[ $retry_count -eq 1 || $(($retry_count % 10)) -eq 0 ]]; then
                log "Current .NET processes:" "INFO"
                ps aux | grep dotnet | grep -v grep | tee -a "$LOG_FILE"
                
                log "Current listening ports:" "INFO"
                netstat -tulpn | grep LISTEN | grep ":$api_port" | tee -a "$LOG_FILE" || echo "Port $api_port not listening yet"
                
                # Check if Aspire logs have any errors
                if [[ -f "$absolute_log_dir/aspire-output-$TIMESTAMP.log" ]]; then
                    log "Recent Aspire log output:" "INFO"
                    tail -20 "$absolute_log_dir/aspire-output-$TIMESTAMP.log" | tee -a "$LOG_FILE"
                fi
            fi
        fi
        
        if [[ $retry_count -lt $max_retries && "$test_success" != "true" ]]; then
            sleep 10
        fi
    done
    
    # Final status
    if [[ "$test_success" == "true" ]]; then
        log "Test completed successfully for lifetime: $container_lifetime" "INFO"
        return 0
    elif [[ "$test_success" == "reproduced" ]]; then
        log "Issue successfully reproduced for lifetime: $container_lifetime" "INFO"
        return 2  # Special return code for reproduced issue
    else
        log "Test failed for lifetime $container_lifetime after $max_retries attempts" "ERROR"
        
        # Collect additional debugging info
        log "Collecting final debugging information..." "INFO"
        ps aux | grep dotnet | tee -a "$LOG_FILE"
        netstat -tulpn | grep LISTEN | tee -a "$LOG_FILE"
        
        if [[ -f "$absolute_log_dir/aspire-output-$TIMESTAMP.log" ]]; then
            log "Aspire output tail:" "INFO"
            tail -50 "$absolute_log_dir/aspire-output-$TIMESTAMP.log" | tee -a "$LOG_FILE"
        fi
        
        return 1
    fi
}

# Main execution
log "Starting Cosmos DB Emulator tests on Ubuntu" "INFO"
log "Debug Level: $DEBUG_LEVEL, Test Scenario: $TEST_SCENARIO" "INFO"
log "Environment: $(uname -a)" "INFO"
log "Docker version: $(sudo docker --version)" "INFO"
log ".NET version: $(dotnet --version)" "INFO"

declare -A results

# Test different scenarios based on input
case "$TEST_SCENARIO" in
    "basic")
        test_cosmos_emulator "Session"
        results["Session"]=$?
        ;;
    "persistent")
        test_cosmos_emulator "Persistent"
        results["Persistent"]=$?
        ;;
    "ephemeral")
        test_cosmos_emulator "Session"
        results["Session"]=$?
        ;;
    "all")
        test_cosmos_emulator "Session"
        results["Session"]=$?
        sleep 30
        test_cosmos_emulator "Persistent"
        results["Persistent"]=$?
        ;;
esac

# Summary
log "=== TEST RESULTS SUMMARY ===" "INFO"
overall_success=true
issue_reproduced=false

for scenario in "${!results[@]}"; do
    case ${results[$scenario]} in
        0) 
            log "$scenario: PASSED" "INFO"
            ;;
        1)
            log "$scenario: FAILED" "ERROR"
            overall_success=false
            ;;
        2)
            log "$scenario: ISSUE REPRODUCED" "WARN"
            issue_reproduced=true
            ;;
    esac
done

if $issue_reproduced; then
    log "Issue successfully reproduced on Ubuntu!" "INFO"
    exit 2
elif $overall_success; then
    log "All tests PASSED on Ubuntu (Issue NOT reproduced)" "INFO"
    exit 0
else
    log "Tests FAILED on Ubuntu" "ERROR"
    exit 1
fi
