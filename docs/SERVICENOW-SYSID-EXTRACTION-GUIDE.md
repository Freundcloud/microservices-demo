# ServiceNow sys_id Extraction Guide

> **Quick Reference**: How to extract the sys_id from your ServiceNow GitHub Tool URL

## What is the sys_id?

The `sys_id` is a unique identifier for your GitHub Tool configuration in ServiceNow. You need this value as your `SN_ORCHESTRATION_TOOL_ID` in GitHub Actions workflows.

---

## Method 1: Extract from URL (Modern ServiceNow)

### Your ServiceNow Version: Vancouver, Utah, or newer

**URL Format:**
```
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135
                                                                                  └─────────────┬─────────────┘
                                                                                               sys_id
```

**How to Extract:**

1. Open your GitHub Tool record in ServiceNow
2. Look at the URL in your browser's address bar
3. Find the last segment after `sn_devops_tool/`
4. Copy everything after the last `/`

**Example:**

| Full URL | Extracted sys_id |
|----------|------------------|
| `https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135` | `4eaebb06c320f690e1bbf0cb05013135` |

**Visual Breakdown:**
```
https://calitiiltddemo3.service-now.com/
       │
       └─ Your instance name

/now/devops-change/record/sn_devops_tool/
                                        │
                                        └─ Table name

4eaebb06c320f690e1bbf0cb05013135
└───────────────┬───────────────┘
           sys_id (THIS IS WHAT YOU NEED!)
```

---

## Method 2: Extract from URL (Older ServiceNow)

### Your ServiceNow Version: Rome, Tokyo, or older

**URL Format:**
```
https://your-instance.service-now.com/sn_devops_tool.do?sys_id=a1b2c3d4e5f6
                                                               └────┬────┘
                                                                  sys_id
```

**How to Extract:**

1. Open your GitHub Tool record in ServiceNow
2. Look at the URL in your browser's address bar
3. Find the `sys_id=` parameter
4. Copy the value after `sys_id=`

**Example:**

| Full URL | Extracted sys_id |
|----------|------------------|
| `https://dev123456.service-now.com/sn_devops_tool.do?sys_id=a1b2c3d4e5f6` | `a1b2c3d4e5f6` |

---

## Method 3: Right-Click Copy (All Versions)

**Works in all ServiceNow versions:**

1. Open your GitHub Tool record in ServiceNow
2. Right-click on the **form header** (the gray bar at the top)
3. Select **Copy sys_id** from the context menu
4. The sys_id is now in your clipboard

**Alternative:**
- Right-click header
- Select **Copy URL**
- Paste the URL and extract the sys_id using Method 1 or 2

---

## Method 4: From the Record (Manual)

If the sys_id field is visible on the form:

1. Open your GitHub Tool record
2. Scroll down to find the **sys_id** field
3. Copy the value directly

**Note:** This field may be hidden by default. You can add it via:
- Right-click header > **Configure** > **Form Layout**
- Add "sys_id" to the form

---

## Verification

Once you have your sys_id, verify it:

### Correct Format
- **Length**: Exactly 32 characters
- **Characters**: Only lowercase letters (a-f) and numbers (0-9)
- **Example**: `4eaebb06c320f690e1bbf0cb05013135` ✅

### Incorrect Formats
- Too short: `4eaebb06` ❌
- Has uppercase: `4EAEBB06c320f690e1bbf0cb05013135` ❌
- Has special chars: `4eaebb06-c320-f690-e1bb-f0cb05013135` ❌
- With equals sign: `sys_id=4eaebb06c320f690e1bbf0cb05013135` ❌

---

## Usage in GitHub Actions

Once you have your sys_id, add it to GitHub Secrets:

1. Go to: `https://github.com/your-org/your-repo/settings/secrets/actions`
2. Click: **New repository secret**
3. Name: `SERVICENOW_ORCHESTRATION_TOOL_ID`
4. Value: Paste your sys_id (e.g., `4eaebb06c320f690e1bbf0cb05013135`)
5. Click: **Add secret**

**Then use it in workflows:**

```yaml
- name: ServiceNow DevOps Change
  uses: ServiceNow/servicenow-devops-change@v2
  with:
    instance-url: ${{ secrets.SERVICENOW_INSTANCE_URL }}
    devops-integration-user-name: ${{ secrets.SERVICENOW_USERNAME }}
    devops-integration-user-password: ${{ secrets.SERVICENOW_PASSWORD }}
    tool-id: ${{ secrets.SERVICENOW_ORCHESTRATION_TOOL_ID }}  # ← Uses your sys_id
```

---

## Troubleshooting

### Problem: Can't find the sys_id in the URL

**Solution:**
- Try Method 3 (Right-click > Copy sys_id)
- Or Method 4 (Add sys_id field to form)

### Problem: URL looks completely different

**Solution:**
- Your ServiceNow instance might use a custom URL structure
- Use Method 3 or Method 4 instead
- Contact your ServiceNow administrator

### Problem: sys_id doesn't work in GitHub Actions

**Check:**
- [ ] sys_id is exactly 32 characters
- [ ] No extra spaces or newlines
- [ ] Not including `sys_id=` in the value
- [ ] Copied from correct record (GitHub Tool, not another record)

---

## Quick Reference Table

| ServiceNow Version | URL Pattern | sys_id Location |
|-------------------|-------------|-----------------|
| Vancouver/Utah+ | `/now/devops-change/record/sn_devops_tool/[sys_id]` | Last segment of URL |
| Rome/Tokyo | `/sn_devops_tool.do?sys_id=[sys_id]` | Query parameter value |
| All versions | Right-click header > Copy sys_id | Clipboard |
| All versions | sys_id field on form | Direct copy |

---

## Real Example (Your Instance)

Based on your URL:
```
https://calitiiltddemo3.service-now.com/now/devops-change/record/sn_devops_tool/4eaebb06c320f690e1bbf0cb05013135
```

**Your sys_id is:**
```
4eaebb06c320f690e1bbf0cb05013135
```

**To use in GitHub Actions:**

1. Add this secret: `SERVICENOW_ORCHESTRATION_TOOL_ID` = `4eaebb06c320f690e1bbf0cb05013135`
2. Reference it as: `${{ secrets.SERVICENOW_ORCHESTRATION_TOOL_ID }}`
3. ServiceNow will identify your GitHub Tool by this ID

---

**Document Version**: 1.0
**Last Updated**: 2025-10-16
**Need Help?** See [SERVICENOW-SETUP-CHECKLIST.md](SERVICENOW-SETUP-CHECKLIST.md) for complete setup instructions
