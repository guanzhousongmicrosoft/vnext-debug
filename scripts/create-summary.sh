#!/bin/bash

set -euo pipefail

# Check if analysis results exist
if [[ ! -d "analysis" ]]; then
    echo "# ❌ Analysis Failed"
    echo "No analysis directory found. The log analysis step may have failed."
    exit 1
fi

# Check for GitHub summary
if [[ -f "analysis/github-summary.md" ]]; then
    cat "analysis/github-summary.md"
else
    echo "# 📊 Test Execution Results"
    echo ""
    echo "## Status"
    echo "Test execution completed but detailed summary not available."
    echo ""
    
    # Try to extract basic information from individual platform analyses
    if [[ -d "analysis" ]]; then
        echo "## Available Analysis Files"
        ls -la analysis/ || true
        echo ""
        
        # Check each platform
        for platform in windows ubuntu macos; do
            if [[ -f "analysis/${platform}-analysis.md" ]]; then
                echo "### $platform"
                if grep -q "Schema Issue Reproduced" "analysis/${platform}-analysis.md"; then
                    echo "✅ Issue reproduced successfully"
                elif grep -q "Schema Issue Not Reproduced" "analysis/${platform}-analysis.md"; then
                    echo "❌ Issue not reproduced"
                else
                    echo "🟡 Status unclear"
                fi
                echo ""
            fi
        done
    fi
fi

echo ""
echo "## 🔗 Useful Links"
echo "- [Original Issue](https://github.com/Azure/azure-cosmos-db-emulator-docker/issues/199)"
echo "- [Related Aspire Issue](https://github.com/dotnet/aspire/issues/9326)"
echo ""
echo "## 📋 Issue Details"
echo "- **Error**: schema \"cosmos_api\" does not exist"
echo "- **Environment**: Azure Cosmos DB emulator vNext with .NET Aspire"
echo "- **Platform**: Primarily affects Ubuntu in GitHub Actions"
echo "- **Status**: Under investigation by Azure Cosmos DB team"
echo ""
echo "## 🎯 Test Objectives"
echo "1. Reproduce the schema error across different platforms"
echo "2. Compare behavior between Windows, Ubuntu, and macOS"
echo "3. Collect detailed logs for debugging"
echo "4. Test different Aspire configurations"
echo ""
echo "---"
echo "*Generated on $(date) by Azure Cosmos DB Emulator Issue Reproduction Workflow*"
