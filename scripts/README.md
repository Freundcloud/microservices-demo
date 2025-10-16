# Scripts Directory

This directory contains utility scripts for the microservices-demo project.

## ServiceNow Onboarding Script

### SN_onboarding_Github.sh

Automated setup script for configuring ServiceNow for GitHub Actions integration with EKS cluster discovery and CMDB population.

#### Features

- ✅ Creates GitHub integration user with secure password
- ✅ Assigns admin role to integration user
- ✅ Guides you through creating required CMDB tables
- ✅ Configures custom fields for EKS-specific data
- ✅ Sets up CMDB relationships
- ✅ Tests API access with all required tables
- ✅ Generates credentials file and setup summary
- ✅ Provides GitHub secrets configuration commands

#### Prerequisites

- ServiceNow instance (Zurich v6.1.0 or later)
- Admin user credentials
- `jq` installed: `sudo apt-get install jq` (Ubuntu/Debian) or `brew install jq` (macOS)
- `curl` installed (usually pre-installed)

#### Usage

```bash
# From the project root
cd scripts
./SN_onboarding_Github.sh
```

#### What It Does

1. **Prompts for Credentials**
   - ServiceNow instance URL
   - Admin username and password
   - Tests authentication

2. **Creates GitHub Integration User**
   - Username: `github_integration`
   - Generates secure random password
   - Assigns admin role
   - Saves credentials to `.github_sn_credentials`

3. **Guides Table Creation**
   - `u_eks_cluster` - Stores EKS cluster CIs
   - `u_microservice` - Stores microservice CIs
   - Adds custom fields to `cmdb_ci_server` for EKS nodes

4. **Verifies Setup**
   - Tests API access to all tables
   - Verifies CMDB relationship types
   - Confirms read/write permissions

5. **Generates Documentation**
   - `SERVICENOW_SETUP_SUMMARY.md` - Complete setup summary
   - `.github_sn_credentials` - Saved credentials (DO NOT COMMIT!)
   - GitHub secrets configuration commands

#### Output Files

- `.github_sn_credentials` - ServiceNow credentials (gitignored)
- `SERVICENOW_SETUP_SUMMARY.md` - Setup summary and next steps

#### Interactive Steps

The script will pause and prompt you to create tables manually via ServiceNow UI when:

1. **Creating u_eks_cluster table**
   - Navigate to System Definition > Tables > New
   - Follow on-screen instructions
   - Add 10 custom fields

2. **Creating u_microservice table**
   - Navigate to System Definition > Tables > New
   - Follow on-screen instructions
   - Add 8 custom fields

3. **Adding custom fields to cmdb_ci_server**
   - Navigate to System Definition > Tables
   - Search for "Server [cmdb_ci_server]"
   - Add 8 custom fields (optional, can skip)

#### Security Notes

- **Password Generation**: Uses `openssl rand` for secure password generation
- **Credentials Storage**: Saves to `.github_sn_credentials` with 600 permissions
- **Gitignore**: Credentials file is automatically ignored by git
- **Admin Role**: Integration user has full admin access (required for CMDB operations)

#### After Running the Script

1. **Add GitHub Secrets**
   ```bash
   # Using GitHub CLI
   gh secret set SERVICENOW_INSTANCE_URL --body "https://your-instance.service-now.com"
   gh secret set SERVICENOW_USERNAME --body "github_integration"
   gh secret set SERVICENOW_PASSWORD --body "generated-password"
   ```

   Or via GitHub UI:
   - Repository → Settings → Secrets and variables → Actions
   - New repository secret

2. **Run EKS Discovery Workflow**
   ```bash
   gh workflow run eks-discovery.yaml
   ```

3. **Verify in ServiceNow**
   - Navigate to u_eks_cluster_list.do
   - Navigate to u_microservice_list.do
   - Navigate to cmdb_ci_server_list.do
   - Filter servers by `cluster_name = microservices`

#### Troubleshooting

**Authentication Failed**
- Verify admin credentials
- Check ServiceNow instance URL (no trailing slash)
- Ensure admin user has full permissions

**Table Creation Failed**
- Follow manual table creation instructions
- Ensure you have table creation permissions
- Verify table extends `cmdb_ci`

**API Access Tests Failed**
- Check GitHub user has admin role
- Verify tables exist in ServiceNow
- Test API access manually with curl

**Custom Fields Not Created**
- Some ServiceNow instances require UI-based field creation
- Custom fields are optional for basic functionality
- Standard CMDB fields (cpu_count, ram, etc.) work without custom fields

#### Manual Table Creation

If you prefer to create tables manually before running the script:

**u_eks_cluster Table:**
1. System Definition > Tables > New
2. Label: `EKS Cluster`
3. Name: `u_eks_cluster`
4. Extends: `Configuration Item [cmdb_ci]`
5. Add fields: u_cluster_name, u_arn, u_version, u_endpoint, u_status, u_region, u_vpc_id, u_provider, u_last_discovered, u_discovered_by

**u_microservice Table:**
1. System Definition > Tables > New
2. Label: `Microservice`
3. Name: `u_microservice`
4. Extends: `Configuration Item [cmdb_ci]`
5. Add fields: u_name (mandatory), u_namespace (mandatory), u_cluster_name, u_image, u_replicas, u_ready_replicas, u_status, u_language

#### Support

For issues or questions:
- Check `docs/SERVICENOW-QUICK-START.md`
- Review `docs/SERVICENOW-ZURICH-COMPATIBILITY.md`
- Check `docs/SERVICENOW-SETUP-CHECKLIST.md`

#### Version History

- **1.0.0** (2025-10-16)
  - Initial release
  - Support for ServiceNow Zurich v6.1.0
  - Automated user creation and role assignment
  - Guided table creation
  - Comprehensive testing and validation
