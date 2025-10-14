# GitHub Actions Setup Guide

This guide explains how to configure GitHub Actions to automatically deploy the Online Boutique application to AWS EKS using Terraform.

## 🎯 Overview

The CI/CD pipeline consists of three workflows:

1. **Terraform Plan** (`.github/workflows/terraform-plan.yaml`)
   - Runs on Pull Requests
   - Shows infrastructure changes
   - Posts plan as PR comment

2. **Terraform Apply** (`.github/workflows/terraform-apply.yaml`)
   - Runs on merge to `main` branch
   - Deploys AWS infrastructure
   - Can be manually triggered

3. **Deploy Application** (`.github/workflows/deploy-application.yaml`)
   - Deploys microservices to EKS
   - Creates ingress for frontend
   - Can be manually triggered

---

## 🔐 Step 1: Configure GitHub Secrets

GitHub Secrets store your AWS credentials securely. They are encrypted and only exposed to workflows.

### Required Secrets

You need to add two secrets to your GitHub repository:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfi...` |

### How to Add Secrets

1. **Go to Repository Settings**
   - Navigate to your GitHub repository
   - Click **Settings** tab
   - Click **Secrets and variables** → **Actions** (left sidebar)

2. **Add AWS_ACCESS_KEY_ID**
   - Click **New repository secret**
   - Name: `AWS_ACCESS_KEY_ID`
   - Value: Your AWS Access Key ID (from AWS IAM)
   - Click **Add secret**

3. **Add AWS_SECRET_ACCESS_KEY**
   - Click **New repository secret**
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Value: Your AWS Secret Access Key (from AWS IAM)
   - Click **Add secret**

### Visual Guide

```
GitHub Repository
  ↓
Settings (top tab)
  ↓
Secrets and variables (left sidebar)
  ↓
Actions
  ↓
"New repository secret" button
  ↓
Name: AWS_ACCESS_KEY_ID
Value: AKIA...
  ↓
"Add secret"
```

---

## 🚀 Step 2: Configure GitHub Environment (Optional but Recommended)

Environments provide additional protection for production deployments.

### Create Production Environment

1. **Go to Repository Settings**
   - Click **Settings** → **Environments**
   - Click **New environment**
   - Name: `production`
   - Click **Configure environment**

2. **Add Protection Rules**
   - ✅ Enable **Required reviewers** (recommended)
     - Add team members who must approve deployments
   - ✅ Enable **Wait timer** (optional)
     - Add delay before deployment (e.g., 5 minutes)
   - Click **Save protection rules**

3. **Add Environment Secrets** (optional)
   - You can override repository secrets per environment
   - Click **Add secret** under environment
   - Useful for dev/staging/prod separation

---

## 📋 Step 3: Workflow Usage

### Automatic Deployment Flow

```
1. Create Pull Request with infrastructure changes
   ↓
2. GitHub Actions runs Terraform Plan
   ↓
3. Review plan in PR comments
   ↓
4. Merge PR to main branch
   ↓
5. GitHub Actions runs Terraform Apply
   ↓
6. Infrastructure deployed to AWS
   ↓
7. Application automatically deployed to EKS
```

### Manual Deployment

#### Deploy Infrastructure Manually

1. Go to **Actions** tab
2. Select **"Terraform Apply - AWS Infrastructure"**
3. Click **Run workflow**
4. Choose action: `apply` or `destroy`
5. Click **Run workflow**

#### Deploy Application Manually

1. Go to **Actions** tab
2. Select **"Deploy Application to EKS"**
3. Click **Run workflow**
4. Enter:
   - Cluster name: `online-boutique`
   - Namespace: `default`
5. Click **Run workflow**

---

## 🔍 Step 4: Verify Workflows

### Check Workflow Files

Ensure these files exist in your repository:

```bash
.github/workflows/
├── terraform-plan.yaml         # PR checks
├── terraform-apply.yaml        # Infrastructure deployment
└── deploy-application.yaml     # App deployment
```

### Test Terraform Plan

1. Create a new branch
   ```bash
   git checkout -b test-workflow
   ```

2. Make a small change to Terraform
   ```bash
   echo "# Test change" >> terraform-aws/variables.tf
   git add terraform-aws/variables.tf
   git commit -m "test: trigger workflow"
   git push origin test-workflow
   ```

3. Create Pull Request on GitHub

4. Check the **Actions** tab
   - You should see "Terraform Plan" running
   - Wait for completion
   - Check PR comments for Terraform plan output

---

## 📊 Step 5: Monitor Deployments

### View Workflow Runs

1. Go to **Actions** tab in your repository
2. Click on a workflow run to see details
3. View logs for each step
4. Check deployment summary

### View Deployment Status

Each workflow creates a summary with:
- ✅ Status of each step
- 📊 Resource counts
- 🔗 Application URLs
- 📝 Next steps

---

## 🛠️ Workflow Configuration

### Environment Variables

Each workflow uses these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `eu-west-2` | AWS region for deployment |
| `TF_VERSION` | `1.5.0` | Terraform version |
| `CLUSTER_NAME` | `online-boutique` | EKS cluster name |

### Modify Defaults

Edit the workflow file to change defaults:

```yaml
env:
  AWS_REGION: eu-west-1        # Change region
  CLUSTER_NAME: my-cluster     # Change cluster name
```

---

## 🔄 Workflow Triggers

### Terraform Plan

Triggers on:
- ✅ Pull requests to `main` branch
- ✅ Changes to `terraform-aws/**`
- ✅ Changes to workflow file

### Terraform Apply

Triggers on:
- ✅ Push to `main` branch
- ✅ Changes to `terraform-aws/**`
- ✅ Manual workflow dispatch

### Deploy Application

Triggers on:
- ✅ Push to `main` branch
- ✅ Changes to `src/**` or `kubernetes-manifests/**`
- ✅ Manual workflow dispatch
- ✅ Automatic trigger after Terraform Apply

---

## 🔒 Security Best Practices

### ✅ DO:

- ✅ Use GitHub Secrets for credentials
- ✅ Enable environment protection rules
- ✅ Require PR reviews before merge
- ✅ Use least privilege IAM policies
- ✅ Rotate AWS access keys regularly
- ✅ Enable branch protection on `main`
- ✅ Review Terraform plans before applying

### ❌ DON'T:

- ❌ Commit credentials to repository
- ❌ Use root AWS account credentials
- ❌ Disable security checks
- ❌ Skip Terraform plan review
- ❌ Give overly broad IAM permissions

---

## 🎯 Complete Setup Checklist

- [ ] AWS IAM user created with appropriate permissions
- [ ] AWS access keys generated
- [ ] GitHub Secrets configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- [ ] GitHub Environment created (optional: `production`)
- [ ] Branch protection enabled on `main` (optional)
- [ ] Workflow files present in `.github/workflows/`
- [ ] Test PR created to verify Terraform Plan
- [ ] Infrastructure deployed successfully
- [ ] Application deployed successfully
- [ ] Application accessible via ALB URL

---

## 📖 Example Deployment Scenario

### Scenario: Deploy Infrastructure and Application

1. **Fork/Clone Repository**
   ```bash
   git clone <your-repo-url>
   cd microservices-demo
   ```

2. **Configure GitHub Secrets** (as described above)

3. **Create Feature Branch**
   ```bash
   git checkout -b feature/deploy-to-aws
   ```

4. **Customize Terraform Variables** (optional)
   ```bash
   cd terraform-aws
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed
   ```

5. **Commit and Push**
   ```bash
   git add .
   git commit -m "feat: configure AWS deployment"
   git push origin feature/deploy-to-aws
   ```

6. **Create Pull Request**
   - GitHub Actions runs Terraform Plan
   - Review plan output in PR comments
   - Request review from team

7. **Merge to Main**
   - Merge PR
   - GitHub Actions runs Terraform Apply
   - Infrastructure deployed to AWS
   - Application automatically deployed

8. **Access Application**
   - Check Actions tab for ALB URL
   - Wait 5-10 minutes for ALB provisioning
   - Access application in browser

---

## 🆘 Troubleshooting

### Workflow Not Running

**Problem**: Workflow doesn't trigger on PR/push

**Solutions**:
- Check workflow path: `.github/workflows/*.yaml`
- Verify `paths` filter matches changed files
- Check branch name matches trigger (`main`)

### AWS Credentials Invalid

**Problem**: "Unable to locate credentials" or "Access Denied"

**Solutions**:
- Verify GitHub Secrets are set correctly
- Check IAM user has required permissions
- Ensure access keys are active in AWS
- Try regenerating access keys

### Terraform State Lock

**Problem**: "Error acquiring the state lock"

**Solutions**:
- Wait for previous workflow to complete
- Manually unlock state in AWS (if stuck)
- Check S3 backend configuration

### EKS Access Denied

**Problem**: "error: You must be logged in to the server"

**Solutions**:
- Verify AWS credentials have EKS permissions
- Check cluster name is correct
- Ensure region matches cluster location

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## 🚀 Next Steps

Once workflows are configured:

1. **Test the Pipeline**: Create a test PR and verify Terraform Plan works
2. **Deploy Infrastructure**: Merge to main or manually trigger Terraform Apply
3. **Deploy Application**: Application deploys automatically or trigger manually
4. **Monitor**: Check CloudWatch Logs and EKS Console
5. **Configure ServiceNow**: See [SERVICENOW.md](SERVICENOW.md) for integration

---

**Ready to deploy?** Make sure GitHub Secrets are configured, then create your first PR!
