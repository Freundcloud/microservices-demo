# ServiceNow Authentication Troubleshooting Guide

> **Issue**: Getting "User is not authenticated" error when calling ServiceNow API

## Your Current Error

```json
{"error":{"message":"User is not authenticated","detail":"Required to provide Auth information"},"status":"failure"}
```

## Step-by-Step Troubleshooting

### Step 1: Test Basic Connectivity

First, verify ServiceNow API is accessible:

```bash
curl -I https://calitiiltddemo3.service-now.com/api/now/table/sys_user
```

**Expected**: HTTP 401 Unauthorized (this is good - means API is accessible)

---

### Step 2: Verify User Exists and is Active

**In ServiceNow UI:**

1. Navigate to: **User Administration > Users**
2. Search for: `github_integration`
3. Verify:
   - ✅ User exists
   - ✅ **Active** checkbox is checked
   - ✅ **Locked out** is NOT checked
   - ✅ **Web service access only** is checked

**If user is locked out:**
- Uncheck "Locked out"
- Click "Update"

---

### Step 3: Test with Admin User First

To isolate if it's a user permission issue, test with your admin account:

```bash
curl -X GET \
  -H "Accept: application/json" \
  -u "your_admin_username:your_admin_password" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**If admin works but github_integration doesn't:**
- Issue is with the service account configuration
- Proceed to Step 4

**If admin also fails:**
- Issue is with API access or instance configuration
- Contact ServiceNow admin

---

### Step 4: Special Characters in Password

Your password has many special characters: `$`, `<`, `>`, `!`, `=`, `{`, `}`, `?`, `;`, etc.

**These can cause issues in shell commands!**

#### Solution A: Use Single Quotes (Recommended)

```bash
curl -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**Note**: Changed `"github_integration:..."` to `'github_integration:...'`

#### Solution B: Escape Special Characters

If single quotes don't work, escape each special character:

```bash
curl -X GET \
  -H "Accept: application/json" \
  -u "github_integration:U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb\$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

#### Solution C: Store in Variable

```bash
# Store password in variable
PASSWORD='U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw'

# Use variable in curl
curl -X GET \
  -H "Accept: application/json" \
  -u "github_integration:$PASSWORD" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

#### Solution D: Use .netrc File (Most Secure)

```bash
# Create .netrc file
cat > ~/.netrc << 'EOF'
machine calitiiltddemo3.service-now.com
login github_integration
password U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw
EOF

# Set permissions
chmod 600 ~/.netrc

# Use curl without -u flag (reads from .netrc)
curl -n -X GET \
  -H "Accept: application/json" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

---

### Step 5: Test with Simple Endpoint

Don't test with the GitHub tool endpoint yet. Start simple:

```bash
# Test 1: List users (should work for any authenticated user)
curl -v -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:YOUR_PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# Test 2: Get your own user record
curl -v -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:YOUR_PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_query=user_name=github_integration"
```

**Expected Success Response:**
```json
{
  "result": [
    {
      "sys_id": "...",
      "user_name": "github_integration",
      "first_name": "GitHub",
      "last_name": "Integration",
      "active": "true"
    }
  ]
}
```

---

### Step 6: Check User Roles

The user needs specific roles for API access:

**In ServiceNow UI:**

1. Navigate to: **User Administration > Users**
2. Search for: `github_integration`
3. Open user record
4. Go to **Roles** tab
5. Verify these roles exist:
   - ✅ `rest_service`
   - ✅ `api_analytics_read`
   - ✅ `devops_user`
   - ✅ `web_service_admin` (optional but helpful)

**To add missing roles:**
1. Click **Edit** in Roles section
2. Add missing roles from the list
3. Click **Save**
4. Click **Update** on user record

---

### Step 7: Check API Access Control Rules

**In ServiceNow UI:**

1. Navigate to: **System Web Services > REST > REST API Access**
2. Look for rules blocking `github_integration` user
3. Or check: **System Security > Access Control (ACL)**

**Common issues:**
- User doesn't have read access to `sn_devops_tool` table
- IP restrictions blocking requests
- Session timeout settings

---

### Step 8: Try Base64 Auth Header Directly

Bypass `-u` flag completely:

```bash
# Encode credentials manually
echo -n 'github_integration:U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw' | base64

# Copy the output, then use it:
curl -X GET \
  -H "Accept: application/json" \
  -H "Authorization: Basic Z2l0aHViX2ludGVncmF0aW9uOlU0ZHJ4YVJRQUEtZ3JIOUlARmFlTTd2LlVYOXcsczxXWmYlO1ZJM2k/UDxnKUJzO3tWSSkjOUZXaTh1WnZVS1FiJFF6dVc+IT1ZbDEzbE19UTxsekQ1KXd9XlA5Q20pR1R4S3c=" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

---

### Step 9: Check ServiceNow Logs

**In ServiceNow UI:**

1. Navigate to: **System Logs > System Log > All**
2. Filter by:
   - User: `github_integration`
   - Time: Last 15 minutes
3. Look for authentication failures

**Alternative:**
1. Navigate to: **System Security > Authentication Log**
2. Look for failed login attempts

---

### Step 10: Reset Password to Simple One (Temporary)

To isolate if special characters are the issue:

**Set a simple temporary password:**
- Example: `TestPassword123!`

```bash
# Test with simple password
curl -v -X GET \
  -H "Accept: application/json" \
  -u "github_integration:TestPassword123!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**If this works:**
- Issue is with special characters in complex password
- Use simpler password or proper escaping
- Update password in GitHub Secrets

**If this still fails:**
- Issue is with user configuration or permissions
- Proceed to Step 11

---

### Step 11: Check "Web Service Access Only" Setting

**The "Web service access only" checkbox has two effects:**

1. ✅ **Checked**: User can ONLY access APIs (no UI login)
2. ❌ **Unchecked**: User can access both UI and APIs

**Test by temporarily unchecking it:**

1. Navigate to: **User Administration > Users**
2. Open: `github_integration`
3. **Uncheck**: "Web service access only"
4. Click **Update**
5. Try API call again

**If it works after unchecking:**
- There might be an ACL rule preventing web service only users
- Contact ServiceNow admin to fix ACLs
- For now, leave it unchecked (less secure but functional)

---

### Step 12: Verify Instance URL

Make sure you're using the correct instance URL format:

**Correct formats:**
```
https://calitiiltddemo3.service-now.com
https://calitiiltddemo3.service-now.com/
```

**Incorrect formats:**
```
http://calitiiltddemo3.service-now.com  (missing 's' in https)
https://calitiiltddemo3.service-now.com/api  (don't include /api in base URL)
```

---

## Quick Diagnostic Commands

Run all these in sequence:

```bash
# 1. Test instance connectivity
curl -I https://calitiiltddemo3.service-now.com/api/now/table/sys_user

# 2. Test with single quotes (handles special chars)
curl -v -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:YOUR_PASSWORD_HERE' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# 3. Test with base64 auth
BASIC_AUTH=$(echo -n 'github_integration:YOUR_PASSWORD_HERE' | base64)
curl -v -X GET \
  -H "Accept: application/json" \
  -H "Authorization: Basic $BASIC_AUTH" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# 4. Check if user exists
# (This will fail auth but shows different error if user doesn't exist)
curl -v -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:wrong_password' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

---

## Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "User is not authenticated" | Credentials wrong or user locked | Check password, check user active |
| "User Not Authenticated: User name or password invalid" | Wrong credentials | Reset password |
| "Access Denied" | No permissions | Add required roles |
| "Endpoint not found" | Wrong URL | Check instance URL |
| "Connection refused" | Network issue | Check VPN/firewall |

---

## Next Steps Based on Results

### ✅ If Simple Endpoint Works (`/sys_user`)

Then test the GitHub tool endpoint:

```bash
curl -v -X GET \
  -H "Accept: application/json" \
  -u 'github_integration:YOUR_PASSWORD' \
  "https://calitiiltddemo3.service-now.com/api/now/table/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135"
```

**If this fails but sys_user worked:**
- User doesn't have read access to `sn_devops_tool` table
- Add `devops_user` role
- Or add ACL rule for the table

### ❌ If Nothing Works

1. **Use ServiceNow admin account to:**
   - Check user record in detail
   - Check authentication logs
   - Verify ACL rules

2. **Contact ServiceNow support:**
   - Provide user sys_id
   - Provide authentication log screenshots
   - Ask about API access restrictions

3. **Create new integration user:**
   - Follow Task 1.3 again
   - Use simple password initially
   - Test immediately after creation

---

## Recommended Password Format

For fewer issues with special characters, use this pattern:

**Format:** `[Word][Number][Special][Word][Number][Special]`

**Examples:**
```
GitHub2024!Integration2024#
DevOps2024@ServiceNow2024!
ApiKey2024#Access2024!
```

**Avoid these characters in passwords for API use:**
- `$` (shell variable)
- `` ` `` (backtick)
- `\` (escape character)
- `"` (quote)
- `'` (single quote)

**Safe special characters:**
- `!` `@` `#` `%` `^` `&` `*` `-` `_` `+` `=`

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
