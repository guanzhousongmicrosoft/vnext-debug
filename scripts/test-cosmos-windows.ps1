param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,3)]
    [int]$DebugLevel = 2,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "persistent", "ephemeral", "all")]
    [string]$TestScenario = "basic"
)

# Initialize logging
$logDir = "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "$logDir/cosmos-test-windows-$timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestampedMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $timestampedMessage
    $timestampedMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Test-CosmosEmulator {
    param(
        [string]$ContainerLifetime = "Session"
    )
    
    Write-Log "Starting Cosmos DB Emulator test with lifetime: $ContainerLifetime" "INFO"
    
    try {
        # Create test Aspire project
        $testProjectDir = "test-aspire-project"
        if (Test-Path $testProjectDir) {
            Remove-Item -Recurse -Force $testProjectDir
        }
        
        Write-Log "Creating test Aspire project..." "INFO"
        
        # Check .NET and Aspire workload
        Write-Log "Checking .NET and Aspire workload..." "INFO"
        dotnet --version | Out-String | Write-Log
        
        # Install Aspire workload if not already installed
        Write-Log "Installing Aspire workload..." "INFO"
        dotnet workload install aspire
        
        # Create the project
        dotnet new aspire -n $testProjectDir
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create Aspire project"
        }
        
        Set-Location $testProjectDir
        
        # Add Cosmos DB emulator configuration
        $programCs = @"
using Aspire.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Configure Cosmos DB emulator with detailed logging
var cosmos = builder
    .AddAzureCosmosDB("database")
    .RunAsPreviewEmulator(options =>
    {
        options.WithLifetime(ContainerLifetime.$ContainerLifetime);
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_PARTITION_COUNT", "10");
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_DATA_PERSISTENCE", "true");
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_LOG_LEVEL", "Debug");
    });

var database = cosmos.AddCosmosDatabase("MyDb");
var container = database.AddContainer("Users", "/emailAddress");

// Add a simple API project that uses Cosmos
var api = builder.AddProject<Projects.TestApi>("api")
    .WithReference(database);

builder.Build().Run();
"@

        $programCs | Out-File -FilePath "$testProjectDir.AppHost/Program.cs" -Encoding UTF8
        
        # Create test API project
        Write-Log "Creating test API project..." "INFO"
        dotnet new webapi -n TestApi --framework net9.0
        
        # Add Cosmos client to API
        Set-Location TestApi
        dotnet add package Microsoft.Azure.Cosmos
        dotnet add package Aspire.Microsoft.Azure.Cosmos
        
        # Create a simple controller that tests Cosmos connectivity
        $controllerContent = @"
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Cosmos;

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
        try
        {
            _logger.LogInformation("Testing Cosmos DB connection...");
            
            // Try to get the database
            var database = _cosmosClient.GetDatabase("MyDb");
            var response = await database.ReadAsync();
            
            _logger.LogInformation("Successfully connected to Cosmos DB. Database: {DatabaseId}", response.Resource.Id);
            
            // Try to get the container
            var container = database.GetContainer("Users");
            var containerResponse = await container.ReadContainerAsync();
            
            _logger.LogInformation("Successfully accessed container: {ContainerId}", containerResponse.Resource.Id);
            
            return Ok(new { 
                Status = "Connected", 
                Database = response.Resource.Id,
                Container = containerResponse.Resource.Id,
                Timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to Cosmos DB");
            return StatusCode(500, new { 
                Status = "Failed", 
                Error = ex.Message,
                InnerError = ex.InnerException?.Message,
                StackTrace = ex.StackTrace,
                Timestamp = DateTime.UtcNow
            });
        }
    }
}
"@
        
        if (-not (Test-Path "Controllers")) {
            New-Item -ItemType Directory -Path "Controllers"
        }
        $controllerContent | Out-File -FilePath "Controllers/CosmosTestController.cs" -Encoding UTF8
        
        # Configure services
        $programApiCs = @"
using Aspire.Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add Aspire Cosmos DB client
builder.AddAzureCosmosClient("database");

// Enhanced logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.SetMinimumLevel(LogLevel.Debug);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();
"@
        
        $programApiCs | Out-File -FilePath "Program.cs" -Encoding UTF8
        
        Set-Location ..
        
        # Add project reference
        dotnet sln add TestApi/TestApi.csproj
        Set-Location "$testProjectDir.AppHost"
        dotnet add reference ../TestApi/TestApi.csproj
        Set-Location ..
        
        Write-Log "Building Aspire project..." "INFO"
        dotnet build
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Aspire project"
        }
        
        Write-Log "Starting Aspire application..." "INFO"
        
        # Start the application with detailed logging
        $env:ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL = "http://localhost:18889"
        $env:DOTNET_ENVIRONMENT = "Development"
        $env:ASPIRE_ALLOW_UNSECURED_TRANSPORT = "true"
        
        if ($DebugLevel -ge 3) {
            $env:DOTNET_LOG_LEVEL = "Debug"
            $env:Logging__LogLevel__Default = "Debug"
            $env:Logging__LogLevel__Microsoft = "Debug"
            $env:Logging__LogLevel__Microsoft.Hosting.Lifetime = "Information"
        }
        
        $aspireProcess = Start-Process -FilePath "dotnet" -ArgumentList "run --project $testProjectDir.AppHost" -PassThru -NoNewWindow
        
        Write-Log "Aspire process started with PID: $($aspireProcess.Id)" "INFO"
        
        # Wait for services to start up
        Write-Log "Waiting for services to start..." "INFO"
        Start-Sleep -Seconds 60
        
        # Check if Cosmos emulator is running
        Write-Log "Checking Docker containers..." "INFO"
        $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Out-String
        Write-Log "Docker containers:`n$containers" "INFO"
        
        # Try to connect to the API and test Cosmos
        $maxRetries = 10
        $retryCount = 0
        $testSuccess = $false
        
        while ($retryCount -lt $maxRetries -and -not $testSuccess) {
            try {
                $retryCount++
                Write-Log "Attempt $retryCount/$maxRetries: Testing API connection..." "INFO"
                
                # Find the API port from Docker or Aspire dashboard
                $apiUrl = "http://localhost:5000/CosmosTest/test"  # Default port, may need to be dynamic
                
                $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 30
                Write-Log "API test successful: $($response | ConvertTo-Json -Depth 3)" "INFO"
                $testSuccess = $true
                
            } catch {
                Write-Log "API test attempt $retryCount failed: $($_.Exception.Message)" "WARN"
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Seconds 10
                }
            }
        }
        
        # Collect detailed logs
        Write-Log "Collecting container logs..." "INFO"
        $cosmosContainers = docker ps --filter "ancestor=mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator" --format "{{.Names}}"
        
        foreach ($containerName in $cosmosContainers) {
            if ($containerName) {
                Write-Log "Collecting logs from container: $containerName" "INFO"
                $containerLogs = docker logs $containerName 2>&1
                $containerLogs | Out-File -FilePath "$logDir/cosmos-container-$containerName-$timestamp.log" -Encoding UTF8
            }
        }
        
        if (-not $testSuccess) {
            throw "Failed to connect to Cosmos DB after $maxRetries attempts"
        }
        
        Write-Log "Test completed successfully for lifetime: $ContainerLifetime" "INFO"
        return $true
        
    } catch {
        Write-Log "Test failed for lifetime $ContainerLifetime`: $($_.Exception.Message)" "ERROR"
        Write-Log "Stack trace: $($_.Exception.StackTrace)" "ERROR"
        return $false
        
    } finally {
        # Cleanup
        if ($aspireProcess -and -not $aspireProcess.HasExited) {
            Write-Log "Stopping Aspire process..." "INFO"
            Stop-Process -Id $aspireProcess.Id -Force -ErrorAction SilentlyContinue
        }
        
        # Stop and remove containers
        Write-Log "Cleaning up Docker containers..." "INFO"
        docker stop $(docker ps -aq) 2>$null
        docker rm $(docker ps -aq) 2>$null
        
        Set-Location ..
        if (Test-Path $testProjectDir) {
            Remove-Item -Recurse -Force $testProjectDir -ErrorAction SilentlyContinue
        }
    }
}

# Main execution
Write-Log "Starting Cosmos DB Emulator tests on Windows" "INFO"
Write-Log "Debug Level: $DebugLevel, Test Scenario: $TestScenario" "INFO"

$results = @{}

try {
    # Test different scenarios based on input
    switch ($TestScenario) {
        "basic" {
            $results["Session"] = Test-CosmosEmulator -ContainerLifetime "Session"
        }
        "persistent" {
            $results["Persistent"] = Test-CosmosEmulator -ContainerLifetime "Persistent"
        }
        "ephemeral" {
            $results["Session"] = Test-CosmosEmulator -ContainerLifetime "Session"
        }
        "all" {
            $results["Session"] = Test-CosmosEmulator -ContainerLifetime "Session"
            Start-Sleep -Seconds 30
            $results["Persistent"] = Test-CosmosEmulator -ContainerLifetime "Persistent"
        }
    }
    
    # Summary
    Write-Log "=== TEST RESULTS SUMMARY ===" "INFO"
    foreach ($scenario in $results.Keys) {
        $status = if ($results[$scenario]) { "PASSED" } else { "FAILED" }
        Write-Log "$scenario`: $status" "INFO"
    }
    
    $overallSuccess = ($results.Values | Where-Object { $_ -eq $false }).Count -eq 0
    
    if ($overallSuccess) {
        Write-Log "All tests PASSED on Windows" "INFO"
        exit 0
    } else {
        Write-Log "Some tests FAILED on Windows" "ERROR"
        exit 1
    }
    
} catch {
    Write-Log "Critical error during testing: $($_.Exception.Message)" "ERROR"
    exit 1
}
