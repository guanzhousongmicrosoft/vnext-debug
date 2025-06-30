#!/bin/bash

set -euo pipefail

ANALYSIS_DIR="analysis"
mkdir -p "$ANALYSIS_DIR"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

log() {
    local level=${2:-INFO}
    local message="$(date '+%Y-%m-%d %H:%M:%S') [$level] $1"
    echo "$message" | tee -a "$ANALYSIS_DIR/analysis-$TIMESTAMP.log"
}

analyze_platform_logs() {
    local platform=$1
    local log_dir="collected-logs/${platform}-logs"
    
    log "Analyzing $platform logs..." "INFO"
    
    if [[ ! -d "$log_dir" ]]; then
        log "No logs found for $platform" "WARN"
        return 1
    fi
    
    local platform_analysis="$ANALYSIS_DIR/${platform}-analysis.md"
    
    cat > "$platform_analysis" << EOF
# $platform Analysis Results

## Test Execution Summary
EOF
    
    # Find and analyze main test logs
    local main_logs=$(find "$log_dir" -name "*cosmos-test-${platform,,}*" -type f | head -1)
    if [[ -n "$main_logs" && -f "$main_logs" ]]; then
        log "Found main test log: $main_logs" "INFO"
        
        # Extract test results
        echo "## Test Results" >> "$platform_analysis"
        if grep -q "TEST RESULTS SUMMARY" "$main_logs"; then
            echo '```' >> "$platform_analysis"
            grep -A 20 "TEST RESULTS SUMMARY" "$main_logs" | head -20 >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
        fi
        
        # Look for specific error patterns
        echo "## Error Analysis" >> "$platform_analysis"
        
        # Schema errors
        if grep -q "cosmos_api.*does not exist" "$main_logs"; then
            echo "### ✅ Schema Issue Reproduced" >> "$platform_analysis"
            echo "The 'schema cosmos_api does not exist' error was successfully reproduced on $platform." >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
            grep -n "cosmos_api.*does not exist" "$main_logs" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
        elif grep -q "schema.*does not exist" "$main_logs"; then
            echo "### ⚠️ Schema-related Error Found" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
            grep -n "schema.*does not exist" "$main_logs" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
        else
            echo "### ❌ Schema Issue Not Reproduced" >> "$platform_analysis"
            echo "The specific schema error was not found in the logs." >> "$platform_analysis"
        fi
        
        # Connection errors
        if grep -q "Failed to connect to Cosmos DB" "$main_logs"; then
            echo "### Connection Failures" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
            grep -A 5 -B 5 "Failed to connect to Cosmos DB" "$main_logs" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
        fi
        
        # Container status
        echo "## Container Status" >> "$platform_analysis"
        if grep -q "Docker containers:" "$main_logs"; then
            echo '```' >> "$platform_analysis"
            grep -A 10 "Docker containers:" "$main_logs" >> "$platform_analysis"
            echo '```' >> "$platform_analysis"
        fi
        
        # API response analysis
        echo "## API Response Analysis" >> "$platform_analysis"
        local api_responses=$(find "$log_dir" -name "api-response-*" -type f)
        if [[ -n "$api_responses" ]]; then
            for response_file in $api_responses; do
                echo "### Response: $(basename $response_file)" >> "$platform_analysis"
                echo '```json' >> "$platform_analysis"
                cat "$response_file" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            done
        fi
    fi
    
    # Analyze container logs
    local container_logs=$(find "$log_dir" -name "cosmos-container-*" -type f)
    if [[ -n "$container_logs" ]]; then
        echo "## Container Logs Analysis" >> "$platform_analysis"
        for container_log in $container_logs; do
            echo "### $(basename $container_log)" >> "$platform_analysis"
            
            # Look for startup issues
            if grep -q "ERROR\|FATAL\|Exception" "$container_log"; then
                echo "#### Errors Found:" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
                grep -n "ERROR\|FATAL\|Exception" "$container_log" | head -20 >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            fi
            
            # Look for schema-related messages
            if grep -q "schema\|cosmos_api" "$container_log"; then
                echo "#### Schema-related Messages:" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
                grep -n "schema\|cosmos_api" "$container_log" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            fi
            
            # Container startup status
            if grep -q "Started\|Ready\|Listening" "$container_log"; then
                echo "#### Startup Status:" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
                grep -n "Started\|Ready\|Listening" "$container_log" | tail -10 >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            fi
        done
    fi
    
    # Analyze Aspire output
    local aspire_logs=$(find "$log_dir" -name "aspire-output-*" -type f)
    if [[ -n "$aspire_logs" ]]; then
        echo "## Aspire Output Analysis" >> "$platform_analysis"
        for aspire_log in $aspire_logs; do
            echo "### $(basename $aspire_log)" >> "$platform_analysis"
            
            # Look for Aspire startup issues
            if grep -q "Failed\|Error\|Exception" "$aspire_log"; then
                echo "#### Aspire Errors:" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
                grep -n -i "Failed\|Error\|Exception" "$aspire_log" | head -20 >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            fi
            
            # Look for resource creation
            if grep -q "Creating resource\|Starting resource" "$aspire_log"; then
                echo "#### Resource Creation:" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
                grep -n "Creating resource\|Starting resource" "$aspire_log" >> "$platform_analysis"
                echo '```' >> "$platform_analysis"
            fi
        done
    fi
    
    log "Analysis completed for $platform, saved to $platform_analysis" "INFO"
}

# Main analysis
log "Starting log analysis..." "INFO"

# Analyze each platform
platforms=("windows" "ubuntu" "macos")
declare -A platform_status

for platform in "${platforms[@]}"; do
    if analyze_platform_logs "$platform"; then
        platform_status[$platform]="analyzed"
    else
        platform_status[$platform]="no_logs"
    fi
done

# Create comprehensive analysis report
cat > "$ANALYSIS_DIR/comprehensive-analysis.md" << 'EOF'
# Comprehensive Analysis: Azure Cosmos DB Emulator vNext Issue

## Issue Summary
This analysis examines the reproduction of GitHub issue #199: "vNext Emulator Issue with GitHub Actions & .NET Aspire"

The issue manifests as a schema error: `schema "cosmos_api" does not exist` when using the Azure Cosmos DB emulator vNext with .NET Aspire in CI/CD environments, particularly GitHub Actions on Ubuntu.

## Cross-Platform Analysis Results

EOF

# Add platform-specific results
for platform in "${platforms[@]}"; do
    echo "### $platform Results" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
    
    case ${platform_status[$platform]} in
        "analyzed")
            echo "✅ Analysis completed successfully" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
            
            # Check if issue was reproduced
            local platform_file="$ANALYSIS_DIR/${platform}-analysis.md"
            if [[ -f "$platform_file" ]] && grep -q "Schema Issue Reproduced" "$platform_file"; then
                echo "🔴 **Issue Reproduced**: The schema error was successfully reproduced on $platform" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
            elif [[ -f "$platform_file" ]] && grep -q "Schema Issue Not Reproduced" "$platform_file"; then
                echo "🟢 **Issue Not Reproduced**: Tests passed on $platform" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
            else
                echo "🟡 **Inconclusive**: Unable to determine if issue was reproduced" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
            fi
            ;;
        "no_logs")
            echo "❌ No logs available for analysis" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
            ;;
    esac
    echo "" >> "$ANALYSIS_DIR/comprehensive-analysis.md"
done

# Add detailed technical analysis
cat >> "$ANALYSIS_DIR/comprehensive-analysis.md" << 'EOF'
## Technical Analysis

### Root Cause Investigation

Based on the error pattern `schema "cosmos_api" does not exist`, this appears to be related to:

1. **Database Schema Initialization**: The Cosmos DB emulator vNext may have issues with schema initialization in containerized environments
2. **Timing Issues**: The emulator might not be fully ready when the application attempts to connect
3. **Platform-Specific Configuration**: Different behavior between local development and CI/CD environments

### Aspire Integration Issues

The issue specifically occurs when using .NET Aspire to manage the Cosmos DB emulator container, suggesting:

1. **Container Lifecycle Management**: Aspire's container management may not wait for complete emulator initialization
2. **Environment Variable Propagation**: Required environment variables may not be properly set
3. **Network Configuration**: Container networking issues in CI environments

### Recommended Solutions

1. **Add Initialization Delays**: Implement proper health checks and startup delays
2. **Enhanced Error Handling**: Add retry logic with exponential backoff
3. **Container Configuration**: Optimize emulator settings for CI environments
4. **Aspire Configuration**: Use persistent container lifetime and enhanced logging

### Next Steps

1. Test with different Aspire configurations
2. Implement custom health checks
3. Add schema initialization verification
4. Consider alternative container orchestration approaches

EOF

# Create summary for GitHub Actions
cat > "$ANALYSIS_DIR/github-summary.md" << 'EOF'
# Test Execution Summary

## Platform Results

EOF

for platform in "${platforms[@]}"; do
    echo "- **$platform**: ${platform_status[$platform]}" >> "$ANALYSIS_DIR/github-summary.md"
    
    if [[ ${platform_status[$platform]} == "analyzed" ]]; then
        local platform_file="$ANALYSIS_DIR/${platform}-analysis.md"
        if [[ -f "$platform_file" ]]; then
            if grep -q "Schema Issue Reproduced" "$platform_file"; then
                echo "  - ✅ Issue reproduced successfully" >> "$ANALYSIS_DIR/github-summary.md"
            elif grep -q "Schema Issue Not Reproduced" "$platform_file"; then
                echo "  - ❌ Issue not reproduced" >> "$ANALYSIS_DIR/github-summary.md"
            fi
        fi
    fi
done

cat >> "$ANALYSIS_DIR/github-summary.md" << 'EOF'

## Key Findings

The test execution aimed to reproduce the schema error `cosmos_api does not exist` that occurs when using Azure Cosmos DB emulator vNext with .NET Aspire in CI/CD environments.

## Artifacts

- Platform-specific analysis reports
- Container logs and API responses
- Comprehensive technical analysis
- Recommendations for resolution

Check the uploaded artifacts for detailed logs and analysis results.
EOF

log "Comprehensive analysis completed" "INFO"
log "Reports generated:" "INFO"
log "  - Platform analyses: $ANALYSIS_DIR/*-analysis.md" "INFO"
log "  - Comprehensive report: $ANALYSIS_DIR/comprehensive-analysis.md" "INFO"
log "  - GitHub summary: $ANALYSIS_DIR/github-summary.md" "INFO"
