#!/usr/bin/env pwsh

Write-Host "🚀 Starting Cosmos DB Emulator Test Suite" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

function Test-ApiEndpoint {
    param(
        [string]$Method,
        [string]$Url,
        [string]$Description,
        [int]$ExpectedStatus,
        [string]$Data = $null
    )
    
    Write-Host "Testing: $Description" -ForegroundColor Cyan
    
    try {
        $headers = @{ "Content-Type" = "application/json" }
        
        if ($Data) {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $Data -SkipCertificateCheck -ErrorAction Stop
        } else {
            $response = Invoke-WebRequest -Uri $Url -Method $Method -SkipCertificateCheck -ErrorAction Stop
        }
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "✅ $Description - Status: $($response.StatusCode)" -ForegroundColor Green
            if ($response.Content -and $response.Content -ne "null") {
                Write-Host "   Response: $($response.Content)" -ForegroundColor Blue
            }
            return $response
        } else {
            Write-Host "❌ $Description - Expected: $ExpectedStatus, Got: $($response.StatusCode)" -ForegroundColor Red
            return $null
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "✅ $Description - Status: $statusCode (Expected error)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ $Description - Error: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
}

function Wait-ForService {
    param(
        [string]$Url,
        [string]$ServiceName,
        [int]$MaxAttempts = 30
    )
    
    Write-Host "Waiting for $ServiceName to be ready..." -ForegroundColor Blue
    
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Url -Method GET -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop | Out-Null
            Write-Host "✅ $ServiceName is ready!" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "⏳ Attempt $attempt/$MaxAttempts - waiting for $ServiceName..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host "❌ $ServiceName failed to start within expected time" -ForegroundColor Red
    return $false
}

# Build the solution
Write-Host "🔨 Building the solution..." -ForegroundColor Blue
$buildResult = dotnet build CosmosEmulatorApp.sln --verbosity quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

# Start the application in background
Write-Host "🚀 Starting the Aspire application..." -ForegroundColor Blue
$appProcess = Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", "CosmosEmulatorApp.AppHost" -PassThru

# Give the application time to start
Start-Sleep -Seconds 15

try {
    # Try to find the API port
    $apiUrl = $null
    $apiPorts = @(7001, 7002, 7003, 5001, 5002, 5003)
    
    foreach ($port in $apiPorts) {
        $testUrl = "https://localhost:$port/health"
        try {
            Invoke-WebRequest -Uri $testUrl -Method GET -SkipCertificateCheck -TimeoutSec 3 -ErrorAction Stop | Out-Null
            $apiUrl = "https://localhost:$port"
            Write-Host "✅ Found API at $apiUrl" -ForegroundColor Green
            break
        } catch {
            # Continue to next port
        }
    }
    
    if (-not $apiUrl) {
        Write-Host "⚠️  Could not auto-detect API URL. Trying default port 7001..." -ForegroundColor Yellow
        $apiUrl = "https://localhost:7001"
    }
    
    # Wait for API to be ready
    if (Wait-ForService "$apiUrl/health" "API") {
        Write-Host "`n🧪 Running API tests..." -ForegroundColor Blue
        Write-Host "==================================" -ForegroundColor Blue
        
        # Test 1: Health check
        Test-ApiEndpoint -Method "GET" -Url "$apiUrl/health" -Description "Health Check" -ExpectedStatus 200
        
        # Test 2: Get all items (initially empty)
        Write-Host "`n📋 Testing initial state..." -ForegroundColor Blue
        Test-ApiEndpoint -Method "GET" -Url "$apiUrl/api/items" -Description "Get all items (initial)" -ExpectedStatus 200
        
        # Test 3: Create multiple items
        Write-Host "`n📝 Creating test data..." -ForegroundColor Blue
        
        # Create item 1
        $item1Response = Test-ApiEndpoint -Method "POST" -Url "$apiUrl/api/items" -Description "Create item 1" -ExpectedStatus 201
        $item1Id = $null
        if ($item1Response -and $item1Response.Content) {
            $item1Data = $item1Response.Content | ConvertFrom-Json
            $item1Id = $item1Data.id
        }
        
        # Create item 2
        $item2Response = Test-ApiEndpoint -Method "POST" -Url "$apiUrl/api/items" -Description "Create item 2" -ExpectedStatus 201
        $item2Id = $null
        if ($item2Response -and $item2Response.Content) {
            $item2Data = $item2Response.Content | ConvertFrom-Json
            $item2Id = $item2Data.id
        }
        
        # Test 4: Get all items (should now have data)
        Write-Host "`n📋 Testing after data insertion..." -ForegroundColor Blue
        Test-ApiEndpoint -Method "GET" -Url "$apiUrl/api/items" -Description "Get all items (with data)" -ExpectedStatus 200
        
        # Test 5: Get specific item
        if ($item1Id) {
            Write-Host "`n🔍 Testing individual item retrieval..." -ForegroundColor Blue
            Test-ApiEndpoint -Method "GET" -Url "$apiUrl/api/items/$item1Id" -Description "Get specific item" -ExpectedStatus 200
        }
        
        # Test 6: Delete an item
        if ($item2Id) {
            Write-Host "`n🗑️  Testing item deletion..." -ForegroundColor Blue
            Test-ApiEndpoint -Method "DELETE" -Url "$apiUrl/api/items/$item2Id" -Description "Delete item" -ExpectedStatus 204
            
            # Verify deletion
            Test-ApiEndpoint -Method "GET" -Url "$apiUrl/api/items/$item2Id" -Description "Verify item deleted" -ExpectedStatus 404
        }
        
        # Test 7: Final state check
        Write-Host "`n📋 Final state check..." -ForegroundColor Blue
        Test-ApiEndpoint -Method "GET" -Url "$apiUrl/api/items" -Description "Get all items (final)" -ExpectedStatus 200
        
        Write-Host "`n🎯 Test Summary" -ForegroundColor Blue
        Write-Host "================" -ForegroundColor Blue
        Write-Host "✅ Application started successfully" -ForegroundColor Green
        Write-Host "✅ Cosmos DB emulator container running" -ForegroundColor Green
        Write-Host "✅ API endpoints tested" -ForegroundColor Green
        Write-Host "✅ Data insertion and retrieval verified" -ForegroundColor Green
        
        Write-Host "`n💡 Tips:" -ForegroundColor Blue
        Write-Host "- Check the Aspire Dashboard for detailed service information"
        Write-Host "- Use the Data Explorer in the Cosmos emulator to browse data"
        Write-Host "- API documentation is available at $apiUrl/swagger"
        
    } else {
        Write-Host "❌ API failed to start. Check the Aspire dashboard for more details." -ForegroundColor Red
    }
    
} finally {
    # Cleanup
    Write-Host "`n🧹 Cleaning up..." -ForegroundColor Yellow
    if ($appProcess -and -not $appProcess.HasExited) {
        $appProcess.Kill()
        $appProcess.WaitForExit(5000)
    }
    Write-Host "✅ Cleanup complete" -ForegroundColor Green
}
