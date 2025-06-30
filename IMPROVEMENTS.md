# Azure Cosmos DB Emulator vNext Issue Reproduction - Key Improvements

## Problem Analysis

Based on the GitHub Actions logs, the main issue was that while Aspire successfully built and started, the TestApi service was not being launched. This prevented testing the actual Cosmos DB connectivity and reproducing the "schema 'cosmos_api' does not exist" error.

## Root Cause Identified

The primary issue was in the AppHost configuration:
- **Project Reference Problem**: Using `builder.AddProject<Projects.TestApi>("api")` which requires a project reference that wasn't properly established
- **Build Order Issues**: The project wasn't being created in the correct order for Aspire to recognize it
- **Missing Project Registration**: The TestApi wasn't properly added to the solution and referenced by the AppHost

## Key Improvements Made

### 1. Fixed Project Reference Issue
**Before:**
```csharp
var api = builder.AddProject<Projects.TestApi>("api")
```

**After:**
```csharp
var api = builder.AddProject("api", "../TestApi/TestApi.csproj")
```

This change uses the direct project path instead of relying on the `Projects` reference which wasn't properly generated.

### 2. Improved TestApi Creation Process
**Before:**
- Created directories and files manually
- Used `mkdir -p TestApi/Controllers`

**After:**
- Uses `dotnet new webapi -n TestApi --framework net8.0` to create a proper project structure
- Ensures all required files and directories are created correctly
- Better integration with the .NET build system

### 3. Enhanced Build Process
- Added `dotnet restore` step before building
- Added build output verification to ensure DLLs are created
- Better error reporting for build failures
- Separated build and run phases for better debugging

### 4. Improved Logging and Debugging
**Before:**
- Single log file mixing stdout/stderr
- Limited error detection

**After:**
- Separate stdout and stderr log files
- Enhanced error detection and reporting
- Better environment variable logging
- More detailed process monitoring

### 5. Enhanced Environment Configuration
Added additional environment variables for better debugging:
```bash
export ASPNETCORE_ENVIRONMENT="Development"
export ASPIRE_ALLOW_UNSECURED_TRANSPORT="true"
export DOTNET_ENVIRONMENT="Development"
```

### 6. Better Project Integration
- Proper solution file management with `dotnet sln add`
- Correct project reference setup
- Proper dependency resolution order

## Expected Results

With these improvements, the workflow should now:

1. ✅ Successfully create the Aspire project
2. ✅ Properly create and configure the TestApi project  
3. ✅ Build all projects without errors
4. ✅ Launch the Aspire AppHost
5. ✅ **NEW**: Actually start the TestApi service on port 5000
6. ✅ Start the Cosmos DB emulator container
7. ✅ Allow testing the API endpoints to reproduce the schema issue

## Testing the Improvements

### Local Testing
```bash
# Run the test script locally (if prerequisites are installed)
./scripts/test-cosmos-ubuntu.sh 2 basic
```

### GitHub Actions Testing
The existing workflow `.github/workflows/reproduce-cosmos-issue.yml` will automatically use the improved script.

### Validation Steps
1. Check that TestApi process is running: `ps aux | grep TestApi`
2. Verify port 5000 is listening: `netstat -tulpn | grep :5000`
3. Test API health endpoint: `curl http://localhost:5000/CosmosTest/health`
4. Test Cosmos connectivity: `curl http://localhost:5000/CosmosTest/test`

## Debugging Enhancements

The improved script now provides:
- **Separate log files** for different components
- **Better error messages** with specific failure points
- **Environment variable dumps** for configuration debugging
- **Process monitoring** to track service startup
- **Build verification** to ensure all artifacts are created
- **Network monitoring** to verify port binding

## Next Steps

1. **Test the workflow**: Run the GitHub Actions workflow to verify the improvements
2. **Monitor logs**: Check the enhanced logging for better debugging information
3. **Reproduce the issue**: With the TestApi now properly starting, we should be able to reproduce the Cosmos DB schema error
4. **Document findings**: Once the issue is reproduced, document the exact error conditions and potential fixes

The key breakthrough is fixing the project reference mechanism in Aspire, which should resolve the service startup issues and allow proper testing of the Cosmos DB connectivity problem.
