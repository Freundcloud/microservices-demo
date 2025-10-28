# ServiceNow Authentication Composite Action

This composite action prepares ServiceNow authentication credentials for use in workflows, supporting both official ServiceNow GitHub Actions and direct curl-based API calls.

## Purpose

Centralizes ServiceNow authentication logic and provides credentials in multiple formats:
- Direct username/password for ServiceNow official actions
- Base64-encoded Basic Auth for curl commands
- Instance URL and tool ID for API calls

## Usage

### Basic Usage with ServiceNow Official Actions

```yaml
- name: Prepare ServiceNow Auth
  id: sn-auth
  uses: ./.github/actions/servicenow-auth
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

- name: Upload Test Results to ServiceNow
  uses: ServiceNow/servicenow-devops-test-report@v6.0.0
  with:
    devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
    devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
    instance-url: ${{ steps.sn-auth.outputs.instance-url }}
    tool-id: ${{ steps.sn-auth.outputs.tool-id }}
    context-github: ${{ toJSON(github) }}
    job-name: 'My Job'
    xml-report-filename: test-results.xml
```

### Usage with curl (REST API)

```yaml
- name: Prepare ServiceNow Auth
  id: sn-auth
  uses: ./.github/actions/servicenow-auth
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

- name: Register Discovery Data
  run: |
    curl -X POST "${{ steps.sn-auth.outputs.instance-url }}/api/now/table/cmdb_ci" \
      -H "Authorization: Basic ${{ steps.sn-auth.outputs.basic-auth }}" \
      -H "Content-Type: application/json" \
      -d '{
        "name": "my-eks-cluster",
        "environment": "production"
      }'
```

## Inputs

This action doesn't have explicit inputs - it reads from environment variables:

| Environment Variable | Description | Required | Example |
|---------------------|-------------|----------|---------|
| `SERVICENOW_USERNAME` | ServiceNow integration username | Yes | `github.integration@company.com` |
| `SERVICENOW_PASSWORD` | ServiceNow integration password | Yes | `***` (from secrets) |
| `SERVICENOW_INSTANCE_URL` | ServiceNow instance URL | Yes | `https://company.service-now.com` |
| `SN_ORCHESTRATION_TOOL_ID` | ServiceNow orchestration tool ID | Yes | `abc123def456` |

## Outputs

| Output | Description | Format | Usage |
|--------|-------------|--------|-------|
| `username` | ServiceNow username | String | For ServiceNow actions |
| `password` | ServiceNow password | String | For ServiceNow actions |
| `instance-url` | ServiceNow instance URL | URL | For ServiceNow actions and API calls |
| `tool-id` | Orchestration tool ID | String | For ServiceNow DevOps actions |
| `basic-auth` | Base64-encoded Basic Auth | Base64 | For curl Authorization header |

## What This Action Does

1. Reads ServiceNow credentials from environment variables
2. Passes through username, password, instance URL, and tool ID as outputs
3. **Generates Base64-encoded Basic Auth** for curl commands
4. Provides all credentials in easily accessible output format

## Authentication Methods Supported

### 1. ServiceNow Official GitHub Actions

These actions require username and password directly:
- `ServiceNow/servicenow-devops-test-report@v6.0.0`
- `ServiceNow/servicenow-devops-register-package@v3.1.0`
- `ServiceNow/servicenow-devops-sonar@v3.1.0`

**Example**:
```yaml
uses: ServiceNow/servicenow-devops-test-report@v6.0.0
with:
  devops-integration-user-name: ${{ steps.sn-auth.outputs.username }}
  devops-integration-user-password: ${{ steps.sn-auth.outputs.password }}
```

### 2. curl with Basic Authentication

For direct API calls using curl, use the pre-encoded Basic Auth:

**Example**:
```yaml
curl -X GET "${{ steps.sn-auth.outputs.instance-url }}/api/now/table/cmdb_ci" \
  -H "Authorization: Basic ${{ steps.sn-auth.outputs.basic-auth }}"
```

## Benefits

- **Centralized Authentication**: Single source for all ServiceNow credentials
- **Multiple Formats**: Supports both official actions and curl commands
- **Base64 Encoding**: Automatically generates Basic Auth header
- **Consistency**: Same authentication pattern across all workflows
- **Maintainability**: Update authentication logic in one place
- **Security**: Credentials passed via environment variables (secrets)

## Security Considerations

- **Secrets Handling**: Always pass secrets via environment variables
- **No Hardcoding**: Never hardcode credentials in workflows
- **Masked Outputs**: Password and basic-auth outputs are automatically masked by GitHub
- **Scope**: Use ServiceNow integration users with minimal required permissions

## Workflows Using This Action

- `aws-infrastructure-discovery.yaml` (curl-based API calls)
- `build-images.yaml` (ServiceNow DevOps actions)
- `run-unit-tests.yaml` (test report uploads)
- `servicenow-change-rest.yaml` (change request management)

## Related Actions

- [Setup AWS Credentials](./../setup-aws-credentials/README.md) - AWS authentication
- [Fix SARIF URIs](./../fix-sarif-uris/README.md) - SARIF file fixing

## Example: Complete Workflow

```yaml
jobs:
  discover-and-register:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Prepare ServiceNow Auth
        id: sn-auth
        uses: ./.github/actions/servicenow-auth
        env:
          SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
          SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
          SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
          SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

      - name: Discover AWS Resources
        run: |
          # Your discovery logic here
          echo "Discovered EKS cluster: my-cluster"

      - name: Register in ServiceNow CMDB
        run: |
          curl -X POST "${{ steps.sn-auth.outputs.instance-url }}/api/now/table/cmdb_ci" \
            -H "Authorization: Basic ${{ steps.sn-auth.outputs.basic-auth }}" \
            -H "Content-Type: application/json" \
            -d '{
              "name": "my-cluster",
              "type": "EKS Cluster",
              "environment": "production"
            }'
```

## Troubleshooting

### Issue: "Unauthorized" Error

**Cause**: Invalid credentials or expired password

**Solution**:
1. Verify secrets are correctly set in GitHub repository settings
2. Check ServiceNow integration user is active
3. Verify password hasn't expired

### Issue: "Tool ID not found"

**Cause**: `SN_ORCHESTRATION_TOOL_ID` secret not set or invalid

**Solution**:
1. Run `scripts/find-servicenow-tool-id.sh` to get the correct tool ID
2. Update `SN_ORCHESTRATION_TOOL_ID` secret in GitHub

### Issue: "Instance URL unreachable"

**Cause**: ServiceNow instance URL is incorrect or instance is down

**Solution**:
1. Verify `SERVICENOW_INSTANCE_URL` format: `https://instance.service-now.com` (no trailing slash)
2. Check ServiceNow instance is accessible from GitHub Actions runners
3. Verify firewall/IP whitelist allows GitHub Actions IPs

## Migration Guide

### Before (Inline Auth)

```yaml
- name: Call ServiceNow API
  run: |
    BASIC_AUTH=$(echo -n "${{ secrets.SERVICENOW_USERNAME }}:${{ secrets.SERVICENOW_PASSWORD }}" | base64)
    curl -H "Authorization: Basic $BASIC_AUTH" \
      "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/cmdb_ci"
```

### After (Using Composite Action)

```yaml
- name: Prepare ServiceNow Auth
  id: sn-auth
  uses: ./.github/actions/servicenow-auth
  env:
    SERVICENOW_USERNAME: ${{ secrets.SERVICENOW_USERNAME }}
    SERVICENOW_PASSWORD: ${{ secrets.SERVICENOW_PASSWORD }}
    SERVICENOW_INSTANCE_URL: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    SN_ORCHESTRATION_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

- name: Call ServiceNow API
  run: |
    curl -H "Authorization: Basic ${{ steps.sn-auth.outputs.basic-auth }}" \
      "${{ steps.sn-auth.outputs.instance-url }}/api/now/table/cmdb_ci"
```

**Benefits of Migration**:
- 3 lines reduced to 1 for auth preparation
- Base64 encoding handled automatically
- Consistent authentication pattern
- Easier to maintain and update
