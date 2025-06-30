# Latest Fix: Endpoint Configuration Conflict Resolution

## Problem Found
The recent workflow run revealed a new error after fixing the project reference issue:

```
Aspire.Hosting.DistributedApplicationException: Endpoint with name 'http' already exists. 
Endpoint name may not have been explicitly specified and was derived automatically from 
scheme argument. Multiple calls to WithEndpoint (and related methods) may result in a 
conflict if name argument is not specified.
```

## Root Cause
When using `dotnet new webapi` to create the TestApi project, it automatically configures a default HTTP endpoint. Our Aspire configuration was trying to add another HTTP endpoint with `WithHttpEndpoint()`, causing a naming conflict.

## Solution Applied

### 1. Removed Conflicting Endpoint Configuration
**Before:**
```csharp
var api = builder.AddProject("api", "../TestApi/TestApi.csproj")
    .WithReference(cosmos)
    .WithHttpEndpoint(port: 5000, env: "HTTP_PORT")  // ❌ Conflicts with default endpoint
```

**After:**
```csharp
var api = builder.AddProject("api", "../TestApi/TestApi.csproj")
    .WithReference(cosmos)
    .WithEnvironment("ASPNETCORE_URLS", "http://localhost:5000")  // ✅ Uses environment variable
```

### 2. Enhanced TestApi Configuration
**Added launchSettings.json:**
```json
{
  "profiles": {
    "TestApi": {
      "commandName": "Project",
      "applicationUrl": "http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
```

**Updated Program.cs:**
```csharp
// Configure URLs explicitly
builder.WebHost.UseUrls("http://localhost:5000");
```

### 3. Better Port Management
- Uses consistent port 5000 across all configurations
- Avoids Aspire's automatic endpoint naming conflicts
- Ensures proper URL binding in the TestApi service

## Expected Result
With this fix, the workflow should now:

1. ✅ Successfully create the Aspire project
2. ✅ Properly create and configure the TestApi project  
3. ✅ Build all projects without errors
4. ✅ **Fixed**: Avoid endpoint configuration conflicts
5. ✅ Launch the Aspire AppHost successfully
6. ✅ Start the TestApi service on port 5000
7. ✅ Allow testing the Cosmos DB connectivity

## Testing the Fix
The GitHub Actions workflow should now proceed past the endpoint configuration error and actually start the TestApi service, enabling the Cosmos DB connectivity testing.

This fix addresses the immediate blocker and gets us back to the main goal: reproducing the "schema 'cosmos_api' does not exist" error in the Azure Cosmos DB emulator vNext.
