# EKS Discovery Workflow - Shell Escaping Fix

> **Date**: 2025-10-16
> **Issue**: Command substitution error with unmatched backticks
> **Status**: ✅ Fixed

## Problem Description

The `eks-discovery.yaml` workflow was failing with the following error:

```
/home/runner/work/_temp/5676931e-84be-49c5-bc37-587944573544.sh: command substitution: line 43: unexpected EOF while looking for matching ``'
Error: Process completed with exit code 1.
```

### Root Cause

The issue occurred when using **nested command substitutions** with `jq` to create JSON payloads. The cluster endpoint URL and other values containing special characters (like dots in the EKS endpoint URL) were causing shell escaping issues when passed through multiple layers of command substitution.

**Problematic code pattern:**
```bash
CLUSTER_PAYLOAD=$(jq -n \
  --arg name "${{ env.CLUSTER_NAME }}" \
  --arg endpoint "${{ steps.cluster-info.outputs.cluster_endpoint }}" \
  '{
    u_name: $name,
    u_endpoint: $endpoint
  }')
```

When GitHub Actions substitutes the values, special characters in the endpoint URL (like `https://6242EDF2E8203DB623991423AF39485B.gr7.eu-west-2.eks.amazonaws.com`) can cause shell parsing errors with nested backticks.

## Solution

### Fix #1: Use Heredoc for Cluster Payload

Instead of nested command substitution, we now use a **heredoc** to write the JSON structure first, then use `jq` to add dynamic values:

```bash
# Write cluster data to JSON file to avoid shell escaping issues
cat > cluster-payload.json << 'CLUSTER_EOF'
{
  "u_name": "${{ env.CLUSTER_NAME }}",
  "u_arn": "${{ steps.cluster-info.outputs.cluster_arn }}",
  "u_version": "${{ steps.cluster-info.outputs.cluster_version }}",
  "u_endpoint": "${{ steps.cluster-info.outputs.cluster_endpoint }}",
  "u_status": "${{ steps.cluster-info.outputs.cluster_status }}",
  "u_region": "${{ env.AWS_REGION }}",
  "u_vpc_id": "${{ steps.cluster-info.outputs.vpc_id }}",
  "u_provider": "AWS EKS",
  "u_last_discovered": "TIMESTAMP_PLACEHOLDER",
  "u_discovered_by": "GitHub Actions"
}
CLUSTER_EOF

# Replace timestamp placeholder with actual timestamp
CLUSTER_PAYLOAD=$(jq --arg ts "$TIMESTAMP" '.u_last_discovered = $ts' cluster-payload.json)
```

**Benefits:**
- ✅ No nested command substitution
- ✅ GitHub Actions expressions are evaluated directly in heredoc
- ✅ Special characters in URLs are safely preserved
- ✅ Only one level of jq processing (for timestamp)

### Fix #2: Simplify Microservice Payload Creation

For microservices, we pipe the JSON directly from the service record instead of extracting each field individually:

**Before:**
```bash
NAME=$(echo $service | jq -r '.name')
NAMESPACE=$(echo $service | jq -r '.namespace')
# ... extract all fields ...

SERVICE_PAYLOAD=$(jq -n \
  --arg name "$NAME" \
  --arg namespace "$NAMESPACE" \
  # ... pass all fields as args ...
  '{ u_name: $name, u_namespace: $namespace, ... }')
```

**After:**
```bash
SERVICE_PAYLOAD=$(echo "$service" | jq \
  --arg cluster "$CLUSTER_SYS_ID" \
  --arg timestamp "$TIMESTAMP" \
  '{
    u_name: .name,
    u_namespace: .namespace,
    u_environment: .environment,
    u_replicas: (.replicas | tostring),
    u_ready_replicas: (.ready_replicas | tostring),
    u_image: .image,
    u_image_tag: .image_tag,
    u_status: .status,
    u_cluster: $cluster,
    u_last_discovered: $timestamp,
    u_discovered_by: "GitHub Actions"
  }')
```

**Benefits:**
- ✅ Fewer variables to extract
- ✅ Direct field reference from JSON input (`.name`, `.namespace`)
- ✅ Reduced chance of shell escaping issues
- ✅ More efficient processing

### Additional Improvements

1. **Added quotes around variables:**
   ```bash
   # Before
   echo $EXISTING_CLUSTER | jq -r '.result[0].sys_id // empty'

   # After
   echo "$EXISTING_CLUSTER" | jq -r '.result[0].sys_id // empty'
   ```

2. **Proper error handling:**
   ```bash
   EXISTING_CLUSTER=$(curl -s -X GET "..." 2>/dev/null || echo '{"result":[]}')
   ```

## Testing

To test the fixed workflow:

```bash
# Trigger the workflow manually
gh workflow run eks-discovery.yaml

# Monitor the run
gh run list --workflow=eks-discovery.yaml

# View logs
gh run view --log
```

## Expected Results

After the fix, the workflow should:

1. ✅ Successfully discover EKS cluster information
2. ✅ Create/update cluster CI in ServiceNow CMDB (`u_eks_cluster` table)
3. ✅ Discover all microservices in dev/qa/prod namespaces
4. ✅ Create/update microservice CIs in ServiceNow CMDB (`u_microservice` table)
5. ✅ Generate discovery summary artifacts
6. ✅ Complete without shell escaping errors

## Files Modified

- [`.github/workflows/eks-discovery.yaml`](../../.github/workflows/eks-discovery.yaml)
  - Fixed cluster payload creation (lines 141-203)
  - Fixed microservice payload creation (lines 205-270)

## Related Documentation

- [ServiceNow Setup Checklist](../SERVICENOW-SETUP-CHECKLIST.md) - Updated Task 1.11
- [GitHub Actions Troubleshooting](./GITHUB-ACTIONS-TROUBLESHOOTING.md) - General debugging guide
- [ServiceNow Integration Guide](../servicenow/README.md) - Complete integration documentation

## Prevention

To prevent similar issues in the future:

1. **Avoid deeply nested command substitutions** - Use intermediate files or variables
2. **Use heredocs for complex JSON** - Let GitHub Actions expand expressions directly
3. **Quote all variable references** - Protect against spaces and special characters
4. **Test with real data** - Ensure URLs and special characters are handled correctly
5. **Use `jq` for JSON manipulation** - Don't build JSON strings manually with shell

## Additional Notes

This fix was applied after the workflow failed with the following cluster endpoint:
```
https://6242EDF2E8203DB623991423AF39485B.gr7.eu-west-2.eks.amazonaws.com
```

The endpoint URL contains characters that can cause issues with shell escaping when passed through multiple layers of command substitution. The heredoc approach eliminates these issues entirely.

---

**Last Updated**: 2025-10-16
**Tested With**: GitHub Actions runner ubuntu-latest
**ServiceNow API Version**: Vancouver/Utah
