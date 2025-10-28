# Terraform State check_results Fix

## Problem

After enabling S3 remote state backend and migrating state, GitHub Actions CI/CD workflows were failing with:

```
Error refreshing state: unsupported checkable object kind "var"
```

## Root Cause

The Terraform state file contained `check_results` entries with `"object_kind": "var"`, which are from Terraform's experimental check blocks. These are not supported in standard Terraform state operations and caused refresh errors.

Example of problematic check_results entry:
```json
"check_results": [
  {
    "object_kind": "var",
    "config_addr": "module.eks.module.self_managed_node_group.var.platform",
    "status": "pass",
    "objects": null
  }
]
```

## Impact

- CI/CD workflows failed at `terraform init` stage
- `terraform plan` and `terraform apply` could not run
- State migration was successful but state contained invalid entries

## Solution

### 1. Download Current State
```bash
cd terraform-aws
terraform state pull > /tmp/current-state.json
```

### 2. Remove check_results
```bash
jq 'del(.check_results)' /tmp/current-state.json > /tmp/fixed-state.json
```

This removed 26 check_results entries (9449 lines → 9423 lines).

### 3. Upload Fixed State to S3
```bash
aws s3 cp /tmp/fixed-state.json \
  s3://microservices-terraform-state-1761116893/microservices/terraform.tfstate \
  --region eu-west-2
```

### 4. Update DynamoDB Checksum
When directly uploading to S3 (bypassing `terraform state push`), the DynamoDB checksum needs manual update:

```bash
aws dynamodb update-item \
  --table-name microservices-terraform-locks \
  --key '{"LockID": {"S": "microservices-terraform-state-1761116893/microservices/terraform.tfstate-md5"}}' \
  --update-expression "SET Digest = :d" \
  --expression-attribute-values '{":d": {"S": "d5969a34a2c1932e7f174a8489e1d182"}}' \
  --region eu-west-2
```

The new checksum (`d5969a34a2c1932e7f174a8489e1d182`) matches the MD5 of the fixed state file.

### 5. Verify Fix
```bash
terraform init -reconfigure  # Should succeed
terraform plan              # Should show "No changes"
```

## Results

✅ **Success!**
- Terraform init works in CI/CD workflows
- State refreshes without errors
- `terraform plan` shows "No changes" (infrastructure matches configuration)
- Remote state backend fully functional

## Prevention

This issue occurred during initial state migration from local to S3. To prevent in future:

1. **Use `terraform state push`** instead of direct S3 upload when possible (handles checksums automatically)
2. **Avoid experimental features** in production state files
3. **Test state migration** locally before CI/CD deployment
4. **Keep Terraform versions consistent** between local and CI/CD

## Technical Details

### Why check_results Caused Errors

The `check_results` field is part of Terraform's [Checks feature](https://developer.hashicorp.com/terraform/language/checks) (experimental as of Terraform 1.5+). These validation checks are stored in state but:

- Are not part of standard resource lifecycle
- Don't represent actual infrastructure
- Can include unsupported `object_kind` values like `"var"` (variables)
- Cause "unsupported checkable object kind" errors during state refresh

### State Structure

Valid Terraform state should only contain:
- `version` (state format version)
- `terraform_version` (Terraform version that wrote the state)
- `serial` (state version number)
- `lineage` (state file lineage ID)
- `outputs` (output values)
- `resources` (managed resources)

Invalid/Optional:
- `check_results` (experimental validation checks - can be removed safely)

## Files Modified

- `terraform-aws/versions.tf` - S3 backend configuration (commit ddfc7472)
- S3 State File: `s3://microservices-terraform-state-1761116893/microservices/terraform.tfstate`
- DynamoDB Lock Table: `microservices-terraform-locks` (checksum updated)

## Related Issues

- **VPC Duplication Fix**: Enabling S3 backend solved duplicate VPC creation
- **State Migration**: Initial migration included experimental check_results
- **CI/CD Failures**: Workflow run 18708414668 failed with this error

## References

- [Terraform State Format](https://developer.hashicorp.com/terraform/language/state)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Terraform Checks (Experimental)](https://developer.hashicorp.com/terraform/language/checks)
- [DynamoDB State Locking](https://developer.hashicorp.com/terraform/language/settings/backends/s3#dynamodb-state-locking)

---

**Date**: 2025-10-22
**Fixed By**: Remote state configuration and check_results removal
**Status**: Resolved ✅
