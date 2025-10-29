# ServiceNow Work Items - Where to Find Them

**Quick Reference**: How to find and view GitHub-linked work items in ServiceNow

---

## 📍 Direct URLs

### View All Work Items
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do
```

### Filter by Source (GitHub only)
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=source=GitHub
```

### Filter by Change Request
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=change_request.number=CHG0030277
```
*Replace CHG0030277 with your change request number*

### Filter by External ID (GitHub Issue Number)
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=external_id=42^source=GitHub
```
*Replace 42 with your GitHub issue number*

---

## 🔍 Navigation in ServiceNow UI

### Method 1: Application Navigator (Recommended)

1. Log into ServiceNow: https://calitiiltddemo3.service-now.com
2. Click **"All"** (Application Navigator) in top-left
3. Type **"DevOps"** in the search box
4. Expand **"DevOps"** section
5. Click **"Work Items"**

### Method 2: Direct Table Access

1. Log into ServiceNow
2. In the filter navigator, type: **sn_devops_work_item.list**
3. Press Enter
4. View all work items table

### Method 3: From Change Request

1. Open a Change Request (e.g., CHG0030277)
2. Scroll down to **"Related Lists"** tab
3. Look for **"Work Items"** section
4. See all work items linked to this change request

---

## 📊 Work Items Table Columns

| Column | Description | Example |
|--------|-------------|---------|
| **Number** | ServiceNow work item number | WI0001050 |
| **Title** | GitHub issue title | "Implement work items integration" |
| **Type** | Issue/Story/Defect/Task | Issue |
| **State** | Open/Closed | Open |
| **Source** | Source system | GitHub |
| **External ID** | GitHub issue number | 42 |
| **URL** | Link to GitHub issue | https://github.com/.../issues/42 |
| **Change Request** | Linked CR number | CHG0030277 |
| **Priority** | 1-4 (Critical to Low) | 3 |
| **Description** | Full issue details | Issue body + metadata |

---

## 🔎 Search & Filter Examples

### Find Work Items for Specific GitHub Issue

**UI Filter**:
1. Go to Work Items list
2. Click filter icon
3. Filter: `External ID` = `42` AND `Source` = `GitHub`

**URL**:
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=external_id=42^source=GitHub
```

### Find All Open Work Items from GitHub

**URL**:
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=state=Open^source=GitHub
```

### Find Work Items NOT Linked to Change Requests

**URL**:
```
https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=change_requestISEMPTY^source=GitHub
```

---

## 🧪 Verify Work Item Creation

### Check via API (Using Script)

```bash
# Use the verification script
/tmp/check-servicenow-work-items.sh
```

### Check Manually

1. **Get Change Request Number** from workflow logs:
   ```bash
   gh run view {RUN_ID} --repo Freundcloud/microservices-demo --json jobs
   ```
   Look for "Create Change Request" job output

2. **Navigate to Work Items** filtered by that CR:
   ```
   https://calitiiltddemo3.service-now.com/sn_devops_work_item_list.do?sysparm_query=change_request.number=CHG0030XXX
   ```

3. **Verify Fields**:
   - External ID should match GitHub issue number
   - URL should link to GitHub issue
   - Title should match GitHub issue title
   - Source should be "GitHub"

---

## 📋 Expected Work Items

### From Our Deployment

**GitHub Issue #42**: "Implement GitHub Issues to ServiceNow Work Items Integration"

**Expected Work Item**:
- **Number**: WI000XXXX (auto-assigned)
- **Title**: "Implement GitHub Issues to ServiceNow Work Items Integration"
- **Type**: Issue (or Story if labeled)
- **State**: Open
- **Source**: GitHub
- **External ID**: 42
- **URL**: https://github.com/Freundcloud/microservices-demo/issues/42
- **Change Request**: CHG0030XXX (from latest deployment)
- **Priority**: 3 (Moderate) or based on labels

---

## ❓ Troubleshooting

### "No work items found"

**Possible Reasons**:
1. Workflow hasn't run yet (register-work-items job)
2. No GitHub issues referenced in commit messages
3. Job was skipped (check if conditions in MASTER-PIPELINE)

**Check**:
```bash
# View latest workflow run
gh run list --repo Freundcloud/microservices-demo --limit 1

# Check register-work-items job
gh run view {RUN_ID} --repo Freundcloud/microservices-demo
```

Look for: **📋 Register Work Items** job

### "Work items exist but not linked to change request"

**Possible Reasons**:
1. Change request sys_id lookup failed
2. Insufficient permissions

**Check workflow logs**:
```bash
gh run view {RUN_ID} --repo Freundcloud/microservices-demo --log
```

Look for: "Could not find change request"

### "Wrong work item type or priority"

**Reason**: GitHub issue labels weren't mapped correctly

**Solution**: Add appropriate labels to GitHub issue:
- Type: `story`, `feature`, `bug`, `task`
- Priority: `critical`, `urgent`, `high`, `low`

---

## 🎯 Quick Commands

### Check if work item exists for Issue #42
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item?sysparm_query=external_id=42^source=GitHub" \
  | jq '.result[] | {number, title, state, change_request}'
```

### List all GitHub work items
```bash
curl -s -u "$SERVICENOW_USERNAME:$SERVICENOW_PASSWORD" \
  "$SERVICENOW_INSTANCE_URL/api/now/table/sn_devops_work_item?sysparm_query=source=GitHub&sysparm_limit=10" \
  | jq '.result[] | {number, external_id, title, state}'
```

---

## 📚 Related Documentation

- [Work Items Integration Guide](./implemented/SERVICENOW-WORK-ITEMS-INTEGRATION.md)
- [GitHub Issue #42](https://github.com/Freundcloud/microservices-demo/issues/42)
- ServiceNow DevOps Plugin: https://docs.servicenow.com/bundle/latest/page/product/devops/concept/work-item-tracking.html

---

**Last Updated**: 2025-10-29
**ServiceNow Instance**: https://calitiiltddemo3.service-now.com
