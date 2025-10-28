# AWS Setup Guide

This guide will help you configure AWS credentials to deploy the Online Boutique application on AWS EKS.

## 🚀 Quick Start

### 1. Set Up AWS Credentials

Copy the example environment file and add your credentials:

```bash
cp .envrc.example .envrc
```

Edit `.envrc` with your AWS credentials:

```bash
nano .envrc
# or
vim .envrc
# or
code .envrc
```

Replace the placeholder values:
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_DEFAULT_REGION`: Your preferred region (e.g., `eu-west-2`)

### 2. Load Environment Variables

**Option A: Manual Loading**
```bash
source .envrc
```

**Option B: Using direnv (Recommended)**

Install direnv for automatic credential loading:

```bash
# On NixOS (you're already using it!)
nix-env -iA nixpkgs.direnv

# On macOS
brew install direnv

# On Ubuntu/Debian
sudo apt install direnv

# Add to your shell (~/.bashrc or ~/.zshrc)
eval "$(direnv hook bash)"   # for bash
eval "$(direnv hook zsh)"    # for zsh

# Allow direnv for this directory
direnv allow
```

Now credentials will automatically load when you `cd` into this directory!

### 3. Verify AWS Configuration

Test your AWS credentials:

```bash
# Show your AWS identity
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

Test AWS access:

```bash
# List S3 buckets (if you have any)
aws s3 ls

# List EKS clusters (if you have any)
aws eks list-clusters --region eu-west-2

# Check your default region
echo $AWS_DEFAULT_REGION
```

## 📋 How to Get AWS Credentials

### If You DON'T Have an AWS Account

1. **Create AWS Account**: https://aws.amazon.com/free
2. **Sign up** for AWS Free Tier (includes 12 months of free services)
3. **Verify email** and **add payment method** (required but won't be charged for free tier usage)

### If You HAVE an AWS Account

1. **Sign in to AWS Console**: https://console.aws.amazon.com/

2. **Navigate to IAM**:
   - Search for "IAM" in the top search bar
   - Click **Identity and Access Management**

3. **Create or Select IAM User**:
   - Go to **Users** (left sidebar)
   - Click existing user OR **"Create user"** for new one
   - For new user: Enter username (e.g., `terraform-admin`)

4. **Set Permissions**:
   - Click **"Attach policies directly"**
   - Select **`AdministratorAccess`** (for demo/testing)
   - OR select specific policies: `AmazonEKSClusterPolicy`, `AmazonVPCFullAccess`, etc.
   - Click **"Next"** → **"Create user"**

5. **Create Access Key**:
   - Click on the user
   - Go to **"Security credentials"** tab
   - Scroll to **"Access keys"**
   - Click **"Create access key"**
   - Select **"Command Line Interface (CLI)"**
   - Check the confirmation box
   - Click **"Next"** → **"Create access key"**

6. **Save Credentials** 🔐:
   - **Access Key ID**: `AKIA...`
   - **Secret Access Key**: `wJal...`
   - **⚠️ IMPORTANT**: Download CSV or copy now - you can't see the secret again!

7. **Add to `.envrc`**:
   ```bash
   export AWS_ACCESS_KEY_ID="AKIA_YOUR_KEY_HERE"
   export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY_HERE"
   export AWS_DEFAULT_REGION="eu-west-2"
   ```

## 🔐 Security Best Practices

### ✅ DO:
- ✅ Use IAM users, not root account
- ✅ Enable MFA (Multi-Factor Authentication)
- ✅ Use `.envrc` for local credentials (already in `.gitignore`)
- ✅ Rotate access keys regularly (every 90 days)
- ✅ Use AWS Secrets Manager for production
- ✅ Grant minimum required permissions

### ❌ DON'T:
- ❌ Commit `.envrc` to Git (already excluded)
- ❌ Share credentials in chat, email, or Slack
- ❌ Use root account credentials
- ❌ Give `AdministratorAccess` in production
- ❌ Hardcode credentials in code

## 🎯 Next Steps

Once credentials are configured:

1. **Test Terraform**:
   ```bash
   cd terraform-aws
   terraform init
   terraform plan
   ```

2. **Deploy Infrastructure**:
   ```bash
   terraform apply
   ```

3. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region eu-west-2 --name online-boutique
   ```

4. **Deploy Application**:
   ```bash
   kubectl apply -f ../release/kubernetes-manifests.yaml
   ```

## 🛠️ Troubleshooting

### "Unable to locate credentials"

```bash
# Check if environment variables are set
env | grep AWS

# Re-source the file
source .envrc

# Verify credentials
aws sts get-caller-identity
```

### "Access Denied" Errors

- Check IAM user has required permissions
- Verify credentials are correct
- Ensure region is correct

### "Region not found"

```bash
# Set region explicitly
export AWS_DEFAULT_REGION="eu-west-2"

# Or in AWS CLI command
aws eks list-clusters --region eu-west-2
```

## 📚 Additional Resources

- [AWS Free Tier](https://aws.amazon.com/free/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [direnv Documentation](https://direnv.net/)

## 💰 Cost Estimation

Using this demo will incur AWS costs:

| Service | Estimated Cost |
|---------|----------------|
| EKS Control Plane | ~$72/month |
| EC2 Instances (3x t3.medium) | ~$90/month |
| NAT Gateway | ~$32/month |
| ElastiCache (cache.t3.micro) | ~$15/month |
| Load Balancer | ~$20/month |
| **Total** | **~$229/month** |

💡 **Tip**: Remember to destroy resources when done testing:
```bash
cd terraform-aws
terraform destroy
```

## 🆘 Need Help?

- Check [terraform-aws/README.md](terraform-aws/README.md) for Terraform-specific help
- Review AWS CloudWatch logs for errors
- Check Terraform state: `terraform show`

---

**Ready?** Once credentials are configured, proceed to [terraform-aws/README.md](terraform-aws/README.md) for deployment instructions!
