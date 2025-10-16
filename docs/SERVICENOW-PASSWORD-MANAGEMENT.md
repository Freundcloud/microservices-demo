# ServiceNow Integration User Password Management

> **Quick Reference**: How to set, reset, and manage the `github_integration` user password

## Setting Password During User Creation

### Method 1: During Initial User Creation (Recommended)

**When creating the user in Task 1.3:**

1. Fill in all user details (User ID, Name, Email, etc.)
2. **Before clicking Submit**, scroll down to find the **Password** section
3. Look for a **Set Password** button or **Password** field
4. Click **Set Password**
5. Enter your password in both fields:
   - **New password**: Your strong password
   - **Confirm password**: Same password
6. Click **Submit** to create the user

**Note**: The password section location varies by ServiceNow version:
- **Modern UI**: Usually in a collapsible section labeled "Password"
- **Classic UI**: May be in the main form or a separate tab

---

## Setting Password After User Creation

### Method 2: Set Password After User Exists

If you already created the user without setting a password:

**Steps:**

1. Navigate to: **User Administration > Users**
2. Search for: `github_integration`
3. Open the user record
4. Right-click the **form header** (gray bar at top)
5. Select **Set Password** from the context menu
6. Enter your password:
   - **New password**: Your strong password
   - **Confirm password**: Same password
7. Click **Submit** or **OK**

**Alternative (if right-click doesn't work):**
1. With user record open, look for a **Set Password** button on the form
2. It may be under **Related Links** or in the form header
3. Click it and follow the password dialog

---

## Password Requirements

### ServiceNow Standard Requirements

Most ServiceNow instances require:

- ✅ **Minimum length**: 8-12 characters
- ✅ **Uppercase letters**: At least one (A-Z)
- ✅ **Lowercase letters**: At least one (a-z)
- ✅ **Numbers**: At least one (0-9)
- ✅ **Special characters**: At least one (!, @, #, $, %, ^, &, *)

### Check Your Instance Policy

To verify your specific requirements:
1. Navigate to: **System Security > Password Policies**
2. Look at the **Default Password Policy**
3. Check the requirements listed

---

## Creating a Strong Password

### Recommended Format

**Pattern**: `[Service][Purpose][Number][Special][Year][Special]`

**Examples:**
```
GitHubInt3gr@ti0n2024!
ServiceN0w-GitHub#2024
DevOps$GitHubApi2024!
SN_GitHubAct10n2024#
```

### Password Generator Command

**Linux/Mac:**
```bash
# Generate random password (20 characters, with special chars)
openssl rand -base64 20 | tr -d "=+/" | cut -c1-20

# Add your own special chars and numbers
echo "GitHub$(openssl rand -base64 8 | tr -d "=+/")@2024!"
```

**Online Tools:**
- Use a password manager's generator (1Password, LastPass, Bitwarden)
- Ensure it meets ServiceNow requirements

---

## Storing the Password Securely

### ✅ Recommended Methods

1. **Password Manager** (Best Practice)
   - 1Password
   - LastPass
   - Bitwarden
   - AWS Secrets Manager
   - HashiCorp Vault

2. **Encrypted Documentation**
   - Store in encrypted file
   - Use GPG encryption
   - Keep offline backup

3. **Team Secret Store**
   - Shared team vault
   - GitHub Secrets (for workflows only)
   - AWS Parameter Store

### ❌ DO NOT Store Here

- ❌ Plain text files
- ❌ Git repositories
- ❌ Slack/Teams messages
- ❌ Email
- ❌ Sticky notes
- ❌ Unencrypted documents

---

## Using the Password

### In GitHub Actions Workflows

The password needs to be added to GitHub Secrets:

**Setup:**
1. Go to: `https://github.com/your-org/your-repo/settings/secrets/actions`
2. Click: **New repository secret**
3. Name: `SERVICENOW_PASSWORD`
4. Value: Paste your password
5. Click: **Add secret**

**Usage in Workflows:**
```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v2
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-user-name: github_integration
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    tool-id: ${{ secrets.SERVICENOW_ORCHESTRATION_TOOL_ID }}
```

### For Basic Authentication

If using Basic Auth (username:password):

**Create Base64 String:**
```bash
# Format: username:password
echo -n "github_integration:YourPasswordHere" | base64

# Example output:
# Z2l0aHViX2ludGVncmF0aW9uOllvdXJQYXNzd29yZEhlcmU=
```

**Store in GitHub Secrets:**
- Name: `SERVICENOW_BASIC_AUTH`
- Value: The base64 string

---

## Resetting the Password

### When to Reset

- 🔄 Every 90 days (security best practice)
- 🚨 If password is compromised
- 🔒 After team member departure
- 📋 During security audits

### How to Reset

**Steps:**

1. Navigate to: **User Administration > Users**
2. Search for: `github_integration`
3. Open the user record
4. Right-click header > **Set Password**
5. Enter new password (twice)
6. Click **Submit**

**After Resetting:**
7. Update GitHub Secrets with new password
8. Update any other systems using this password
9. Update your password manager
10. Test GitHub Actions workflows

---

## Testing the Password

### Verify Password Works

**Method 1: ServiceNow REST API Test**
```bash
# Test with curl
curl -X GET \
  -H "Accept: application/json" \
  -u "github_integration:YourPasswordHere" \
  "https://your-instance.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# Should return: HTTP 200 OK with JSON response
```

**Method 2: ServiceNow UI Login (If not "Web service access only")**
- Go to: `https://your-instance.service-now.com`
- Login with: `github_integration` / password
- Should see: Login successful

**Method 3: GitHub Actions Test Workflow**
```yaml
name: Test ServiceNow Auth
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test ServiceNow Connection
        run: |
          curl -X GET \
            -H "Accept: application/json" \
            -u "github_integration:${{ secrets.SERVICENOW_PASSWORD }}" \
            "${{ secrets.SERVICENOW_INSTANCE_URL }}/api/now/table/sys_user?sysparm_limit=1"
```

---

## Troubleshooting

### Problem: "Set Password" option not available

**Solutions:**
1. Check if you have **admin** privileges
2. Try: **System Security > Users and Groups > Users**
3. Contact your ServiceNow administrator
4. User might be externally authenticated (SSO)

### Problem: Password doesn't meet requirements

**Solutions:**
1. Check: **System Security > Password Policies**
2. Make password longer (try 16+ characters)
3. Add more special characters
4. Ensure mix of upper/lower/numbers/symbols

### Problem: Password set but authentication fails

**Check:**
1. ✅ User is **Active**
2. ✅ User has **web_service_access_only** checked
3. ✅ User has required roles (devops_user, api_analytics_read)
4. ✅ Password has no extra spaces or newlines
5. ✅ Account is not locked (check user record)

### Problem: Can't remember password

**Solution:**
- Use "Set Password" to create a new one
- Update all systems using the password
- Store new password in password manager

---

## Security Best Practices

### ✅ DO

- ✅ Use a unique password (not reused elsewhere)
- ✅ Store in a password manager
- ✅ Use long passwords (16+ characters)
- ✅ Include mix of character types
- ✅ Rotate every 90 days
- ✅ Set "Web service access only" = Yes
- ✅ Use minimal required permissions
- ✅ Monitor API access logs
- ✅ Document password rotation schedule

### ❌ DON'T

- ❌ Share password via insecure channels
- ❌ Use weak passwords (e.g., "Password123!")
- ❌ Commit password to Git
- ❌ Reuse passwords from other systems
- ❌ Store in plain text
- ❌ Give user unnecessary permissions
- ❌ Forget to update GitHub Secrets after rotation

---

## Password Rotation Checklist

When rotating the password:

- [ ] Generate new strong password
- [ ] Set new password in ServiceNow user record
- [ ] Update GitHub Secrets: `SERVICENOW_PASSWORD`
- [ ] Update GitHub Secrets: `SERVICENOW_BASIC_AUTH` (if used)
- [ ] Update password manager
- [ ] Update documentation
- [ ] Test GitHub Actions workflows
- [ ] Notify team (if shared account)
- [ ] Schedule next rotation (90 days)

---

## Quick Reference

| Task | Location | Action |
|------|----------|--------|
| Set password (new user) | User form | Scroll to Password section > Set Password |
| Reset password (existing) | User record | Right-click header > Set Password |
| Check requirements | System Security | Password Policies > Default Password Policy |
| Store password | Password Manager | Create secure entry with metadata |
| Use in GitHub | Repository Settings | Secrets > Actions > New secret |
| Test password | Terminal/API | `curl -u username:password` |
| Rotate password | User record | Set Password > Update systems |

---

## Example: Complete Password Setup

**Step-by-step example for `github_integration` user:**

```bash
# 1. Generate strong password
PASSWORD="GitHubInt3gr@ti0n2024!"

# 2. Set in ServiceNow UI
# (Manual step - use ServiceNow form)

# 3. Store in password manager
# (Manual step - save to 1Password/LastPass)

# 4. Create base64 for Basic Auth (if needed)
echo -n "github_integration:GitHubInt3gr@ti0n2024!" | base64
# Output: Z2l0aHViX2ludGVncmF0aW9uOkdpdEh1YkludDNnckB0aTBuMjAyNCE=

# 5. Add to GitHub Secrets
# SERVICENOW_PASSWORD: GitHubInt3gr@ti0n2024!
# SERVICENOW_BASIC_AUTH: Z2l0aHViX2ludGVncmF0aW9uOkdpdEh1YkludDNnckB0aTBuMjAyNCE=

# 6. Test the password
curl -X GET \
  -H "Accept: application/json" \
  -u "github_integration:GitHubInt3gr@ti0n2024!" \
  "https://calitiiltddemo3.service-now.com/api/now/table/sys_user?sysparm_limit=1"

# 7. Schedule rotation
# Set reminder for 90 days from now
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**Related Docs**: [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) (Task 1.3)
