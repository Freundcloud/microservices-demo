# ServiceNow DevOps Integration Test

This file is used to trigger a test deployment to verify ServiceNow DevOps Change integration.

## Test Details

**Date**: 2025-10-22
**Test**: Verify change requests appear in ServiceNow DevOps Change workspace
**Changes Tested**:
- business_service field added to change request payload
- Services association completed
- DevOps application configured

## Expected Results

1. Change request should be created in ServiceNow
2. Change request should appear in DevOps Change workspace at:
   https://calitiiltddemo3.service-now.com/now/devops-change/changes/
3. Change should have all required fields:
   - `category`: "DevOps"
   - `devops_change`: true
   - `business_service`: 1e7b938bc360b2d0e1bbf0cb050131da
   - `u_tool_id`: 4c5e482cc3383214e1bbf0cb05013196
4. Security tools should be registered

## Verification Steps

After deployment completes:
1. Check GitHub Actions workflow logs for change request number (CHG#####)
2. Open ServiceNow DevOps Change workspace
3. Verify change request is visible
4. Check change request has all required fields
5. Verify services are associated
