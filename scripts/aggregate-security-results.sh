#!/bin/bash

################################################################################
# Aggregate Security Scan Results
################################################################################
#
# This script aggregates SARIF files from multiple security scanning tools
# into a single JSON structure ready for upload to ServiceNow.
#
# Usage:
#   ./aggregate-security-results.sh
#
# Environment Variables:
#   GITHUB_RUN_ID - GitHub Actions run ID
#   GITHUB_REPOSITORY - GitHub repository name
#   GITHUB_SHA - Git commit SHA
#   GITHUB_REF_NAME - Git branch name
#
################################################################################

set -euo pipefail

# Configuration
SCAN_ID="${GITHUB_RUN_ID:-$(date +%s)}-$(date +%s)"
REPOSITORY="${GITHUB_REPOSITORY:-unknown}"
COMMIT_SHA="${GITHUB_SHA:-unknown}"
BRANCH="${GITHUB_REF_NAME:-unknown}"
OUTPUT_FILE="aggregated-security-results.json"
SUMMARY_FILE="security-scan-summary.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Initialize output structure
initialize_output() {
    log_info "Initializing output files..."

    cat > $OUTPUT_FILE << EOF
{
  "scan_id": "$SCAN_ID",
  "repository": "$REPOSITORY",
  "commit_sha": "$COMMIT_SHA",
  "branch": "$BRANCH",
  "scan_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "findings": []
}
EOF

    cat > $SUMMARY_FILE << EOF
{
  "scan_id": "$SCAN_ID",
  "repository": "$REPOSITORY",
  "commit_sha": "$COMMIT_SHA",
  "branch": "$BRANCH",
  "scan_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_findings": 0,
  "critical_count": 0,
  "high_count": 0,
  "medium_count": 0,
  "low_count": 0,
  "info_count": 0,
  "tools_run": [],
  "github_url": "https://github.com/$REPOSITORY/actions/runs/$GITHUB_RUN_ID"
}
EOF
}

# Map SARIF level to severity
map_severity() {
    local level="$1"
    local security_severity="$2"

    # Check if we have a CVSS score
    if [ -n "$security_severity" ] && [ "$security_severity" != "null" ]; then
        local score=$(echo "$security_severity" | awk '{print int($1)}')
        if [ "$score" -ge 9 ]; then
            echo "CRITICAL"
        elif [ "$score" -ge 7 ]; then
            echo "HIGH"
        elif [ "$score" -ge 4 ]; then
            echo "MEDIUM"
        else
            echo "LOW"
        fi
    else
        # Map SARIF levels
        case "$level" in
            "error") echo "HIGH" ;;
            "warning") echo "MEDIUM" ;;
            "note") echo "LOW" ;;
            *) echo "INFO" ;;
        esac
    fi
}

# Generate unique finding ID
generate_finding_id() {
    local tool="$1"
    local rule_id="$2"
    local file_path="$3"
    local line_number="$4"

    echo "${tool}:${rule_id}:${file_path}:${line_number}" | md5sum | cut -d' ' -f1
}

# Extract CVE ID from tags or rule ID
extract_cve() {
    local tags="$1"
    local rule_id="$2"

    # Check tags for CVE
    if echo "$tags" | grep -qiE "CVE-[0-9]{4}-[0-9]+"; then
        echo "$tags" | grep -oiE "CVE-[0-9]{4}-[0-9]+" | head -1
    # Check rule ID for CVE
    elif echo "$rule_id" | grep -qiE "CVE-[0-9]{4}-[0-9]+"; then
        echo "$rule_id" | grep -oiE "CVE-[0-9]{4}-[0-9]+" | head -1
    else
        echo ""
    fi
}

# Process a single SARIF file
process_sarif_file() {
    local sarif_file="$1"

    if [ ! -f "$sarif_file" ]; then
        log_warning "SARIF file not found: $sarif_file"
        return
    fi

    log_info "Processing $sarif_file..."

    # Extract tool name
    local tool_name=$(jq -r '.runs[0].tool.driver.name // "Unknown"' "$sarif_file")
    local tool_version=$(jq -r '.runs[0].tool.driver.version // "unknown"' "$sarif_file")

    log_info "Tool: $tool_name v$tool_version"

    # Process each result
    jq -c '.runs[0].results[]? // empty' "$sarif_file" | while read -r result; do
        # Extract basic fields
        local rule_id=$(echo "$result" | jq -r '.ruleId // "unknown"')
        local level=$(echo "$result" | jq -r '.level // "warning"')
        local message=$(echo "$result" | jq -r '.message.text // .message.markdown // "No description"')

        # Extract location
        local file_path=$(echo "$result" | jq -r '.locations[0].physicalLocation.artifactLocation.uri // "unknown"')
        local line_number=$(echo "$result" | jq -r '.locations[0].physicalLocation.region.startLine // 0')

        # Extract properties
        local security_severity=$(echo "$result" | jq -r '.properties."security-severity" // null')
        local tags=$(echo "$result" | jq -r '.properties.tags[]? // empty' | paste -sd ',' -)

        # Map severity
        local severity=$(map_severity "$level" "$security_severity")

        # Extract CVE if present
        local cve_id=$(extract_cve "$tags" "$rule_id")

        # Generate unique finding ID
        local finding_id=$(generate_finding_id "$tool_name" "$rule_id" "$file_path" "$line_number")

        # Create GitHub URL (if applicable)
        local github_url="https://github.com/$REPOSITORY/blob/$COMMIT_SHA/$file_path#L$line_number"

        # Create finding JSON
        local finding=$(jq -n \
            --arg scan_id "$SCAN_ID" \
            --arg scan_type "$tool_name" \
            --arg scan_date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg finding_id "$finding_id" \
            --arg severity "$severity" \
            --arg title "$(echo "$message" | head -c 255)" \
            --arg description "$message" \
            --arg file_path "$file_path" \
            --arg line_number "$line_number" \
            --arg rule_id "$rule_id" \
            --arg cve_id "$cve_id" \
            --arg repository "$REPOSITORY" \
            --arg branch "$BRANCH" \
            --arg commit_sha "$COMMIT_SHA" \
            --arg github_url "$github_url" \
            --argjson sarif_data "$result" \
            '{
                u_scan_id: $scan_id,
                u_scan_type: $scan_type,
                u_scan_date: $scan_date,
                u_finding_id: $finding_id,
                u_severity: $severity,
                u_title: $title,
                u_description: $description,
                u_file_path: $file_path,
                u_line_number: ($line_number | tonumber),
                u_rule_id: $rule_id,
                u_cve_id: $cve_id,
                u_repository: $repository,
                u_branch: $branch,
                u_commit_sha: $commit_sha,
                u_github_url: $github_url,
                u_status: "Open",
                u_false_positive: false,
                u_suppressed: false
            }')

        # Add to aggregated results
        jq --argjson finding "$finding" '.findings += [$finding]' $OUTPUT_FILE > tmp.json
        mv tmp.json $OUTPUT_FILE
    done

    # Add tool to summary
    jq --arg tool "$tool_name" '.tools_run += [$tool] | .tools_run |= unique' $SUMMARY_FILE > tmp.json
    mv tmp.json $SUMMARY_FILE
}

# Calculate summary statistics
calculate_summary() {
    log_info "Calculating summary statistics..."

    local total=$(jq '.findings | length' $OUTPUT_FILE)
    local critical=$(jq '[.findings[] | select(.u_severity == "CRITICAL")] | length' $OUTPUT_FILE)
    local high=$(jq '[.findings[] | select(.u_severity == "HIGH")] | length' $OUTPUT_FILE)
    local medium=$(jq '[.findings[] | select(.u_severity == "MEDIUM")] | length' $OUTPUT_FILE)
    local low=$(jq '[.findings[] | select(.u_severity == "LOW")] | length' $OUTPUT_FILE)
    local info=$(jq '[.findings[] | select(.u_severity == "INFO")] | length' $OUTPUT_FILE)

    jq \
        --arg total "$total" \
        --arg critical "$critical" \
        --arg high "$high" \
        --arg medium "$medium" \
        --arg low "$low" \
        --arg info "$info" \
        '.total_findings = ($total | tonumber) |
         .critical_count = ($critical | tonumber) |
         .high_count = ($high | tonumber) |
         .medium_count = ($medium | tonumber) |
         .low_count = ($low | tonumber) |
         .info_count = ($info | tonumber)' $SUMMARY_FILE > tmp.json
    mv tmp.json $SUMMARY_FILE

    log_info "Summary:"
    log_info "  Total findings: $total"
    log_info "  Critical: $critical"
    log_info "  High: $high"
    log_info "  Medium: $medium"
    log_info "  Low: $low"
    log_info "  Info: $info"
}

# Main execution
main() {
    log_info "Starting security results aggregation..."
    log_info "Scan ID: $SCAN_ID"
    log_info "Repository: $REPOSITORY"
    log_info "Commit: $COMMIT_SHA"
    log_info "Branch: $BRANCH"

    initialize_output

    # Process all SARIF files
    log_info "Searching for SARIF files..."

    # Common locations for SARIF files
    for sarif in \
        codeql-results-*.sarif \
        semgrep-results.sarif \
        trivy-fs-results.sarif \
        checkov-results.sarif \
        tfsec-results.sarif \
        dependency-check-report/dependency-check-report.sarif \
        sarif-results/**/*.sarif
    do
        if compgen -G "$sarif" > /dev/null 2>&1; then
            for file in $sarif; do
                process_sarif_file "$file"
            done
        fi
    done

    calculate_summary

    log_info "Aggregation complete!"
    log_info "Output: $OUTPUT_FILE"
    log_info "Summary: $SUMMARY_FILE"
}

main "$@"
