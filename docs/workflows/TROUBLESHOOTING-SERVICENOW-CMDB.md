# Troubleshooting ServiceNow CMDB Discovery Workflow

> **Purpose**: Resolve common issues with ServiceNow CMDB discovery workflow
> **Related Workflow**: `.github/workflows/eks-discovery.yaml`
> **Last Updated**: 2025-10-16

## Table of Contents

1. [Quick Fixes](#quick-fixes)
2. [Common Errors](#common-errors)
3. [Shell Syntax Issues](#shell-syntax-issues)
4. [ServiceNow API Issues](#servicenow-api-issues)
5. [Authentication Problems](#authentication-problems)
6. [Data Validation](#data-validation)

---

## Quick Fixes

### Current Error: Heredoc Shell Syntax Error

**Error Message:**
```bash
/home/runner/work/_temp/xxx.sh: command substitution: line 36: unexpected EOF while looking for matching `'
Error: Process completed with exit code 1.
```

**Root Cause:**
The heredoc syntax `cat <<EOF` was mixing shell command substitution (`$(date)`) with GitHub Actions template syntax (`${{ }}`), causing backtick parsing errors.

**Solution Applied:**
Use `jq` to build JSON payloads instead of heredocs. This avoids all shell escaping issues:

```yaml
# ❌ WRONG - Heredoc with mixed syntax
CLUSTER_PAYLOAD=$(cat <<EOF
{
  "u_name": "${{ env.CLUSTER_NAME }}",
  "u_last_discovered": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "u_discovered_by": "GitHub Actions"
}
EOF
)

# ✅ CORRECT - Use jq for JSON construction
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CLUSTER_PAYLOAD=$(jq -n \
  --arg name "${{ env.CLUSTER_NAME }}" \
  --arg timestamp "$TIMESTAMP" \
  '{
    u_name: $name,
    u_last_discovered: $timestamp,
    u_discovered_by: "GitHub Actions"
  }')
```

**Benefits of jq approach:**
- ✅ No shell escaping issues
- ✅ Proper JSON formatting guaranteed
- ✅ Safe handling of special characters
- ✅ Works with GitHub Actions template syntax
- ✅ No backtick conflicts

---

## Common Errors

### Error 1: Empty JSON Responses from ServiceNow

**Symptoms:**
```bash
CLUSTER_SYS_ID=$(echo $EXISTING_CLUSTER | jq -r '.result[0].sys_id // empty')
# Returns empty even when record exists
```

**Common Causes:**

1. **Wrong Table Name:**
```bash
# Check if table exists in ServiceNow
curl -s -X GET \
  "$SN_INSTANCE_URL/api/now/table/sys_db_object?sysparm_query=name=u_eks_cluster" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN"
```

2. **Wrong Query Syntax:**
```bash
# Incorrect
sysparm_query=u_name=microservices

# Correct - must encode special characters
sysparm_query=u_name%3Dmicroservices
```

3. **Permission Issues:**
- User must have `rest_service` role
- User must have read access to custom tables

**Solutions:**

```yaml
- name: Debug ServiceNow Response
  run: |
    RESPONSE=$(curl -s -X GET \
      "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster?sysparm_query=u_name=${{ env.CLUSTER_NAME }}&sysparm_limit=1" \
      -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
      -H "Content-Type: application/json")

    echo "ServiceNow Response:"
    echo "$RESPONSE" | jq '.'

    # Check for errors
    if echo "$RESPONSE" | jq -e '.error' > /dev/null; then
      echo "ERROR: $(echo $RESPONSE | jq -r '.error.message')"
      exit 1
    fi
```

### Error 2: 401 Unauthorized

**Error Message:**
```json
{
  "error": {
    "message": "User Not Authenticated",
    "detail": "Required to provide Auth information"
  }
}
```

**Solutions:**

1. **Verify Token Format:**
```bash
# OAuth token should be used with "Bearer"
-H "Authorization: Bearer $SN_OAUTH_TOKEN"

# Basic auth uses base64 encoded credentials
-H "Authorization: Basic $(echo -n 'user:password' | base64)"
```

2. **Test Token Manually:**
```bash
# Test from local machine
export SN_INSTANCE_URL="https://yourinstance.service-now.com"
export SN_OAUTH_TOKEN="your_token_here"

curl -s -X GET \
  "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
```

3. **Check Token Expiration:**
```bash
# In ServiceNow, navigate to:
# System OAuth > Access Tokens
# Check expiration date
```

### Error 3: 403 Forbidden

**Error Message:**
```json
{
  "error": {
    "message": "Insufficient rights",
    "detail": "ACL restricts operation"
  }
}
```

**Root Causes:**
- User lacks roles for table access
- Table ACLs not configured for API access
- API is disabled in ServiceNow instance

**Solutions:**

1. **Check User Roles:**
```javascript
// In ServiceNow Background Scripts
var user = new GlideRecord('sys_user');
user.addQuery('user_name', 'github_integration');
user.query();
if (user.next()) {
    var roles = user.getRoles();
    gs.info('User roles: ' + roles.join(', '));
}
```

2. **Required Roles for CMDB Updates:**
```
- rest_service
- api_analytics_read
- itil (for CMDB access)
- cmdb_write (for creating/updating CIs)
```

3. **Create/Update ACL for Custom Tables:**
```javascript
// Navigate to: System Security > Access Control (ACL)
// Create ACL for u_eks_cluster table
// Operation: read, write
// Roles: rest_service, cmdb_write
// Type: record
```

### Error 4: Invalid JSON in Request Body

**Error Message:**
```json
{
  "error": {
    "message": "Invalid JSON in request body",
    "detail": "Unexpected character at line 1 column 45"
  }
}
```

**Common Causes:**

1. **Unescaped Special Characters:**
```bash
# Problem: Unescaped quotes in JSON
IMAGE="myapp:latest"  # If this contains quotes or other special chars

# Solution: Use jq with --arg
SERVICE_PAYLOAD=$(jq -n --arg img "$IMAGE" '{ u_image: $img }')
```

2. **Newlines in Values:**
```bash
# Problem: Description contains newlines
DESCRIPTION="Line 1
Line 2"

# Solution: Use jq and it handles escaping
PAYLOAD=$(jq -n --arg desc "$DESCRIPTION" '{ description: $desc }')
```

3. **Empty Required Fields:**
```bash
# Check for empty values before building JSON
if [ -z "$NAME" ]; then
  echo "ERROR: Service name is empty"
  exit 1
fi
```

---

## Shell Syntax Issues

### Issue 1: Heredoc with Command Substitution

**Problem:**
```bash
# This fails when backticks or $() are mixed
PAYLOAD=$(cat <<EOF
{
  "field": "$(command with `backticks`)"
}
EOF
)
```

**Solutions:**

**Option A: Use Quoted Heredoc (Disables Substitution):**
```bash
# Single quotes prevent expansion
PAYLOAD=$(cat <<'EOF'
{
  "field": "value"
}
EOF
)
```

**Option B: Use jq (Recommended):**
```bash
# Build JSON with jq
VALUE=$(command with backticks)
PAYLOAD=$(jq -n --arg val "$VALUE" '{ field: $val }')
```

**Option C: Pre-compute Variables:**
```bash
# Compute values first, then use in heredoc
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
NAME="cluster-name"

PAYLOAD=$(cat <<EOF
{
  "name": "${NAME}",
  "timestamp": "${TIMESTAMP}"
}
EOF
)
```

### Issue 2: Quoting in Loops

**Problem:**
```bash
# Spaces in values break the loop
for service in $SERVICES; do
  # $service might be broken if it contains spaces
done
```

**Solution:**
```bash
# Use proper quoting
while IFS= read -r service; do
  # Process $service safely
done <<< "$SERVICES"

# Or use jq for JSON arrays
jq -c '.[]' services.json | while IFS= read -r service; do
  # Process each JSON object
done
```

### Issue 3: GitHub Actions Template Variables

**Best Practices:**
```yaml
# ✅ GOOD - Extract to shell variables first
- name: Process Data
  run: |
    CLUSTER_NAME="${{ env.CLUSTER_NAME }}"
    REGION="${{ env.AWS_REGION }}"

    # Now use shell variables
    echo "Cluster: $CLUSTER_NAME in $REGION"

# ❌ AVOID - Mixing templates and shell in complex expressions
- name: Process Data
  run: |
    PAYLOAD="{ \"name\": \"${{ env.CLUSTER_NAME }}\", \"region\": \"${{ env.AWS_REGION }}\" }"
```

---

## ServiceNow API Issues

### Issue 1: Rate Limiting

**Symptoms:**
- HTTP 429 responses
- Slow API responses
- Timeouts

**Solutions:**

1. **Add Retry Logic:**
```yaml
- name: Upload to ServiceNow with Retry
  run: |
    MAX_RETRIES=3
    RETRY_DELAY=5

    for i in $(seq 1 $MAX_RETRIES); do
      RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster" \
        -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
        -H "Content-Type: application/json" \
        -d "$CLUSTER_PAYLOAD")

      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
      BODY=$(echo "$RESPONSE" | head -n-1)

      if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Success!"
        break
      elif [ "$HTTP_CODE" = "429" ]; then
        echo "Rate limited, retry $i/$MAX_RETRIES in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
      else
        echo "Error $HTTP_CODE: $BODY"
        exit 1
      fi
    done
```

2. **Batch Updates:**
```yaml
# Instead of updating each service individually, batch them
- name: Batch Update Services
  run: |
    # Collect all payloads
    jq -c '.services[]' all-services.json > services.ndjson

    # Send in batches of 10
    split -l 10 services.ndjson batch_

    for batch in batch_*; do
      # Process batch
      while IFS= read -r service; do
        # Update service
      done < "$batch"

      # Add delay between batches
      sleep 2
    done
```

### Issue 2: Large Payload Failures

**Symptoms:**
- Request entity too large
- Timeouts on large requests

**Solutions:**

1. **Trim Unnecessary Data:**
```bash
# Only send essential fields
SERVICE_PAYLOAD=$(echo $service | jq '{
  u_name: .name,
  u_namespace: .namespace,
  u_status: .status
  # Omit large fields like full spec
}')
```

2. **Split Large Requests:**
```bash
# If services array is huge, process in chunks
jq -c '.services[]' all-services.json | split -l 50 - service_chunk_

for chunk in service_chunk_*; do
  # Process each chunk
  echo "Processing chunk: $chunk"
  # ... upload logic
done
```

### Issue 3: Slow Table Queries

**Problem:**
```bash
# This query is slow on large tables
sysparm_query=u_name=$NAME^u_namespace=$NAMESPACE
```

**Solutions:**

1. **Add Indexes in ServiceNow:**
```javascript
// Navigate to: System Definition > Tables
// Open u_microservice table
// Add indexes on frequently queried fields:
// - u_name
// - u_namespace
// - u_name + u_namespace (compound index)
```

2. **Use Sys ID for Updates:**
```bash
# Cache sys_id mapping locally
echo "$NAME|$NAMESPACE|$SYS_ID" >> ci_mapping.txt

# Next run, read from cache instead of querying
SYS_ID=$(grep "^$NAME|$NAMESPACE|" ci_mapping.txt | cut -d'|' -f3)
```

---

## Authentication Problems

### Using OAuth Tokens

**Setup OAuth Application in ServiceNow:**

1. **Create OAuth Application:**
```
Navigate to: System OAuth > Application Registry
Click: New
Select: Create an OAuth API endpoint for external clients
```

2. **Configure:**
```
Name: GitHub CMDB Integration
Client ID: (copy this)
Client Secret: (copy this)
Refresh Token Lifespan: 8640000 (100 days)
Access Token Lifespan: 1800 (30 minutes)
```

3. **Get Access Token:**
```bash
curl -X POST \
  "$SN_INSTANCE_URL/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$SN_USERNAME" \
  -d "password=$SN_PASSWORD"
```

4. **Store Token in GitHub Secrets:**
```bash
# In GitHub repository settings
Settings > Secrets and variables > Actions > New repository secret
Name: SN_OAUTH_TOKEN
Value: <access_token_from_response>
```

### Using Basic Authentication (Not Recommended)

```yaml
- name: Upload with Basic Auth
  run: |
    AUTH_HEADER=$(echo -n "username:password" | base64)

    curl -X POST \
      "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster" \
      -H "Authorization: Basic $AUTH_HEADER" \
      -H "Content-Type: application/json" \
      -d "$CLUSTER_PAYLOAD"
```

---

## Data Validation

### Validate Before Upload

```yaml
- name: Validate Data Before Upload
  run: |
    # Validate cluster data
    if [ -z "${{ steps.cluster-info.outputs.cluster_arn }}" ]; then
      echo "ERROR: Cluster ARN is empty"
      exit 1
    fi

    # Validate JSON structure
    echo "$CLUSTER_PAYLOAD" | jq empty || {
      echo "ERROR: Invalid JSON in cluster payload"
      exit 1
    }

    # Validate required fields
    REQUIRED_FIELDS=("u_name" "u_region" "u_status")
    for field in "${REQUIRED_FIELDS[@]}"; do
      if ! echo "$CLUSTER_PAYLOAD" | jq -e ".$field" > /dev/null; then
        echo "ERROR: Missing required field: $field"
        exit 1
      fi
    done
```

### Verify Upload Success

```yaml
- name: Verify Upload to ServiceNow
  run: |
    # Wait a bit for data to be indexed
    sleep 5

    # Query back what we just uploaded
    VERIFY=$(curl -s -X GET \
      "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster/$CLUSTER_SYS_ID" \
      -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}")

    # Check response
    VERIFY_NAME=$(echo $VERIFY | jq -r '.result.u_name')

    if [ "$VERIFY_NAME" != "${{ env.CLUSTER_NAME }}" ]; then
      echo "ERROR: Verification failed - uploaded data doesn't match"
      exit 1
    fi

    echo "✅ Verified: Data successfully uploaded to ServiceNow"
```

---

## Debugging Tips

### Enable Verbose Logging

```yaml
- name: Upload with Debug Logging
  run: |
    # Enable bash debug mode
    set -x

    # Capture HTTP response details
    RESPONSE=$(curl -v -s -w "\n%{http_code}" -X POST \
      "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster" \
      -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
      -H "Content-Type: application/json" \
      -d "$CLUSTER_PAYLOAD" 2>&1)

    echo "Full Response:"
    echo "$RESPONSE"

    # Turn off debug mode
    set +x
```

### Save Payloads as Artifacts

```yaml
- name: Save Payloads for Debugging
  if: always()
  run: |
    echo "$CLUSTER_PAYLOAD" > cluster-payload.json
    jq -c '.services[]' all-services.json > services-payloads.ndjson

- name: Upload Debug Artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: servicenow-debug-${{ github.run_number }}
    path: |
      cluster-payload.json
      services-payloads.ndjson
      *.log
```

### Test Locally with Docker

```bash
# Create test script
cat > test-servicenow.sh <<'EOF'
#!/bin/bash
set -e

export SN_INSTANCE_URL="https://yourinstance.service-now.com"
export SN_OAUTH_TOKEN="your_token"

# Build payload
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CLUSTER_PAYLOAD=$(jq -n \
  --arg name "test-cluster" \
  --arg timestamp "$TIMESTAMP" \
  '{
    u_name: $name,
    u_region: "eu-west-2",
    u_status: "ACTIVE",
    u_last_discovered: $timestamp
  }')

echo "Payload:"
echo "$CLUSTER_PAYLOAD" | jq '.'

# Test upload
curl -v -X POST \
  "$SN_INSTANCE_URL/api/now/table/u_eks_cluster" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$CLUSTER_PAYLOAD"
EOF

chmod +x test-servicenow.sh
./test-servicenow.sh
```

---

## Best Practices

### 1. Use jq for All JSON Operations

```bash
# ✅ GOOD
PAYLOAD=$(jq -n --arg name "$NAME" '{ u_name: $name }')

# ❌ AVOID
PAYLOAD="{\"u_name\": \"$NAME\"}"
```

### 2. Always Check HTTP Response Codes

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$URL" ...)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

case $HTTP_CODE in
  200|201) echo "Success" ;;
  401) echo "Authentication failed"; exit 1 ;;
  403) echo "Permission denied"; exit 1 ;;
  429) echo "Rate limited"; sleep 10; retry ;;
  *) echo "Unexpected error: $HTTP_CODE"; exit 1 ;;
esac
```

### 3. Implement Idempotency

```bash
# Always check if record exists before creating
if [ -n "$SYS_ID" ]; then
  # Update existing
  METHOD="PUT"
  URL="$SN_INSTANCE_URL/api/now/table/u_eks_cluster/$SYS_ID"
else
  # Create new
  METHOD="POST"
  URL="$SN_INSTANCE_URL/api/now/table/u_eks_cluster"
fi

curl -X $METHOD "$URL" -d "$PAYLOAD" ...
```

### 4. Handle Errors Gracefully

```bash
# Don't fail entire workflow on single service failure
while IFS= read -r service; do
  if ! upload_service "$service"; then
    echo "⚠️ Failed to upload service, continuing..."
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

if [ $FAILED_COUNT -gt 0 ]; then
  echo "⚠️ $FAILED_COUNT services failed to upload"
fi
```

---

## Support Resources

### ServiceNow Documentation
- [REST API Reference](https://docs.servicenow.com/bundle/tokyo-application-development/page/integrate/inbound-rest/concept/c_RESTAPI.html)
- [OAuth Setup](https://docs.servicenow.com/bundle/tokyo-platform-administration/page/administer/security/task/t_SettingUpOAuth.html)
- [Table API](https://docs.servicenow.com/bundle/tokyo-application-development/page/integrate/inbound-rest/concept/c_TableAPI.html)

### Debugging Commands
```bash
# Test ServiceNow connectivity
curl -v "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1"

# Validate JSON
echo "$PAYLOAD" | jq empty && echo "Valid JSON"

# Test shell escaping
bash -n workflow-script.sh && echo "No syntax errors"
```

---

**Last Updated**: 2025-10-16
**Maintained By**: DevOps Team
**Review Frequency**: After each ServiceNow integration update
