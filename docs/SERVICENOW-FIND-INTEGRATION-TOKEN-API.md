# Finding ServiceNow Integration Token via API

**Created**: 2025-10-21
**Purpose**: Methods to retrieve the ServiceNow DevOps integration token programmatically

## Current Situation

- **Tool ID (sys_id)**: `2fe9c38bc36c72d0e1bbf0cb050131cc`
- **Instance**: `https://calitiiltddemo3.service-now.com`
- **Current Token** (not working): `FgZDc9PYn0b5RqGBRoN2K3VddMrHy3pa`
- **Integration Type**: GitHub Apps

## Method 1: ServiceNow Table API (Requires Basic Auth)

### Prerequisites
You need ServiceNow credentials with access to the DevOps tables.

### Add Credentials to `.envrc`

```bash
# Add these lines to .envrc
export SERVICENOW_USERNAME='your.username'
export SERVICENOW_PASSWORD='your.password'
```

Then reload:
```bash
source .envrc
```

### Query the Tool Record

```bash
curl -X GET \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/2fe9c38bc36c72d0e1bbf0cb050131cc?sysparm_display_value=false" | jq '.'
```

### Query Specific Fields Only

```bash
curl -X GET \
  -H "Accept: application/json" \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/2fe9c38bc36c72d0e1bbf0cb050131cc?sysparm_fields=sys_id,name,token,integration_token,devops_integration_token,credential" | jq '.result'
```

### Expected Response

```json
{
  "result": {
    "sys_id": "2fe9c38bc36c72d0e1bbf0cb050131cc",
    "name": "GitHub Demo",
    "token": "value_here",
    "integration_token": "value_here",
    "credential": {
      "link": "...",
      "value": "credential_sys_id"
    }
  }
}
```

## Method 2: Check All Possible Token Fields

Different ServiceNow versions may use different field names. Try querying all possible fields:

```bash
source .envrc

curl -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/2fe9c38bc36c72d0e1bbf0cb050131cc" | jq '.result | {
    sys_id,
    name,
    token,
    integration_token,
    devops_token,
    devops_integration_token,
    api_token,
    auth_token,
    credential,
    app_id,
    installation_id,
    type
  }'
```

## Method 3: Check Credentials Table

If the token is stored in a separate credentials record:

### Step 1: Get Credential Reference
```bash
curl -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/2fe9c38bc36c72d0e1bbf0cb050131cc?sysparm_fields=credential" | jq '.result.credential'
```

### Step 2: Query the Credential Record
If you get a credential sys_id, query it:
```bash
CREDENTIAL_ID="<sys_id_from_above>"

curl -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/discovery_credentials/${CREDENTIAL_ID}" | jq '.result'
```

## Method 4: Alternative Table - sn_devops_tool

Try the alternative DevOps tool table:

```bash
curl -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool?sysparm_query=sys_id=2fe9c38bc36c72d0e1bbf0cb050131cc" | jq '.result'
```

## Method 5: List All GitHub Tools

If the sys_id is wrong, find all GitHub-related tools:

```bash
curl -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool?sysparm_query=nameLIKEGitHub^ORnameLIKEgithub&sysparm_fields=sys_id,name,type,integration_token" | jq '.result'
```

## Method 6: Using ServiceNow CLI (if installed)

If you have ServiceNow CLI tools installed:

```bash
# Login
snow login --instance calitiiltddemo3

# Query the record
snow record get \
  --table sn_devops_orchestration_tool \
  --sys-id 2fe9c38bc36c72d0e1bbf0cb050131cc \
  --fields sys_id,name,integration_token
```

## Method 7: Direct Database Query (Admin Only)

If you have admin access to the ServiceNow instance:

1. Navigate to: **System Definition > Tables**
2. Search for: `sn_devops_orchestration_tool`
3. Click on the table
4. Run query: `sys_id=2fe9c38bc36c72d0e1bbf0cb050131cc`

## Common Field Names to Check

The integration token might be stored in any of these fields:

- `token`
- `integration_token`
- `devops_token`
- `devops_integration_token`
- `api_token`
- `auth_token`
- `bearer_token`
- `oauth_token`
- `credential` (reference to credentials table)
- `app_token`

## For GitHub Apps Integration Specifically

If using GitHub Apps, also check these fields:

- `app_id` - GitHub App ID
- `installation_id` - GitHub App Installation ID
- `private_key` - GitHub App private key (encrypted)
- `app_token` - Auto-generated token from GitHub App

The integration token for GitHub Apps is typically auto-generated and stored in the tool record when the app is connected.

## Troubleshooting

### Error: "User is not authenticated" when querying API

**Solution**: Add ServiceNow credentials to `.envrc`:
```bash
export SERVICENOW_USERNAME='your.username'
export SERVICENOW_PASSWORD='your.password'
```

### Error: "Access denied to sn_devops_orchestration_tool"

**Solution**: Your ServiceNow user needs these roles:
- `sn_devops.user`
- `sn_devops.integration_user`
- Or `admin` role

### Token field is empty or null

**Possible causes**:
1. GitHub App not fully configured
2. Token needs to be generated/regenerated
3. Token is stored in a separate credentials record
4. Using OAuth instead of token authentication

**Solution**: Check the GitHub tool configuration in ServiceNow UI to generate the token.

## Security Best Practices

⚠️ **WARNING**: Never commit the integration token to git!

After retrieving the token:

1. **Store in `.envrc`** (which is gitignored):
   ```bash
   export SN_DEVOPS_INTEGRATION_TOKEN='token_value_here'
   ```

2. **Update GitHub secret**:
   ```bash
   source .envrc
   gh secret set SN_DEVOPS_INTEGRATION_TOKEN --body "$SN_DEVOPS_INTEGRATION_TOKEN"
   ```

3. **Test the connection**:
   ```bash
   curl -X POST \
     "https://calitiiltddemo3.service-now.com/api/sn_devops/v3/devops/tool/test?toolId=2fe9c38bc36c72d0e1bbf0cb050131cc&token=${SN_DEVOPS_INTEGRATION_TOKEN}"
   ```

Expected success response:
```json
{
  "status": "success",
  "result": "Tool test successful"
}
```

## Quick Start Command

After adding ServiceNow credentials to `.envrc`, run this one-liner:

```bash
source .envrc && \
curl -s -X GET \
  -u "${SERVICENOW_USERNAME}:${SERVICENOW_PASSWORD}" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_orchestration_tool/2fe9c38bc36c72d0e1bbf0cb050131cc" \
  | jq -r '.result | "Tool Name: \(.name)\nSys ID: \(.sys_id)\nIntegration Token: \(.integration_token // .token // "NOT FOUND")\nApp ID: \(.app_id // "N/A")\nInstallation ID: \(.installation_id // "N/A")"'
```

## Next Steps After Finding Token

1. **Update `.envrc`** with the correct token
2. **Update GitHub secret**
3. **Test connection** using curl
4. **Trigger workflow** to verify end-to-end integration
5. **Monitor ServiceNow error logs** for any remaining issues

## Related Documentation

- [SERVICENOW-WEBHOOK-TROUBLESHOOTING.md](SERVICENOW-WEBHOOK-TROUBLESHOOTING.md) - Webhook configuration troubleshooting
- [SERVICENOW-DEVOPS-INTEGRATION-TOKEN-SETUP.md](SERVICENOW-DEVOPS-INTEGRATION-TOKEN-SETUP.md) - Token setup guide
- [SERVICENOW-SECURITY-WEBHOOK-FIX.md](SERVICENOW-SECURITY-WEBHOOK-FIX.md) - Security webhook fixes

---

**Last Updated**: 2025-10-21
**Status**: Documentation for API-based token retrieval
