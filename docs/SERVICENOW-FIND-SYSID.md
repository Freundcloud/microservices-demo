# How to Find sys_id Values in ServiceNow

**Last Updated**: 2025-10-14

This guide shows you how to find the `sys_id` values needed for ServiceNow DevOps integration with GitHub Actions.

---

## What is a sys_id?

A `sys_id` (system ID) is ServiceNow's unique identifier for every record in the database. It's a 32-character hexadecimal string that looks like:

```
abc123def456ghi789jkl012mno345pq
```

You'll need several `sys_id` values for the GitHub Actions integration:
- **Orchestration Tool ID** (GitHub)
- **Security Scanner Tool IDs** (CodeQL, Semgrep, Trivy, Checkov, OWASP)

---

## Method 1: Find sys_id via ServiceNow UI (Easiest)

### Step 1: Enable sys_id Column Display

This is the easiest method and works for all tables.

1. **Navigate to the table** (e.g., DevOps > Orchestration Tools)
2. **Right-click on any column header** in the list view
3. **Click "Personalize List"**
4. **In "Available" section**, find `Sys ID`
5. **Click the `>` arrow** to move it to "Selected"
6. **Click "OK"**

Now you'll see the `sys_id` column in your list view!

### Step 2: Copy the sys_id

- Simply copy the 32-character sys_id value from the list
- Use this value in your GitHub Secrets

---

## Method 2: Find sys_id from Record URL

When viewing any record in ServiceNow, the sys_id is in the URL.

### Example URL:
```
https://your-instance.service-now.com/nav_to.do?uri=sn_devops_orchestration_tool.do?sys_id=abc123def456ghi789jkl012mno345pq
```

The part after `sys_id=` is your sys_id: `abc123def456ghi789jkl012mno345pq`

### Steps:

1. **Open the record** you want the sys_id for
2. **Look at the browser URL bar**
3. **Find `sys_id=` in the URL**
4. **Copy everything after `sys_id=`** until the next `&` or end of URL

---

## Method 3: Use ServiceNow REST API

If you're comfortable with APIs, you can query for sys_ids.

### Using curl:

```bash
# Set your ServiceNow instance details
SN_INSTANCE="your-instance.service-now.com"
SN_USER="your-username"
SN_PASS="your-password"

# Get orchestration tool sys_id for GitHub
curl -s -u "$SN_USER:$SN_PASS" \
  "https://$SN_INSTANCE/api/now/table/sn_devops_orchestration_tool?sysparm_query=name=GitHub&sysparm_fields=sys_id,name" \
  | jq -r '.result[0].sys_id'

# Get security scanner sys_id for CodeQL
curl -s -u "$SN_USER:$SN_PASS" \
  "https://$SN_INSTANCE/api/now/table/sn_devops_security_tool?sysparm_query=name=CodeQL&sysparm_fields=sys_id,name" \
  | jq -r '.result[0].sys_id'
```

---

## Finding Specific sys_id Values

### 1. GitHub Orchestration Tool sys_id

**Path**: DevOps > Orchestration Tools > GitHub

#### Steps:
1. **Log into ServiceNow**
2. **Navigate to**: All > DevOps > Orchestration Tools
3. **Find "GitHub Actions"** in the list (or your GitHub tool name)
4. **Method A** - Use list view:
   - Enable sys_id column (see Method 1 above)
   - Copy the sys_id from the list
5. **Method B** - Open the record:
   - Click on the GitHub tool name
   - Copy sys_id from the URL

**Use as**: `SN_ORCHESTRATION_TOOL_ID`

---

### 2. Security Scanner sys_id Values

**Path**: DevOps > Security > Scanners

#### CodeQL Scanner sys_id

1. **Navigate to**: All > DevOps > Security > Scanners
2. **Find "CodeQL"** in the list
3. **Copy the sys_id** using either method above

**Use as**: `SN_CODEQL_TOOL_ID`

#### Semgrep Scanner sys_id

1. **Navigate to**: All > DevOps > Security > Scanners
2. **Find "Semgrep"** in the list
3. **Copy the sys_id**

**Use as**: `SN_SEMGREP_TOOL_ID`

#### Trivy Scanner sys_id

1. **Navigate to**: All > DevOps > Security > Scanners
2. **Find "Trivy"** in the list
3. **Copy the sys_id**

**Use as**: `SN_TRIVY_TOOL_ID`

#### Checkov Scanner sys_id

1. **Navigate to**: All > DevOps > Security > Scanners
2. **Find "Checkov"** in the list
3. **Copy the sys_id**

**Use as**: `SN_CHECKOV_TOOL_ID`

#### OWASP Dependency Check Scanner sys_id

1. **Navigate to**: All > DevOps > Security > Scanners
2. **Find "OWASP Dependency Check"** in the list
3. **Copy the sys_id**

**Use as**: `SN_OWASP_TOOL_ID`

---

## Visual Guide

### Finding sys_id in List View

```
╔════════════════════════════════════════════════════════════╗
║ Orchestration Tools                                        ║
╠════════════╦══════════════════╦════════════════════════════╣
║ Name       ║ Type             ║ Sys ID                     ║
╠════════════╬══════════════════╬════════════════════════════╣
║ GitHub     ║ GitHub           ║ abc123def456...            ║ ← Copy this
║ Jenkins    ║ Jenkins          ║ ghi789jkl012...            ║
╚════════════╩══════════════════╩════════════════════════════╝
```

### Finding sys_id in URL

```
Browser URL bar:
┌─────────────────────────────────────────────────────────────────┐
│ https://instance.service-now.com/...sys_id=abc123def456...     │
│                                            └─────────┬─────────┘ │
│                                                      │           │
│                                            Copy this part       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Table

| Secret Name | ServiceNow Location | Navigation Path |
|-------------|---------------------|-----------------|
| `SN_ORCHESTRATION_TOOL_ID` | Orchestration Tools > GitHub | DevOps > Orchestration Tools |
| `SN_CODEQL_TOOL_ID` | Security Scanners > CodeQL | DevOps > Security > Scanners |
| `SN_SEMGREP_TOOL_ID` | Security Scanners > Semgrep | DevOps > Security > Scanners |
| `SN_TRIVY_TOOL_ID` | Security Scanners > Trivy | DevOps > Security > Scanners |
| `SN_CHECKOV_TOOL_ID` | Security Scanners > Checkov | DevOps > Security > Scanners |
| `SN_OWASP_TOOL_ID` | Security Scanners > OWASP | DevOps > Security > Scanners |

---

## Troubleshooting

### "I don't see the sys_id column"

**Solution**: Follow Method 1 above to enable the sys_id column in list view.

### "I can't find the table/menu"

**Solution**:
- Check you have the correct role: `sn_devops.integration_user`
- Try using the search box at the top: Type "Orchestration Tools" or "Security Scanners"
- Ask your ServiceNow admin for access

### "The record doesn't exist"

**Solution**:
- You need to create the record first (see main documentation)
- For orchestration tools: Create GitHub tool in DevOps > Orchestration Tools
- For scanners: Create scanner records in DevOps > Security > Scanners

### "I copied the sys_id but it's not working"

**Checklist**:
- ✅ sys_id is exactly 32 characters
- ✅ No spaces before or after
- ✅ All lowercase (ServiceNow sys_ids are lowercase)
- ✅ Only contains: 0-9, a-f (hexadecimal)

---

## Example: Complete Setup Workflow

Here's a complete example of finding all sys_ids:

### 1. Find Orchestration Tool ID

```bash
# Navigate to ServiceNow
https://your-instance.service-now.com

# Go to: All > DevOps > Orchestration Tools
# Click on "GitHub Actions" (or your tool name)
# URL will show:
https://your-instance.service-now.com/...sys_id=abc123def456ghi789jkl012mno345pq

# Copy: abc123def456ghi789jkl012mno345pq
```

### 2. Find Security Scanner IDs

```bash
# Go to: All > DevOps > Security > Scanners
# Enable sys_id column (right-click column header > Personalize List)
# Copy sys_id for each scanner:

CodeQL:    def456ghi789jkl012mno345pqr678st
Semgrep:   ghi789jkl012mno345pqr678stu901vw
Trivy:     jkl012mno345pqr678stu901vwx234yz
Checkov:   mno345pqr678stu901vwx234yza567bc
OWASP:     pqr678stu901vwx234yza567bcd890ef
```

### 3. Set GitHub Secrets

```bash
gh secret set SN_ORCHESTRATION_TOOL_ID --body "abc123def456ghi789jkl012mno345pq"
gh secret set SN_CODEQL_TOOL_ID --body "def456ghi789jkl012mno345pqr678st"
gh secret set SN_SEMGREP_TOOL_ID --body "ghi789jkl012mno345pqr678stu901vw"
gh secret set SN_TRIVY_TOOL_ID --body "jkl012mno345pqr678stu901vwx234yz"
gh secret set SN_CHECKOV_TOOL_ID --body "mno345pqr678stu901vwx234yza567bc"
gh secret set SN_OWASP_TOOL_ID --body "pqr678stu901vwx234yza567bcd890ef"
```

---

## Additional Resources

- [ServiceNow DevOps Documentation](https://docs.servicenow.com/bundle/tokyo-devops/page/product/enterprise-dev-ops/reference/devops-landing-page.html)
- [ServiceNow sys_id Documentation](https://docs.servicenow.com/bundle/tokyo-platform-administration/page/administer/reference-pages/concept/c_SYSID.html)
- [Main Integration Guide](SERVICENOW-INTEGRATION.md)

---

## Need Help?

If you're still having trouble finding sys_id values:

1. **Check your ServiceNow role** - You need `sn_devops.integration_user` role
2. **Ask your ServiceNow admin** - They can help you navigate and find records
3. **Use the search** - Type "Orchestration Tools" in the ServiceNow search box
4. **Check the documentation** - Your organization may have custom navigation

---

**Tip**: Save all your sys_id values in a secure password manager. You'll need them every time you set up a new repository or reconfigure GitHub Actions.
