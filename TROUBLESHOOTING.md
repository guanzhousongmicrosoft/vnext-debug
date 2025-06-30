# Troubleshooting Guide

## Common Issues and Solutions

### 1. TestApi Service Not Starting

**Symptoms:**
- No processes listening on port 5000
- No TestApi processes in `ps aux` output
- Aspire starts but API endpoints are unreachable

**Solutions (Applied in Improvements):**
- ✅ Fixed project reference issue in AppHost
- ✅ Use `builder.AddProject("api", "../TestApi/TestApi.csproj")` instead of `<Projects.TestApi>`
- ✅ Proper project creation with `dotnet new webapi`
- ✅ Correct solution and project reference setup

### 2. Build Failures

**Symptoms:**
- `dotnet build` fails
- Package version conflicts
- Target framework mismatches

**Solutions (Applied in Improvements):**
- ✅ Aligned all projects to .NET 8.0
- ✅ Fixed package versions (Microsoft.Azure.Cosmos 3.49.0)
- ✅ Added proper restore step before build
- ✅ Added build output verification

### 3. Docker Container Issues

**Symptoms:**
- Cosmos emulator container not starting
- Container exits immediately
- Permission denied errors

**Solutions:**
- ✅ Use `sudo docker` commands on Ubuntu
- ✅ Enhanced container logging and monitoring
- ✅ Better error detection for container failures

### 4. Logging and Debugging

**Symptoms:**
- Insufficient log information
- Mixed output making diagnosis difficult
- Missing error details

**Solutions (Applied in Improvements):**
- ✅ Separate stdout and stderr log files
- ✅ Enhanced environment variable logging
- ✅ Better error detection and reporting
- ✅ Detailed process and network monitoring

## Debugging Steps

### 1. Check Aspire Logs
```bash
# Look for build and startup errors
tail -f logs/aspire-output-*.log
tail -f logs/aspire-errors-*.log
```

### 2. Check Process Status
```bash
# Verify TestApi is running
ps aux | grep -i testapi

# Check port binding
netstat -tulpn | grep :5000
```

### 3. Check Docker Containers
```bash
# List running containers
sudo docker ps

# Check Cosmos container logs
sudo docker logs <cosmos-container-name>
```

### 4. Test API Directly
```bash
# Health check
curl -v http://localhost:5000/CosmosTest/health

# Full test
curl -v http://localhost:5000/CosmosTest/test | jq
```

## Environment Variables

Key environment variables for debugging:
```bash
DOTNET_ENVIRONMENT=Development
ASPIRE_ALLOW_UNSECURED_TRANSPORT=true
ASPNETCORE_ENVIRONMENT=Development
ASPNETCORE_URLS=http://localhost:5000
```

## Log Files

The test script creates these log files in the `logs/` directory:
- `cosmos-test-ubuntu-*.log` - Main test log
- `aspire-output-*.log` - Aspire stdout
- `aspire-errors-*.log` - Aspire stderr  
- `cosmos-container-*.log` - Docker container logs
- `api-response-*.json` - API test responses

## Getting Help

1. **Check the workflow logs** in GitHub Actions for detailed output
2. **Review the log artifacts** uploaded by the workflow
3. **Run locally** with debugging enabled: `./scripts/test-cosmos-ubuntu.sh 3 basic`
4. **Compare with IMPROVEMENTS.md** to understand the fixes applied
