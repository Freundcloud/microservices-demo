# Terraform Backend Quick Guide

## TL;DR

**Current State**: State stored locally (on your laptop)
**Recommended**: Use S3 backend for team collaboration

## Do I Need Remote Backend?

| Scenario | Local State | Remote Backend |
|----------|-------------|----------------|
| **Solo developer** | ✅ OK | ⚡ Better |
| **Small team** | ⚠️ Risky | ✅ Recommended |
| **Production** | ❌ Don't | ✅ Required |

## Quick Start (No Backend - Current)

```bash
# Works out of the box
just tf-init
just tf-plan
just tf-apply
```

State stored in: `terraform-aws/terraform.tfstate` (on your laptop)

## Quick Start (With S3 Backend)

### One-Time Setup (15 minutes)

```bash
# 1. Configure backend
cd terraform-aws/backend
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Set unique bucket name

# 2. Create backend infrastructure
just backend-setup

# 3. Copy the backend config from output
# Example output:
#   bucket         = "calitti-microservices-terraform-state-x7y9z2"
#   key            = "microservices/terraform.tfstate"
#   region         = "eu-west-2"
#   dynamodb_table = "microservices-terraform-locks"

# 4. Edit terraform-aws/versions.tf
# Uncomment lines 22-28 and paste your bucket name

# 5. Initialize with backend
cd ..
just tf-init
# Terraform asks: "Do you want to copy existing state to the new backend?"
# Answer: yes
```

### Normal Workflow (After Setup)

```bash
# Exactly the same as before!
just tf-init   # Uses S3 backend automatically
just tf-plan
just tf-apply
```

State stored in: S3 bucket (shared with team)

## What Changes?

**Short answer**: Almost nothing!

| Command | Without Backend | With Backend | Change? |
|---------|----------------|--------------|---------|
| `just tf-init` | ✅ Works | ✅ Works | ❌ No change |
| `just tf-plan` | ✅ Works | ✅ Works | ❌ No change |
| `just tf-apply` | ✅ Works | ✅ Works | ❌ No change |
| `just tf-destroy` | ✅ Works | ✅ Works | ❌ No change |

**The only difference**: State is stored in S3 instead of locally.

## Team Workflow

### Person 1 (First Time Setup)

```bash
# Setup backend (only once)
just backend-setup

# Share bucket name with team
# Example: "calitti-microservices-terraform-state-x7y9z2"

# Update versions.tf, commit, and push
git add terraform-aws/versions.tf
git commit -m "Configure S3 backend"
git push
```

### Person 2, 3, 4... (Team Members)

```bash
# Pull the updated code
git pull

# Initialize (uses S3 automatically)
just tf-init

# Work normally
just tf-plan
just tf-apply
```

**That's it!** State is automatically shared.

## Common Questions

### Q: Can I still use local state?

**A:** Yes! Just don't run `just backend-setup` and don't uncomment the backend block in `versions.tf`. Everything works as before.

### Q: What if two people run `terraform apply` at the same time?

**A:**
- **Without backend**: ❌ State corruption (bad!)
- **With backend**: ✅ Second person gets error "state locked" (good!)

### Q: Can I switch back to local state?

**A:** Yes, but not recommended. Run:

```bash
cd terraform-aws
terraform init -migrate-state
# Answer: yes to migrate state back to local
```

Then comment out the backend block in `versions.tf`.

### Q: How much does S3 backend cost?

**A:** ~$1-2/month (S3 storage + DynamoDB requests)

### Q: What if I lose my laptop with local state?

**A:**
- **Without backend**: ❌ State is gone, infrastructure orphaned
- **With backend**: ✅ State is in S3, just run `git clone` and `tf-init`

### Q: Do I need to change my workflow?

**A:** No! Commands stay exactly the same:
- `just tf-init`
- `just tf-plan`
- `just tf-apply`
- `just tf-destroy`

## Migration Steps (If You Have Existing Infrastructure)

If you already deployed infrastructure and want to add backend:

```bash
# 1. Setup backend
just backend-setup

# 2. Update versions.tf (uncomment backend block)

# 3. Migrate state
just tf-init
# Terraform: "Do you want to copy existing state to the new backend?"
# Answer: yes

# 4. Verify
terraform state list
# Should see all your existing resources
```

Your infrastructure is **not affected** - only the state file location changes.

## Troubleshooting

### "Backend initialization required"

```bash
just tf-init
```

### "Error: Backend configuration changed"

```bash
just tf-init -reconfigure
```

### "Error acquiring the state lock"

Someone else is running Terraform. Either:
- Wait for them to finish
- Or if stuck (crashed): `terraform force-unlock <LOCK_ID>`

### "Bucket name already exists"

S3 bucket names are globally unique. Change the name in `terraform-aws/backend/terraform.tfvars`:

```hcl
state_bucket_name = "your-org-microservices-terraform-state-abc123"
                                                          ↑↑↑↑↑↑
                                                      Add random suffix
```

## Recommendations

| Situation | Recommendation |
|-----------|----------------|
| **Learning/Testing** | Local state is fine |
| **Solo project** | S3 backend is safer (backup) |
| **Team (2+ people)** | S3 backend required |
| **Production** | S3 backend mandatory |
| **Shared single cluster** | **S3 backend highly recommended** ⭐ |

Since you have a **single shared cluster** for all environments, remote backend is **highly recommended** to prevent state conflicts.

## Complete Setup Guide

For detailed instructions, see: [terraform-aws/backend/README.md](../terraform-aws/backend/README.md)

## Quick Commands Reference

```bash
# Backend management
just backend-setup       # Create S3 + DynamoDB backend
just backend-info        # Show backend configuration
just backend-destroy     # Destroy backend (⚠️ deletes history)

# Normal Terraform workflow (works with or without backend)
just tf-init            # Initialize (uses backend if configured)
just tf-plan            # Plan changes
just tf-apply           # Apply changes
just tf-destroy         # Destroy infrastructure
```

---

**Created**: 2025-10-14
**Purpose**: Explain Terraform backend setup and workflow
