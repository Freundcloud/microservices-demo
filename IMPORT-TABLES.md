# Import ServiceNow Security Tables via XML (30 seconds!)

**Time Required**: 30 seconds
**Method**: XML Update Set Import

---

## ⚡ Super Fast Import Method

### Step 1: Download the XML File (5 seconds)

The XML file is already in your repo:
```
servicenow-security-tables-update-set.xml
```

### Step 2: Import into ServiceNow (25 seconds)

1. **Login to ServiceNow**:
   https://calitiiltddemo3.service-now.com

2. **Navigate to Update Sets**:
   - Search for: "Retrieved Update Sets"
   - Or go to: https://calitiiltddemo3.service-now.com/nav_to.do?uri=sys_remote_update_set_list.do

3. **Import XML**:
   - Click **"Import Update Set from XML"** button
   - Choose file: `servicenow-security-tables-update-set.xml`
   - Click **Upload**

4. **Preview the Update Set**:
   - Find the uploaded update set named "Security Scanning Tables"
   - Click on it
   - Click **"Preview Update Set"** button
   - Wait ~5 seconds for preview to complete

5. **Commit the Update Set**:
   - After preview completes, click **"Commit Update Set"** button
   - Wait ~5 seconds for commit to complete

**Done! Both tables with all 33 fields are now created!**

---

## ✅ Verify Tables Were Created

Run this command:

```bash
bash scripts/test-servicenow-connectivity.sh
```

Expected output:
```
[SUCCESS] ✓ u_security_scan_result table exists
[SUCCESS] ✓ u_security_scan_summary table exists
[SUCCESS] ✓ All security tables exist - READY FOR TESTING!
```

---

## 🚀 Re-Run the Workflow

```bash
gh workflow run security-scan-servicenow.yaml --repo Freundcloud/microservices-demo
```

Then monitor:
```bash
RUN_ID=$(gh run list --workflow=security-scan-servicenow.yaml --limit 1 --json databaseId --jq '.[0].databaseId' --repo Freundcloud/microservices-demo)
gh run watch $RUN_ID --repo Freundcloud/microservices-demo
```

---

## 📋 What Gets Created

The XML update set creates:

**Table 1: u_security_scan_result**
- 18 fields for individual security findings
- All mandatory fields configured
- Proper field types (String, Integer, DateTime, URL, Decimal)

**Table 2: u_security_scan_summary**
- 15 fields for scan summaries
- Severity counts (critical, high, medium, low, info)
- Tools run tracking

---

## 🔧 Troubleshooting

### Issue: "Import Update Set from XML" button not visible

**Solution**: You need admin or update set privileges. Use manual creation instead:
```bash
cat CREATE-TABLES-NOW.md
```

### Issue: Preview fails

**Cause**: Table names might conflict with existing tables

**Solution**: Delete existing tables first or use manual creation

### Issue: Commit fails

**Check**: Preview errors tab for details

**Solution**: Resolve conflicts or use manual creation

---

## 🎉 Success!

If import succeeds, you've just created both tables with all 33 fields in 30 seconds instead of 5 minutes of manual work!

Now proceed to trigger the workflow and watch the magic happen!
