# Azure Cosmos DB Emulator vNext Issue Reproduction

This repository contains a comprehensive GitHub Actions workflow to reproduce and debug [Issue #199](https://github.com/Azure/azure-cosmos-db-emulator-docker/issues/199) in the Azure Cosmos DB Emulator Docker repository.

## Issue Summary

The issue manifests as a schema error when using the Azure Cosmos DB emulator vNext (preview) with .NET Aspire in CI/CD environments:

```
schema "cosmos_api" does not exist
```

This error occurs specifically:
- ✅ In GitHub Actions on Ubuntu
- ✅ On macOS M2/M3 systems
- ❌ Works fine on Windows 11
- ❌ Works fine in local development environments

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── reproduce-cosmos-issue.yml    # Main GitHub Actions workflow
├── scripts/
│   ├── test-cosmos-windows.ps1           # PowerShell script for Windows testing
│   ├── test-cosmos-ubuntu.sh             # Bash script for Ubuntu testing
│   ├── test-cosmos-macos.sh              # Bash script for macOS testing
│   ├── analyze-logs.sh                   # Log analysis script
│   └── create-summary.sh                 # Summary generation script
└── README.md                             # This file
```

## How It Works

### 1. Multi-Platform Testing

The workflow runs on three platforms simultaneously:
- **Windows** (control group - expected to work)
- **Ubuntu** (primary target - expected to reproduce issue)
- **macOS** (additional validation)

### 2. Aspire Integration

Each test creates a complete .NET Aspire project that:
- Configures Azure Cosmos DB emulator vNext
- Creates a test database and container
- Implements a comprehensive API for connectivity testing
- Uses proper error handling and logging

### 3. Detailed Logging

The scripts collect:
- Application logs with debug-level output
- Docker container logs from the Cosmos emulator
- Aspire orchestration logs
- API response data with error details
- System information and container status

### 4. Automated Analysis

The analysis phase:
- Examines logs for the specific schema error
- Compares results across platforms
- Generates detailed reports
- Creates actionable summaries

## Usage

### Manual Trigger

1. Go to the **Actions** tab in your GitHub repository
2. Select "Reproduce Azure Cosmos DB Emulator vNext Issue"
3. Click "Run workflow"
4. Choose options:
   - **Debug Level**: 1-3 (higher = more verbose logging)
   - **Test Scenario**: basic, persistent, ephemeral, or all

### Automatic Trigger

The workflow automatically runs on:
- Push to `main` or `develop` branches
- Pull requests to `main`

### Test Scenarios

- **basic**: Test with Session container lifetime
- **persistent**: Test with Persistent container lifetime  
- **ephemeral**: Test with Session container lifetime (alias for basic)
- **all**: Test both Session and Persistent lifetimes

## Aspire Configuration

The test creates an Aspire project with this configuration:

```csharp
var cosmos = builder
    .AddAzureCosmosDB("database")
    .RunAsPreviewEmulator(options =>
    {
        options.WithLifetime(ContainerLifetime.Persistent);
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_PARTITION_COUNT", "10");
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_ENABLE_DATA_PERSISTENCE", "true");
        options.WithEnvironment("AZURE_COSMOS_EMULATOR_LOG_LEVEL", "Debug");
        // Additional debugging settings...
    });

var database = cosmos.AddCosmosDatabase("MyDb");
var container = database.AddContainer("Users", "/emailAddress");
```

## Test API Endpoints

The generated test API includes:

- `GET /CosmosTest/health` - Basic health check
- `GET /CosmosTest/test` - Comprehensive Cosmos DB connectivity test

The test endpoint performs:
1. Client configuration validation
2. Database listing (often where the error occurs)
3. Specific database access
4. Container access
5. Simple query execution

## Expected Results

### Successful Reproduction

When the issue is reproduced, you'll see:
- ✅ API responds with detailed error information
- ✅ Logs contain `schema "cosmos_api" does not exist`
- ✅ Analysis reports "Issue Reproduced"
- ✅ Exit code 2 (reproduced) from test scripts

### Issue Not Reproduced

When tests pass normally:
- ✅ All connectivity tests succeed
- ✅ Database and container operations work
- ✅ Queries execute successfully
- ✅ Exit code 0 (success) from test scripts

### Test Failure

When tests fail due to other issues:
- ❌ Scripts exit with code 1
- ❌ May indicate environment setup problems
- ❌ Check logs for specific error details

## Artifacts

The workflow generates several artifacts:

1. **Platform Logs** (`windows-logs`, `ubuntu-logs`, `macos-logs`)
   - Raw test execution logs
   - Container logs
   - API responses
   - System information

2. **Analysis Results** (`analysis-results`)
   - Platform-specific analysis reports
   - Comprehensive technical analysis
   - Cross-platform comparison
   - Recommendations

## Key Features

### Comprehensive Error Detection

The test API specifically checks for:
- The exact schema error: `cosmos_api does not exist`
- Connection timeouts
- Database creation failures
- Container access issues
- Query execution problems

### Platform-Specific Optimizations

- **Windows**: Uses PowerShell with enhanced error handling
- **Ubuntu**: Includes Docker setup and container management
- **macOS**: Handles Apple Silicon architecture and Docker Desktop

### Enhanced Debugging

- Multiple debug levels (1-3)
- Structured JSON logging
- Container health monitoring
- Network connectivity testing
- Timing analysis

## Troubleshooting

### Common Issues

1. **Docker not running**
   - Windows: Ensure Docker Desktop is started
   - macOS: Script attempts to start Docker Desktop automatically
   - Ubuntu: Script installs and starts Docker service

2. **Port conflicts**
   - Scripts test multiple common ports
   - Check logs for actual port assignments

3. **Container startup delays**
   - Scripts include generous timeouts
   - Increase wait times if needed on slower systems

### Debug Levels

- **Level 1**: Basic logging, essential information only
- **Level 2**: Standard logging with progress indicators
- **Level 3**: Verbose logging including .NET debug output

## Contributing

To improve the reproduction scripts:

1. Fork this repository
2. Modify the scripts in the `scripts/` directory
3. Test your changes locally
4. Submit a pull request

## Related Issues

- [Azure Cosmos DB Emulator Docker #199](https://github.com/Azure/azure-cosmos-db-emulator-docker/issues/199) (Primary issue)
- [.NET Aspire #9326](https://github.com/dotnet/aspire/issues/9326) (Related Aspire issue)

## License

This reproduction setup is provided as-is for debugging purposes. Please refer to the original repositories for licensing information.

---

*This workflow is designed to help the Azure Cosmos DB team and the community debug and resolve the emulator vNext schema issue.*
