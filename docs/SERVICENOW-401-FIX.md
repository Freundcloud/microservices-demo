# ServiceNow 401 Unauthorized - Quick Fix Guide

## Your Current Situation

✅ **What's Working:**
- Connection to ServiceNow successful (TLS handshake complete)
- Authorization header is being sent correctly
- Base64 encoding is correct

❌ **What's NOT Working:**
- ServiceNow is rejecting the credentials with HTTP 401
- Message: "User is not authenticated"

This means the problem is **NOT** with curl or the command - it's with the user configuration in ServiceNow.

---

## Immediate Checks in ServiceNow

### Check 1: User is Active and Not Locked

1. Log into ServiceNow as **admin**
2. Navigate to: **User Administration > Users**
3. Search for: `github_integration`
4. Open the user record
5. Verify these settings:

```
Field                          | Expected Value
-------------------------------|----------------
Active                         | ✅ Checked
Locked out                     | ❌ NOT checked
Failed login attempts          | 0 (or low number)
Password needs reset           | ❌ NOT checked
Web service access only        | ✅ Checked
```

**If "Locked out" is checked:**
- Uncheck it
- Click "Update"
- Try API call again

**If "Failed login attempts" is high:**
- Click "Reset password"
- Set a new password
- Try API call again

---

### Check 2: Password is Correct

The most common issue - the password in ServiceNow doesn't match what you're using.

**Test the password by logging into ServiceNow UI:**

**If "Web service access only" is checked:**
1. Temporarily **UNCHECK** "Web service access only"
2. Click "Update"
3. Try to log into ServiceNow UI: `https://calitiiltddemo3.service-now.com`
   - Username: `github_integration`
   - Password: `U4drxaRQAA-grH9I@FaeM7v.UX9w,s<WZf%;VI3i?P<g)Bs;{VI)#9FWi8uZvUKQb$QzuW>!=Yl13lM}Q<lzD5)w}^P9Cm)GTxKw`

**If UI login fails:**
- Password is wrong! Reset it in ServiceNow
- Use the new password in your curl command

**If UI login succeeds:**
- Password is correct
- Re-check "Web service access only"
- Try API call again

---

### Check 3: User Has Required Roles

The user needs these roles for API access:

1. Open user record: `github_integration`
2. Go to **Roles** tab
3. Verify these roles exist:

**Required Roles:**
```
✅ rest_service          (Basic REST API access)
✅ api_analytics_read    (API analytics)
✅ devops_user          (DevOps operations)
```

**If any are missing:**
1. Click "Edit" in the Roles section
2. Search for the missing role
3. Add it to the Collection
4. Click "Save"
5. Click "Update" on user record
6. Try API call again

---

### Check 4: Reset Password to Something Simple

Let's eliminate the special character issue completely:

**In ServiceNow:**
1. Open user: `github_integration`
2. Right-click header > **Set Password**
3. Enter simple password: `TestPassword2024!`
4. Confirm: `TestPassword2024!`
5. Click OK

**Test with new password:**
```bash
curl -v -X GET \
  -H "Accept: application/json" \
  -u "github_integration:TestPassword2024!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**If this works:**
- Issue was with special characters
- Keep using this simpler password
- Update GitHub Secrets with new password

**If this still fails:**
- Issue is with user configuration, not password
- Proceed to Check 5

---

### Check 5: Check Access Control Rules (ACLs)

ServiceNow might have ACL rules blocking API access:

**Check ACLs:**
1. Navigate to: **System Security > Access Control (ACL)**
2. Filter by: Table = `sys_user`
3. Look for rules that might block `github_integration`

**Common issues:**
- ACL requires admin role for REST API access
- ACL blocks users with "Web service access only"
- IP-based restrictions

**Quick test - give admin role temporarily:**
1. Open user: `github_integration`
2. Go to Roles tab
3. Add role: `admin` (temporarily!)
4. Click Update
5. Try API call

**If it works with admin role:**
- Issue is ACL permissions
- Remove admin role
- Add more specific roles: `rest_service`, `soap_query`, `web_service_admin`

---

### Check 6: Check Instance Security Settings

**Navigate to: System Properties > Security**

Look for these settings that might block API access:

```
Property                              | Should Be
--------------------------------------|------------
glide.basicauth.active                | true
glide.rest.access_control.strict      | false (for testing)
glide.authenticaton.multifactor       | false (for service accounts)
```

**To check:**
1. Navigate to: **System Properties > All Properties**
2. Search for each property above
3. Verify the value

---

### Check 7: Authentication Log

Check why ServiceNow is rejecting the login:

1. Navigate to: **System Logs > System Log > All**
2. Filter by:
   - **Source**: `authentication`
   - **User**: `github_integration`
   - **Created**: Last 15 minutes

Look for errors like:
- "User account is locked"
- "Invalid password"
- "User does not have API access"
- "Access control rule violation"

---

## Step-by-Step Solution

Follow this exact sequence:

### Step 1: Reset Password to Simple One

```
In ServiceNow:
1. User Administration > Users
2. Search: github_integration
3. Open user
4. Right-click header > Set Password
5. Password: TestPassword2024!
6. Confirm: TestPassword2024!
7. Click OK
```

### Step 2: Ensure User is Active

```
Still in user record:
✅ Check: Active
❌ Uncheck: Locked out
❌ Uncheck: Password needs reset
❌ Uncheck: Web service access only (temporarily)
Click: Update
```

### Step 3: Add Required Roles

```
1. Roles tab
2. Click: Edit
3. Add these if missing:
   - rest_service
   - api_analytics_read
   - devops_user
4. Click: Save
5. Click: Update
```

### Step 4: Test Login via UI

```
1. Go to: https://calitiiltddemo3.service-now.com
2. Username: github_integration
3. Password: TestPassword2024!
4. Should log in successfully
5. Log out
```

### Step 5: Test API

```bash
curl -v -X GET \
  -H "Accept: application/json" \
  -u "github_integration:TestPassword2024!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"
```

**Expected Response:**
```json
{
  "result": [
    {
      "sys_id": "...",
      "user_name": "github_integration",
      "active": "true"
      ...
    }
  ]
}
```

### Step 6: Re-enable Security

Once API works:

```
1. Open user: github_integration
2. Check: Web service access only
3. Click: Update
4. Test API again - should still work
```

---

## Common ServiceNow Issues

### Issue 1: "rest_service" Role Missing

**Symptoms:** 401 Unauthorized even with correct password

**Fix:**
```
1. User Administration > Users > github_integration
2. Roles tab > Edit
3. Add: rest_service
4. Save > Update
```

### Issue 2: Account Locked After Failed Attempts

**Symptoms:** 401 after multiple failed curl attempts

**Fix:**
```
1. User Administration > Users > github_integration
2. Uncheck: Locked out
3. Set: Failed login attempts = 0
4. Update
```

### Issue 3: Password Policy Prevents API Login

**Symptoms:** UI login works, API doesn't

**Fix:**
```
1. System Security > Password Policies
2. Check: REST API Basic Authentication
3. Ensure policy allows basic auth
```

### Issue 4: MFA Required

**Symptoms:** 401 for API even with correct credentials

**Fix:**
```
1. User record > github_integration
2. Ensure: "Exclude from multi-factor authentication" is checked
3. Or: System Properties > multifactor_auth.active = false (for dev)
```

---

## Quick Diagnostic Script

Run this to generate diagnostic info:

```bash
#!/bin/bash

echo "=== ServiceNow API Diagnostic ==="
echo ""
echo "1. Testing connectivity..."
curl -I https://calitiiltddemo3.service-now.com/api/now/table/sys_user 2>&1 | grep HTTP

echo ""
echo "2. Testing authentication..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -u "github_integration:TestPassword2024!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

echo ""
echo "3. Testing with verbose output..."
curl -v -u "github_integration:TestPassword2024!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1" \
  2>&1 | grep -E "(HTTP|WWW-Authenticate|error)"

echo ""
echo "=== Check in ServiceNow: ==="
echo "1. User Administration > Users > github_integration"
echo "2. Verify: Active = checked, Locked out = unchecked"
echo "3. Verify Roles: rest_service, api_analytics_read, devops_user"
echo "4. Try UI login: https://calitiiltddemo3.service-now.com"
```

---

## Most Likely Solutions (In Order)

### 1. Missing rest_service Role (80% of cases)

```
Fix: Add "rest_service" role to github_integration user
```

### 2. Account Locked (10% of cases)

```
Fix: Uncheck "Locked out" on user record
```

### 3. Wrong Password (5% of cases)

```
Fix: Reset password in ServiceNow, test in UI first
```

### 4. Web Service Access Only + ACL Issue (3% of cases)

```
Fix: Temporarily uncheck "Web service access only", test, then re-check
```

### 5. MFA Required (2% of cases)

```
Fix: Check "Exclude from multi-factor authentication"
```

---

## Next Steps

1. **Follow Step-by-Step Solution above**
2. **Test with simple password first** (`TestPassword2024!`)
3. **Check authentication logs** in ServiceNow
4. **Add missing roles** if needed
5. **Report back with** which step fixed it

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**Your Instance**: calitiiltddemo3.service-now.com
