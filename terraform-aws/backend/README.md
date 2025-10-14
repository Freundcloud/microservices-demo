# Terraform Backend Setup

This directory contains the Terraform configuration for creating the remote backend infrastructure (S3 bucket and DynamoDB table) to store Terraform state.

## Why Remote Backend?

**Without remote backend (current state):**
❌ State stored locally on your computer
❌ No state locking (risk of corruption)
❌ Can't collaborate with team
❌ Easy to lose state file
❌ Contains sensitive data in plain text on disk

**With remote backend (S3 + DynamoDB):**
✅ State stored securely in S3 with encryption
✅ State locking via DynamoDB (prevents concurrent modifications)
✅ Team collaboration (shared state)
✅ Versioning enabled (state history)
✅ Automatic backups

## Prerequisites

- AWS credentials configured (`aws configure` or `.envrc`)
- Terraform installed (>= 1.5.0)
- Permission to create S3 buckets and DynamoDB tables

## Setup Instructions

### Step 1: Configure Backend

```bash
cd terraform-aws/backend
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set a **globally unique** S3 bucket name:

```hcl
state_bucket_name = "calitti-microservices-terraform-state-x7y9z2"  # Change this!
```

**Important:** S3 bucket names must be globally unique across ALL AWS accounts worldwide. Use your organization name and a random suffix.

### Step 2: Create Backend Infrastructure

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create S3 bucket and DynamoDB table
terraform apply
```

This creates:
- **S3 Bucket**: For storing Terraform state with encryption and versioning
- **DynamoDB Table**: For state locking (prevents concurrent modifications)

### Step 3: Note the Output

After `terraform apply`, you'll see output like:

```
backend_config = <<-EOT
    Add this to your terraform-aws/versions.tf:

    terraform {
      backend "s3" {
        bucket         = "calitti-microservices-terraform-state-x7y9z2"
        key            = "microservices/terraform.tfstate"
        region         = "eu-west-2"
        dynamodb_table = "microservices-terraform-locks"
        encrypt        = true
      }
    }
EOT
```

### Step 4: Configure Main Terraform to Use Remote Backend

Add the backend configuration to `terraform-aws/versions.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"

  # Add this backend block
  backend "s3" {
    bucket         = "calitti-microservices-terraform-state-x7y9z2"  # From step 2 output
    key            = "microservices/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "microservices-terraform-locks"
    encrypt        = true
  }

  required_providers {
    # ... existing providers ...
  }
}
```

### Step 5: Migrate Existing State (if any)

If you already have local state from previous deployments:

```bash
cd terraform-aws

# Re-initialize with new backend
terraform init -migrate-state

# Terraform will prompt: "Do you want to copy existing state to the new backend?"
# Answer: yes
```

This safely migrates your local state to S3.

### Step 6: Verify Remote State

```bash
cd terraform-aws

# Check state is in S3
terraform state list

# View state file location
terraform show | head
```

## Backend Configuration

The backend infrastructure includes:

### S3 Bucket Features
- ✅ **Encryption**: AES256 server-side encryption
- ✅ **Versioning**: Keeps history of all state changes
- ✅ **Public Access Block**: No public access allowed
- ✅ **Lifecycle Policy**:
  - Delete old versions after 90 days
  - Abort incomplete uploads after 7 days

### DynamoDB Table Features
- ✅ **Billing**: Pay-per-request (only pay for actual usage)
- ✅ **Point-in-Time Recovery**: Enabled for data protection
- ✅ **Hash Key**: `LockID` for state locking

## Team Collaboration

Once the backend is configured, all team members can:

1. Pull the repository
2. Run `terraform init` (no migration needed)
3. Share the same state automatically
4. Terraform handles locking automatically

**No manual state sharing required!**

## State Locking

When someone runs `terraform apply`:
1. Terraform writes a lock to DynamoDB
2. Other users get error: "Error acquiring the state lock"
3. First user completes operation
4. Lock is released automatically
5. Other users can now proceed

This prevents state corruption from concurrent modifications.

## Backup and Recovery

### State Versions

S3 versioning keeps all previous versions of your state:

```bash
# List all state versions
aws s3api list-object-versions \
  --bucket calitti-microservices-terraform-state-x7y9z2 \
  --prefix microservices/terraform.tfstate
```

### Restore Previous Version

If needed, you can restore a previous state version:

```bash
# Download specific version
aws s3api get-object \
  --bucket calitti-microservices-terraform-state-x7y9z2 \
  --key microservices/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup
```

## Cost Estimate

Backend infrastructure costs (per month):

- **S3 Bucket**: ~$0.023 per GB + requests (typically < $1/month)
- **DynamoDB Table**: Pay-per-request (typically < $1/month)
- **Total**: ~$1-2 per month

Very cheap for the benefits!

## Security Best Practices

1. **IAM Permissions**: Restrict who can access state bucket
2. **Encryption**: State is encrypted at rest in S3
3. **Versioning**: Can't accidentally lose state
4. **No Secrets**: Avoid storing sensitive values in state (use AWS Secrets Manager instead)

## Troubleshooting

### "Bucket name already exists"

S3 bucket names must be globally unique. If you get this error:
- Change the `state_bucket_name` in `terraform.tfvars`
- Add a random suffix (e.g., `-x7y9z2`)

### "Error acquiring state lock"

Someone else is running Terraform. Either:
- Wait for them to finish
- Or if stuck, manually remove lock:

```bash
terraform force-unlock <LOCK_ID>
```

**⚠️ Only use `force-unlock` if you're certain no one else is running Terraform!**

### "Backend initialization required"

Run:
```bash
terraform init
```

## Destroying Backend (Only if needed)

**⚠️ WARNING: This deletes your state history!**

Only do this if you're completely done with the project:

```bash
cd terraform-aws/backend
terraform destroy
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `terraform init` | Initialize backend |
| `terraform plan` | Preview backend changes |
| `terraform apply` | Create backend infrastructure |
| `terraform output` | Show backend configuration |
| `terraform destroy` | Destroy backend (⚠️ deletes state history!) |

---

**Created**: 2025-10-14
**Purpose**: Remote state storage for microservices infrastructure
**Maintained By**: Infrastructure Team
