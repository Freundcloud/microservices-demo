# ServiceNow Integration Project Plan

> **Project**: GitHub Actions + AWS EKS + ServiceNow DevOps Integration
> **Created**: 2025-10-15
> **Status**: Planning

## Executive Summary

This project plan outlines the integration of GitHub Actions with ServiceNow DevOps to enable:
- Automated change management with environment-specific approvals
- Security scan result tracking in ServiceNow
- AWS EKS cluster and service discovery in ServiceNow CMDB
- End-to-end deployment pipeline with approval gates

## Table of Contents

1. [Project Objectives](#project-objectives)
2. [Architecture Overview](#architecture-overview)
3. [Implementation Phases](#implementation-phases)
4. [Prerequisites](#prerequisites)
5. [Detailed Implementation Steps](#detailed-implementation-steps)
6. [Security Considerations](#security-considerations)
7. [Testing Strategy](#testing-strategy)
8. [Rollout Plan](#rollout-plan)
9. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Project Objectives

### Primary Goals

1. **Automated Change Management**
   - Auto-approve deployments to `dev` environment
   - Require manual approval for `qa` deployments via ServiceNow
   - Require strict approval for `prod` deployments via ServiceNow
   - Track all deployment changes in ServiceNow Change Management

2. **Security Integration**
   - Send security scan results to ServiceNow (Trivy, CodeQL, Checkov, Gitleaks, Semgrep)
   - Create security vulnerabilities in ServiceNow Vulnerability Response
   - Block deployments if critical vulnerabilities detected
   - Track remediation status

3. **AWS Infrastructure Discovery**
   - Register EKS cluster information in ServiceNow CMDB
   - Discover and track all 12 microservices
   - Monitor infrastructure changes
   - Link deployments to CMDB items

4. **Full CI/CD Integration**
   - Seamless GitHub Actions to ServiceNow communication
   - Deployment tracking and audit trail
   - Rollback capabilities via ServiceNow
   - Incident management integration

### Success Metrics

- 100% of deployments tracked in ServiceNow
- <5 minute approval time for dev deployments (auto)
- Security scan results visible in ServiceNow within 10 minutes
- CMDB accuracy >95% for EKS resources
- Zero failed deployments due to integration issues

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions                           │
│                                                                   │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐│
│  │   Build    │→ │  Security  │→ │   Change   │→ │   Deploy   ││
│  │            │  │   Scan     │  │  Request   │  │            ││
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘│
│         │              │               │               │         │
└─────────┼──────────────┼───────────────┼───────────────┼─────────┘
          │              │               │               │
          ▼              ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ServiceNow Platform                         │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   DevOps     │  │ Vulnerability│  │    Change    │          │
│  │   Security   │  │   Response   │  │  Management  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                  │                 │                   │
│         └──────────────────┴─────────────────┘                   │
│                            │                                      │
│                   ┌────────▼────────┐                           │
│                   │      CMDB       │                           │
│                   │  (EKS Cluster)  │                           │
│                   └─────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
          ▲
          │
┌─────────┴─────────┐
│    AWS EKS        │
│  ┌─────────────┐  │
│  │ Microservices│ │
│  │ (12 services)│ │
│  └─────────────┘  │
└───────────────────┘
```

## Implementation Phases

### Phase 1: ServiceNow Setup (Week 1)
**Duration**: 3-5 days
**Prerequisites**: ServiceNow instance access

- [ ] 1.1 Install ServiceNow DevOps plugin
- [ ] 1.2 Configure GitHub integration in ServiceNow
- [ ] 1.3 Create service accounts and API tokens
- [ ] 1.4 Configure Change Management templates
- [ ] 1.5 Set up approval workflows for dev/qa/prod
- [ ] 1.6 Configure security tool mappings
- [ ] 1.7 Create CMDB CI classes for EKS resources

### Phase 2: GitHub Actions Integration - Security Scans (Week 1-2)
**Duration**: 3-5 days
**Prerequisites**: Phase 1 complete

- [ ] 2.1 Add ServiceNow credentials to GitHub Secrets
- [ ] 2.2 Update security-scan.yaml workflow
- [ ] 2.3 Integrate Trivy scan results
- [ ] 2.4 Integrate CodeQL scan results
- [ ] 2.5 Integrate Checkov scan results
- [ ] 2.6 Integrate Gitleaks scan results
- [ ] 2.7 Integrate Semgrep scan results
- [ ] 2.8 Test security result submission
- [ ] 2.9 Configure security gates

### Phase 3: Change Management Integration (Week 2)
**Duration**: 5-7 days
**Prerequisites**: Phase 1 complete

- [ ] 3.1 Update terraform-apply.yaml for change automation
- [ ] 3.2 Implement dev environment auto-approval
- [ ] 3.3 Implement qa environment manual approval
- [ ] 3.4 Implement prod environment strict approval
- [ ] 3.5 Configure change request templates
- [ ] 3.6 Add deployment verification steps
- [ ] 3.7 Implement rollback workflows
- [ ] 3.8 Test change approval flows

### Phase 4: AWS EKS Discovery (Week 3)
**Duration**: 5-7 days
**Prerequisites**: Phase 1 complete

- [ ] 4.1 Install ServiceNow AWS Service Management Connector
- [ ] 4.2 Configure AWS credentials in ServiceNow
- [ ] 4.3 Set up EKS cluster discovery
- [ ] 4.4 Create microservices inventory script
- [ ] 4.5 Schedule periodic discovery jobs
- [ ] 4.6 Map EKS resources to CMDB
- [ ] 4.7 Configure relationship mapping
- [ ] 4.8 Validate CMDB accuracy

### Phase 5: Full CI/CD Pipeline Integration (Week 3-4)
**Duration**: 5-7 days
**Prerequisites**: Phases 2, 3, 4 complete

- [ ] 5.1 Create unified deployment workflow
- [ ] 5.2 Integrate all components (security, change, deploy)
- [ ] 5.3 Add deployment tracking
- [ ] 5.4 Implement incident management hooks
- [ ] 5.5 Configure monitoring and alerts
- [ ] 5.6 Create deployment dashboards
- [ ] 5.7 Document deployment procedures
- [ ] 5.8 Train team on new workflows

### Phase 6: Testing and Validation (Week 4)
**Duration**: 3-5 days
**Prerequisites**: Phase 5 complete

- [ ] 6.1 End-to-end testing in dev environment
- [ ] 6.2 Security scan validation
- [ ] 6.3 Change approval testing
- [ ] 6.4 CMDB accuracy validation
- [ ] 6.5 Rollback procedure testing
- [ ] 6.6 Performance testing
- [ ] 6.7 Documentation review
- [ ] 6.8 Team training sessions

## Prerequisites

### ServiceNow Requirements

1. **ServiceNow Instance**
   - ServiceNow version: San Diego or later
   - DevOps plugin installed
   - License for DevOps Change, Security, and CMDB modules

2. **ServiceNow Permissions**
   - Admin access to configure integrations
   - Ability to create service accounts
   - API token generation permissions

3. **ServiceNow Configuration**
   - Change Management module enabled
   - Vulnerability Response module enabled
   - CMDB module configured
   - Approval workflows defined

### GitHub Requirements

1. **Repository Access**
   - Admin access to repository settings
   - Ability to create GitHub Secrets
   - Workflow modification permissions

2. **GitHub Secrets Required**
   ```
   SN_DEVOPS_INTEGRATION_TOKEN
   SN_INSTANCE_URL
   SN_ORCHESTRATION_TOOL_ID
   SN_OAUTH_TOKEN (for CMDB API calls)
   ```

### AWS Requirements

1. **AWS Permissions**
   - EKS cluster read access
   - CloudWatch logs access
   - IAM permissions to create service accounts (if needed)

2. **AWS Configuration**
   - EKS cluster deployed and accessible
   - AWS credentials in GitHub Secrets
   - VPC and networking configured

### Development Environment

1. **Tools Installed**
   - AWS CLI configured
   - kubectl configured for EKS
   - ServiceNow API testing tool (Postman/curl)

2. **Access**
   - ServiceNow instance credentials
   - AWS console access
   - GitHub repository access

## Detailed Implementation Steps

### Phase 1: ServiceNow Setup

#### 1.1 Install ServiceNow DevOps Plugin

```bash
# In ServiceNow instance
1. Navigate to: System Definition > Plugins
2. Search for "DevOps"
3. Install: "DevOps (com.snc.devops)"
4. Wait for installation to complete (5-10 minutes)
5. Verify: DevOps > Configuration visible in navigation
```

#### 1.2 Configure GitHub Integration

```bash
# In ServiceNow
1. Navigate to: DevOps > Configuration > Tool Configuration
2. Click "New" to create GitHub integration
3. Fill in:
   - Name: "GitHub Actions"
   - Type: "GitHub"
   - URL: "https://github.com/your-org/microservices-demo"
   - Token: Generate from GitHub Settings > Developer settings > Personal access tokens
4. Test connection
5. Save configuration
6. Copy Tool ID for GitHub Actions
```

#### 1.3 Create Service Accounts and API Tokens

```javascript
// In ServiceNow Script Background
// Navigate to: System Definition > Scripts - Background

// Create integration user
var user = new GlideRecord('sys_user');
user.initialize();
user.user_name = 'github_integration';
user.first_name = 'GitHub';
user.last_name = 'Integration';
user.email = 'devops@yourcompany.com';
user.active = true;
user.insert();

// Assign roles
var userRole = new GlideRecord('sys_user_has_role');
userRole.initialize();
userRole.user = user.sys_id;
userRole.role = 'devops_user'; // DevOps user role
userRole.insert();

// Generate API token
// Navigate to: DevOps > Configuration > Integration Tokens
// Click "Generate Token"
// Save token securely for GitHub Secrets
```

#### 1.4 Configure Change Management Templates

```javascript
// Create Change Template for Automated Deployments
// Navigate to: Change > Templates

// Dev Environment Template
Template Name: "Automated Dev Deployment"
Type: Standard
Risk: Low
Assignment Group: DevOps Team
Auto-approve: true
Implementation Plan: "Automated deployment to dev environment via GitHub Actions"
Backout Plan: "Automatic rollback via GitHub Actions workflow"

// QA Environment Template
Template Name: "QA Environment Deployment"
Type: Standard
Risk: Medium
Assignment Group: QA Team
Auto-approve: false
Approval Required: QA Lead
Implementation Plan: "Deployment to QA environment after security scans pass"
Backout Plan: "Manual rollback if issues detected during QA testing"

// Prod Environment Template
Template Name: "Production Deployment"
Type: Standard
Risk: High
Assignment Group: Change Advisory Board
Auto-approve: false
Approval Required: Change Manager, Application Owner, Security Team
Implementation Plan: "Production deployment after QA validation"
Backout Plan: "Immediate rollback to previous stable version"
```

#### 1.5 Set Up Approval Workflows

```javascript
// Navigate to: Workflow > Workflow Editor

// Dev Auto-Approval Flow
Name: "Dev Auto Approval"
Conditions:
  - Environment = "dev"
  - Security scans = passed
Actions:
  - Auto-approve change
  - Notify DevOps team
  - Proceed to deployment

// QA Manual Approval Flow
Name: "QA Approval Required"
Conditions:
  - Environment = "qa"
  - Security scans = passed
  - All tests = passed
Actions:
  - Request approval from QA Lead
  - Wait for approval
  - If approved: proceed to deployment
  - If rejected: notify team and stop

// Prod Strict Approval Flow
Name: "Production Approval"
Conditions:
  - Environment = "prod"
  - Security scans = passed
  - QA validation = completed
  - Change window = scheduled
Actions:
  - Request approval from Change Manager
  - Request approval from Application Owner
  - Request approval from Security Team
  - Wait for all approvals
  - If approved: proceed to deployment
  - If rejected: notify team and stop
```

#### 1.6 Configure Security Tool Mappings

```javascript
// Navigate to: DevOps > Security > Tool Configuration

// Add security tools
var tools = [
  { name: 'Trivy', type: 'container_scanner', id: 'trivy' },
  { name: 'CodeQL', type: 'sast', id: 'codeql' },
  { name: 'Checkov', type: 'iac_scanner', id: 'checkov' },
  { name: 'Gitleaks', type: 'secret_scanner', id: 'gitleaks' },
  { name: 'Semgrep', type: 'sast', id: 'semgrep' }
];

tools.forEach(function(tool) {
  var secTool = new GlideRecord('sn_devops_security_tool');
  secTool.initialize();
  secTool.name = tool.name;
  secTool.type = tool.type;
  secTool.tool_id = tool.id;
  secTool.active = true;
  secTool.insert();
});

// Configure severity mapping
// Critical → Critical (blocks deployment)
// High → High (requires approval)
// Medium → Medium (warning)
// Low → Low (informational)
```

#### 1.7 Create CMDB CI Classes for EKS Resources

```javascript
// Navigate to: Configuration > CI Class Manager

// Create EKS Cluster CI Class
Class Name: "AWS EKS Cluster"
Parent Class: "cmdb_ci_cluster"
Attributes:
  - cluster_name (string)
  - cluster_version (string)
  - cluster_endpoint (URL)
  - region (string)
  - vpc_id (string)
  - node_groups (list)
  - status (choice: active, creating, deleting, failed)

// Create Microservice CI Class
Class Name: "Microservice"
Parent Class: "cmdb_ci_service"
Attributes:
  - service_name (string)
  - namespace (string)
  - replicas (integer)
  - image (string)
  - image_tag (string)
  - cluster (reference: AWS EKS Cluster)
  - language (choice: go, python, java, nodejs, csharp)
  - status (choice: running, pending, failed)

// Create relationship types
Relationship: "Runs on"
  From: Microservice
  To: AWS EKS Cluster
```

### Phase 2: GitHub Actions Integration - Security Scans

#### 2.1 Add ServiceNow Credentials to GitHub Secrets

```bash
# In GitHub repository
# Navigate to: Settings > Secrets and variables > Actions > New repository secret

# Add the following secrets:
1. SN_DEVOPS_INTEGRATION_TOKEN
   Value: [Token from Phase 1.3]

2. SN_INSTANCE_URL
   Value: https://your-instance.service-now.com

3. SN_ORCHESTRATION_TOOL_ID
   Value: [Tool ID from Phase 1.2]

4. SN_OAUTH_TOKEN
   Value: [OAuth token for CMDB API access]
```

#### 2.2 Update security-scan.yaml Workflow

Create new file: `.github/workflows/security-scan-servicenow.yaml`

```yaml
name: Security Scan with ServiceNow Integration

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 0'  # Weekly scan

env:
  SN_INSTANCE_URL: ${{ secrets.SN_INSTANCE_URL }}
  SN_DEVOPS_TOKEN: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  SN_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

jobs:
  # Job 1: Trivy Container Scanning
  trivy-scan:
    name: Trivy Container Security Scan
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build test images
        run: |
          # Build all microservices for scanning
          services=(frontend cartservice productcatalogservice currencyservice
                   paymentservice shippingservice emailservice checkoutservice
                   recommendationservice adservice loadgenerator shoppingassistantservice)

          for service in "${services[@]}"; do
            echo "Building $service..."
            docker build -t $service:latest ./src/$service
          done

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: 'frontend:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
          category: 'trivy'

      - name: Convert SARIF to ServiceNow format
        run: |
          # Convert SARIF to ServiceNow JSON format
          python3 << 'EOF'
          import json

          with open('trivy-results.sarif', 'r') as f:
              sarif = json.load(f)

          # Transform to ServiceNow format
          sn_results = {
              "scanner": "Trivy",
              "scannerVersion": "latest",
              "target": "microservices-demo",
              "vulnerabilities": []
          }

          for run in sarif.get('runs', []):
              for result in run.get('results', []):
                  vuln = {
                      "id": result.get('ruleId', ''),
                      "name": result.get('message', {}).get('text', ''),
                      "severity": result.get('level', 'warning').upper(),
                      "description": result.get('message', {}).get('text', ''),
                      "remediation": result.get('help', {}).get('text', ''),
                      "location": result.get('locations', [{}])[0].get('physicalLocation', {}).get('artifactLocation', {}).get('uri', '')
                  }
                  sn_results['vulnerabilities'].append(vuln)

          with open('trivy-sn-results.json', 'w') as f:
              json.dump(sn_results, f, indent=2)
          EOF

      - name: Upload Trivy results to ServiceNow
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Trivy Container Security Scan'
          security-result-attributes: |
            {
              "scanner": "Trivy",
              "applicationName": "microservices-demo",
              "securityToolId": "trivy"
            }
          security-result-file: 'trivy-sn-results.json'

  # Job 2: CodeQL SAST Scanning
  codeql-scan:
    name: CodeQL SAST Analysis
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read
      actions: read

    strategy:
      matrix:
        language: [ 'go', 'python', 'java', 'javascript', 'csharp' ]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"
          output: 'codeql-results-${{ matrix.language }}.sarif'

      - name: Upload CodeQL results to ServiceNow
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'CodeQL SAST Analysis'
          security-result-attributes: |
            {
              "scanner": "CodeQL",
              "applicationName": "microservices-demo",
              "securityToolId": "codeql",
              "language": "${{ matrix.language }}"
            }
          security-result-file: 'codeql-results-${{ matrix.language }}.sarif'

  # Job 3: Checkov IaC Scanning
  checkov-scan:
    name: Checkov IaC Security Scan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: terraform-aws/
          framework: terraform
          output_format: json
          output_file_path: checkov-results.json
          soft_fail: true

      - name: Upload Checkov results to ServiceNow
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Checkov IaC Security Scan'
          security-result-attributes: |
            {
              "scanner": "Checkov",
              "applicationName": "microservices-demo",
              "securityToolId": "checkov",
              "scanType": "Infrastructure as Code"
            }
          security-result-file: 'checkov-results.json'

  # Job 4: Gitleaks Secret Scanning
  gitleaks-scan:
    name: Gitleaks Secret Detection
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_ENABLE_SUMMARY: true
          GITLEAKS_CONFIG: .gitleaks.toml

      - name: Upload Gitleaks results
        if: always()
        run: |
          # Convert Gitleaks output to ServiceNow format
          if [ -f gitleaks-report.json ]; then
            echo "Gitleaks found secrets, uploading to ServiceNow..."
          fi

      - name: Upload Gitleaks results to ServiceNow
        if: always()
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Gitleaks Secret Detection'
          security-result-attributes: |
            {
              "scanner": "Gitleaks",
              "applicationName": "microservices-demo",
              "securityToolId": "gitleaks",
              "scanType": "Secret Detection"
            }
          security-result-file: 'gitleaks-report.json'

  # Job 5: Semgrep SAST Scanning
  semgrep-scan:
    name: Semgrep SAST Analysis
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/secrets
            p/owasp-top-ten
          generateSarif: true

      - name: Upload Semgrep results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif

      - name: Upload Semgrep results to ServiceNow
        uses: ServiceNow/servicenow-devops-security-result@v3.1.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Semgrep SAST Analysis'
          security-result-attributes: |
            {
              "scanner": "Semgrep",
              "applicationName": "microservices-demo",
              "securityToolId": "semgrep",
              "scanType": "SAST"
            }
          security-result-file: 'semgrep.sarif'

  # Job 6: Aggregate Security Results
  aggregate-results:
    name: Aggregate Security Results
    runs-on: ubuntu-latest
    needs: [trivy-scan, codeql-scan, checkov-scan, gitleaks-scan, semgrep-scan]
    if: always()

    steps:
      - name: Check security scan results
        run: |
          echo "All security scans completed"
          echo "Results sent to ServiceNow for review"

      - name: Create security summary
        run: |
          cat << EOF > security-summary.md
          # Security Scan Summary

          **Scan Date**: $(date)
          **Repository**: ${{ github.repository }}
          **Branch**: ${{ github.ref_name }}
          **Commit**: ${{ github.sha }}

          ## Scans Performed
          - ✅ Trivy (Container vulnerabilities)
          - ✅ CodeQL (SAST - 5 languages)
          - ✅ Checkov (IaC security)
          - ✅ Gitleaks (Secret detection)
          - ✅ Semgrep (SAST patterns)

          ## Results
          All results have been uploaded to ServiceNow for review and approval.

          View details in ServiceNow: ${{ secrets.SN_INSTANCE_URL }}/nav_to.do?uri=sn_devops_security_result_list.do
          EOF

          cat security-summary.md

      - name: Upload summary as artifact
        uses: actions/upload-artifact@v4
        with:
          name: security-summary
          path: security-summary.md
```

### Phase 3: Change Management Integration

#### 3.1 Update terraform-apply.yaml for Change Automation

Create new file: `.github/workflows/deploy-with-servicenow.yaml`

```yaml
name: Deploy with ServiceNow Change Management

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - qa
          - prod
      change_request_id:
        description: 'Existing Change Request ID (optional for dev)'
        required: false
        type: string

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices
  SN_INSTANCE_URL: ${{ secrets.SN_INSTANCE_URL }}
  SN_DEVOPS_TOKEN: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
  SN_TOOL_ID: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}

jobs:
  # Job 1: Create ServiceNow Change Request
  create-change-request:
    name: Create Change Request
    runs-on: ubuntu-latest
    outputs:
      change_request_number: ${{ steps.change.outputs.change-request-number }}
      change_request_sys_id: ${{ steps.change.outputs.change-request-sys-id }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Determine change request settings
        id: change-settings
        run: |
          ENV="${{ github.event.inputs.environment }}"

          if [ "$ENV" == "dev" ]; then
            echo "auto_close=true" >> $GITHUB_OUTPUT
            echo "risk=low" >> $GITHUB_OUTPUT
            echo "priority=3" >> $GITHUB_OUTPUT
            echo "assignment_group=DevOps Team" >> $GITHUB_OUTPUT
          elif [ "$ENV" == "qa" ]; then
            echo "auto_close=false" >> $GITHUB_OUTPUT
            echo "risk=medium" >> $GITHUB_OUTPUT
            echo "priority=2" >> $GITHUB_OUTPUT
            echo "assignment_group=QA Team" >> $GITHUB_OUTPUT
          elif [ "$ENV" == "prod" ]; then
            echo "auto_close=false" >> $GITHUB_OUTPUT
            echo "risk=high" >> $GITHUB_OUTPUT
            echo "priority=1" >> $GITHUB_OUTPUT
            echo "assignment_group=Change Advisory Board" >> $GITHUB_OUTPUT
          fi

      - name: Create ServiceNow Change Request
        id: change
        uses: ServiceNow/servicenow-devops-change@v4.0.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Deploy to ${{ github.event.inputs.environment }}'
          change-request: |
            {
              "setCloseCode": "${{ steps.change-settings.outputs.auto_close }}",
              "autoCloseChange": ${{ steps.change-settings.outputs.auto_close }},
              "attributes": {
                "short_description": "Deploy microservices-demo to ${{ github.event.inputs.environment }}",
                "description": "Automated deployment of microservices application to ${{ github.event.inputs.environment }} environment via GitHub Actions. Commit: ${{ github.sha }}",
                "assignment_group": "${{ steps.change-settings.outputs.assignment_group }}",
                "implementation_plan": "1. Run security scans\n2. Create Kubernetes manifests\n3. Apply manifests to EKS cluster\n4. Verify deployment health\n5. Update ServiceNow CMDB",
                "backout_plan": "Rollback to previous stable version using: kubectl rollout undo deployment -n microservices-${{ github.event.inputs.environment }}",
                "test_plan": "Verify all pods are running, check service endpoints, validate with load testing",
                "risk": "${{ steps.change-settings.outputs.risk }}",
                "priority": "${{ steps.change-settings.outputs.priority }}",
                "category": "Software",
                "type": "Standard",
                "cmdb_ci": "AWS EKS - microservices"
              }
            }

      - name: Output change request details
        run: |
          echo "Change Request Number: ${{ steps.change.outputs.change-request-number }}"
          echo "Change Request Sys ID: ${{ steps.change.outputs.change-request-sys-id }}"
          echo "View in ServiceNow: ${{ secrets.SN_INSTANCE_URL }}/nav_to.do?uri=change_request.do?sys_id=${{ steps.change.outputs.change-request-sys-id }}"

  # Job 2: Wait for Change Approval (QA and Prod only)
  wait-for-approval:
    name: Wait for Change Approval
    runs-on: ubuntu-latest
    needs: create-change-request
    if: github.event.inputs.environment != 'dev'

    steps:
      - name: Wait for ServiceNow Change Approval
        uses: ServiceNow/servicenow-devops-change@v4.0.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Wait for Approval'
          change-request-number: ${{ needs.create-change-request.outputs.change_request_number }}
          interval: '30'  # Check every 30 seconds
          timeout: '3600'  # 1 hour timeout

      - name: Approval received
        run: |
          echo "✅ Change request approved!"
          echo "Change Request: ${{ needs.create-change-request.outputs.change_request_number }}"
          echo "Proceeding with deployment..."

  # Job 3: Run Pre-Deployment Checks
  pre-deployment-checks:
    name: Pre-Deployment Checks
    runs-on: ubuntu-latest
    needs: [create-change-request, wait-for-approval]
    if: always() && needs.create-change-request.result == 'success'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Verify EKS cluster access
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}
          kubectl cluster-info
          kubectl get nodes

      - name: Check namespace exists
        run: |
          NAMESPACE="microservices-${{ github.event.inputs.environment }}"
          if ! kubectl get namespace $NAMESPACE; then
            echo "Creating namespace $NAMESPACE..."
            kubectl create namespace $NAMESPACE
            kubectl label namespace $NAMESPACE istio-injection=enabled
          fi

      - name: Verify security scans passed
        run: |
          # Check ServiceNow for security scan results
          SCAN_STATUS=$(curl -s -X GET \
            "${{ secrets.SN_INSTANCE_URL }}/api/now/table/sn_devops_security_result?sysparm_query=application_name=microservices-demo^ORDERBYDESCsys_created_on&sysparm_limit=1" \
            -H "Authorization: Bearer ${{ secrets.SN_OAUTH_TOKEN }}" \
            -H "Content-Type: application/json" | jq -r '.result[0].status')

          if [ "$SCAN_STATUS" != "passed" ]; then
            echo "❌ Security scans have not passed. Blocking deployment."
            exit 1
          fi

          echo "✅ Security scans passed"

      - name: Pre-deployment validation complete
        run: |
          echo "✅ All pre-deployment checks passed"
          echo "Ready to deploy to ${{ github.event.inputs.environment }}"

  # Job 4: Deploy Application
  deploy:
    name: Deploy to ${{ github.event.inputs.environment }}
    runs-on: ubuntu-latest
    needs: [create-change-request, wait-for-approval, pre-deployment-checks]
    if: always() && needs.pre-deployment-checks.result == 'success'
    environment:
      name: ${{ github.event.inputs.environment }}
      url: ${{ steps.get-url.outputs.application_url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy using Kustomize
        run: |
          ENV="${{ github.event.inputs.environment }}"
          echo "Deploying to environment: $ENV"

          # Apply Kustomize overlay
          kubectl apply -k kustomize/overlays/$ENV

          # Wait for rollout
          NAMESPACE="microservices-$ENV"
          kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/cartservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/productcatalogservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/currencyservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/paymentservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/shippingservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/emailservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/checkoutservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/recommendationservice -n $NAMESPACE --timeout=5m
          kubectl rollout status deployment/adservice -n $NAMESPACE --timeout=5m

      - name: Get application URL
        id: get-url
        run: |
          ENV="${{ github.event.inputs.environment }}"
          NAMESPACE="microservices-$ENV"

          # Get Istio Ingress Gateway URL
          INGRESS_URL=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          echo "application_url=http://$INGRESS_URL" >> $GITHUB_OUTPUT
          echo "Application URL: http://$INGRESS_URL"

      - name: Verify deployment health
        run: |
          ENV="${{ github.event.inputs.environment }}"
          NAMESPACE="microservices-$ENV"

          echo "Checking pod status..."
          kubectl get pods -n $NAMESPACE

          # Count running pods
          RUNNING_PODS=$(kubectl get pods -n $NAMESPACE -o json | jq '[.items[] | select(.status.phase=="Running")] | length')
          TOTAL_PODS=$(kubectl get pods -n $NAMESPACE -o json | jq '.items | length')

          echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"

          if [ $RUNNING_PODS -lt $TOTAL_PODS ]; then
            echo "⚠️ Not all pods are running"
            kubectl describe pods -n $NAMESPACE | grep -A 10 "Events:"
          else
            echo "✅ All pods are running"
          fi

      - name: Run smoke tests
        run: |
          ENV="${{ github.event.inputs.environment }}"
          INGRESS_URL=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

          echo "Running smoke tests against http://$INGRESS_URL"

          # Test homepage
          HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_URL)
          if [ $HTTP_CODE -eq 200 ]; then
            echo "✅ Homepage is accessible"
          else
            echo "❌ Homepage returned HTTP $HTTP_CODE"
            exit 1
          fi

          # Test product page
          HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_URL/product/OLJCESPC7Z)
          if [ $HTTP_CODE -eq 200 ]; then
            echo "✅ Product page is accessible"
          else
            echo "❌ Product page returned HTTP $HTTP_CODE"
            exit 1
          fi

          echo "✅ All smoke tests passed"

      - name: Update ServiceNow Change Request
        uses: ServiceNow/servicenow-devops-change@v4.0.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Update Change Request'
          change-request-number: ${{ needs.create-change-request.outputs.change_request_number }}
          change-request: |
            {
              "state": "3",
              "close_code": "successful",
              "close_notes": "Deployment completed successfully. All pods running. Smoke tests passed. Application URL: ${{ steps.get-url.outputs.application_url }}"
            }

  # Job 5: Post-Deployment CMDB Update
  update-cmdb:
    name: Update ServiceNow CMDB
    runs-on: ubuntu-latest
    needs: [create-change-request, deploy]
    if: always() && needs.deploy.result == 'success'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Gather deployment information
        id: gather-info
        run: |
          ENV="${{ github.event.inputs.environment }}"
          NAMESPACE="microservices-$ENV"

          # Get deployment details
          kubectl get deployments -n $NAMESPACE -o json > deployments.json

          # Extract information
          echo "Deployed services:"
          jq -r '.items[] | "\(.metadata.name): \(.spec.replicas) replicas"' deployments.json

      - name: Update CMDB with deployment info
        run: |
          ENV="${{ github.event.inputs.environment }}"
          NAMESPACE="microservices-$ENV"

          # Get list of services
          SERVICES=(frontend cartservice productcatalogservice currencyservice
                   paymentservice shippingservice emailservice checkoutservice
                   recommendationservice adservice loadgenerator shoppingassistantservice)

          for service in "${SERVICES[@]}"; do
            # Get service details
            REPLICAS=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
            IMAGE=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
            STATUS=$(kubectl get deployment $service -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")

            if [ "$REPLICAS" != "0" ]; then
              # Update ServiceNow CMDB
              PAYLOAD=$(cat <<EOF
          {
            "name": "$service",
            "namespace": "$NAMESPACE",
            "environment": "$ENV",
            "replicas": "$REPLICAS",
            "image": "$IMAGE",
            "status": "$STATUS",
            "cluster": "microservices",
            "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "updated_by": "GitHub Actions"
          }
          EOF
          )

              echo "Updating CMDB for $service..."
              curl -X POST \
                "${{ secrets.SN_INSTANCE_URL }}/api/now/table/u_microservice" \
                -H "Authorization: Bearer ${{ secrets.SN_OAUTH_TOKEN }}" \
                -H "Content-Type: application/json" \
                -d "$PAYLOAD"
            fi
          done

          echo "✅ CMDB updated successfully"

  # Job 6: Rollback on Failure
  rollback:
    name: Rollback Deployment
    runs-on: ubuntu-latest
    needs: [create-change-request, deploy]
    if: failure() && needs.deploy.result == 'failure'

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Rollback deployments
        run: |
          ENV="${{ github.event.inputs.environment }}"
          NAMESPACE="microservices-$ENV"

          echo "⚠️ Deployment failed. Rolling back..."

          # Rollback all deployments
          kubectl rollout undo deployment/frontend -n $NAMESPACE
          kubectl rollout undo deployment/cartservice -n $NAMESPACE
          kubectl rollout undo deployment/productcatalogservice -n $NAMESPACE
          kubectl rollout undo deployment/currencyservice -n $NAMESPACE
          kubectl rollout undo deployment/paymentservice -n $NAMESPACE
          kubectl rollout undo deployment/shippingservice -n $NAMESPACE
          kubectl rollout undo deployment/emailservice -n $NAMESPACE
          kubectl rollout undo deployment/checkoutservice -n $NAMESPACE
          kubectl rollout undo deployment/recommendationservice -n $NAMESPACE
          kubectl rollout undo deployment/adservice -n $NAMESPACE

          echo "✅ Rollback completed"

      - name: Update ServiceNow Change Request - Failed
        uses: ServiceNow/servicenow-devops-change@v4.0.0
        with:
          devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
          instance-url: ${{ secrets.SN_INSTANCE_URL }}
          tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
          context-github: ${{ toJSON(github) }}
          job-name: 'Update Change Request - Failed'
          change-request-number: ${{ needs.create-change-request.outputs.change_request_number }}
          change-request: |
            {
              "state": "4",
              "close_code": "unsuccessful",
              "close_notes": "Deployment failed. Automatic rollback executed. Check GitHub Actions logs for details: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }
```

### Phase 4: AWS EKS Discovery

#### 4.1 ServiceNow AWS Service Management Connector Setup

```bash
# In ServiceNow instance
1. Navigate to: System Applications > All Available Applications > All
2. Search for: "AWS Service Management Connector"
3. Click "Install"
4. Wait for installation (10-15 minutes)
5. Navigate to: AWS Service Management > Setup

# Configure AWS Account
6. AWS Service Management > AWS Accounts > New
   - Account Name: "Production AWS Account"
   - Account ID: [Your AWS Account ID]
   - Access Key ID: [AWS Access Key with read permissions]
   - Secret Access Key: [AWS Secret Key]
   - Regions: eu-west-2 (or your regions)
   - Discovery Schedule: Daily at 2:00 AM

# Enable EKS Discovery
7. AWS Service Management > Discovery Configuration
   - Enable: Amazon EKS
   - Enable: Amazon VPC
   - Enable: Amazon EC2
   - Enable: Elastic Load Balancing
   - Enable: Amazon ElastiCache

8. Test connection: AWS Service Management > Test AWS Connection
```

#### 4.2 Create Custom EKS Discovery Script

Create: `.github/workflows/eks-discovery.yaml`

```yaml
name: EKS Cluster Discovery to ServiceNow

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:  # Manual trigger
  push:
    paths:
      - 'kustomize/overlays/**'
      - 'kubernetes-manifests/**'

env:
  AWS_REGION: eu-west-2
  CLUSTER_NAME: microservices
  SN_INSTANCE_URL: ${{ secrets.SN_INSTANCE_URL }}
  SN_OAUTH_TOKEN: ${{ secrets.SN_OAUTH_TOKEN }}

jobs:
  discover-eks-cluster:
    name: Discover EKS Cluster
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq

      - name: Discover EKS cluster information
        id: cluster-info
        run: |
          echo "Discovering EKS cluster: ${{ env.CLUSTER_NAME }}"

          # Get cluster details
          aws eks describe-cluster --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }} > cluster.json

          # Extract key information
          CLUSTER_ARN=$(jq -r '.cluster.arn' cluster.json)
          CLUSTER_VERSION=$(jq -r '.cluster.version' cluster.json)
          CLUSTER_ENDPOINT=$(jq -r '.cluster.endpoint' cluster.json)
          CLUSTER_STATUS=$(jq -r '.cluster.status' cluster.json)
          VPC_ID=$(jq -r '.cluster.resourcesVpcConfig.vpcId' cluster.json)

          echo "cluster_arn=$CLUSTER_ARN" >> $GITHUB_OUTPUT
          echo "cluster_version=$CLUSTER_VERSION" >> $GITHUB_OUTPUT
          echo "cluster_endpoint=$CLUSTER_ENDPOINT" >> $GITHUB_OUTPUT
          echo "cluster_status=$CLUSTER_STATUS" >> $GITHUB_OUTPUT
          echo "vpc_id=$VPC_ID" >> $GITHUB_OUTPUT

          # Get node groups
          aws eks list-nodegroups --cluster-name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }} > nodegroups.json

          echo "Cluster details:"
          echo "  ARN: $CLUSTER_ARN"
          echo "  Version: $CLUSTER_VERSION"
          echo "  Status: $CLUSTER_STATUS"
          echo "  VPC: $VPC_ID"

      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --name ${{ env.CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Discover microservices in all environments
        id: discover-services
        run: |
          echo "Discovering microservices in all namespaces..."

          NAMESPACES=("microservices-dev" "microservices-qa" "microservices-prod")

          # Create JSON array for all services
          echo '{"services": []}' > all-services.json

          for NAMESPACE in "${NAMESPACES[@]}"; do
            if kubectl get namespace $NAMESPACE &> /dev/null; then
              echo "Discovering services in $NAMESPACE..."

              # Get all deployments
              kubectl get deployments -n $NAMESPACE -o json | \
                jq --arg ns "$NAMESPACE" --arg env "${NAMESPACE##*-}" '
                  .items[] | {
                    name: .metadata.name,
                    namespace: $ns,
                    environment: $env,
                    replicas: .spec.replicas,
                    ready_replicas: (.status.readyReplicas // 0),
                    image: .spec.template.spec.containers[0].image,
                    image_tag: (.spec.template.spec.containers[0].image | split(":")[1]),
                    created: .metadata.creationTimestamp,
                    labels: .metadata.labels,
                    status: (if .status.readyReplicas == .spec.replicas then "Running" else "Degraded" end)
                  }
                ' > services-$NAMESPACE.json

              # Append to all services
              jq --slurpfile new services-$NAMESPACE.json '.services += $new[0]' all-services.json > tmp.json
              mv tmp.json all-services.json
            fi
          done

          echo "Total services discovered: $(jq '.services | length' all-services.json)"
          cat all-services.json

      - name: Upload cluster info to ServiceNow CMDB
        run: |
          echo "Uploading cluster information to ServiceNow CMDB..."

          # Prepare cluster payload
          CLUSTER_PAYLOAD=$(cat <<EOF
          {
            "u_name": "${{ env.CLUSTER_NAME }}",
            "u_arn": "${{ steps.cluster-info.outputs.cluster_arn }}",
            "u_version": "${{ steps.cluster-info.outputs.cluster_version }}",
            "u_endpoint": "${{ steps.cluster-info.outputs.cluster_endpoint }}",
            "u_status": "${{ steps.cluster-info.outputs.cluster_status }}",
            "u_region": "${{ env.AWS_REGION }}",
            "u_vpc_id": "${{ steps.cluster-info.outputs.vpc_id }}",
            "u_provider": "AWS EKS",
            "u_last_discovered": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "u_discovered_by": "GitHub Actions"
          }
          EOF
          )

          # Check if cluster exists in CMDB
          EXISTING_CLUSTER=$(curl -s -X GET \
            "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster?sysparm_query=u_name=${{ env.CLUSTER_NAME }}&sysparm_limit=1" \
            -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
            -H "Content-Type: application/json")

          CLUSTER_SYS_ID=$(echo $EXISTING_CLUSTER | jq -r '.result[0].sys_id // empty')

          if [ -n "$CLUSTER_SYS_ID" ]; then
            echo "Updating existing cluster record: $CLUSTER_SYS_ID"
            curl -X PUT \
              "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster/$CLUSTER_SYS_ID" \
              -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
              -H "Content-Type: application/json" \
              -d "$CLUSTER_PAYLOAD"
          else
            echo "Creating new cluster record"
            CLUSTER_RESPONSE=$(curl -X POST \
              "${{ env.SN_INSTANCE_URL }}/api/now/table/u_eks_cluster" \
              -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
              -H "Content-Type: application/json" \
              -d "$CLUSTER_PAYLOAD")

            CLUSTER_SYS_ID=$(echo $CLUSTER_RESPONSE | jq -r '.result.sys_id')
          fi

          echo "Cluster sys_id: $CLUSTER_SYS_ID"
          echo "CLUSTER_SYS_ID=$CLUSTER_SYS_ID" >> $GITHUB_ENV

      - name: Upload microservices to ServiceNow CMDB
        run: |
          echo "Uploading microservices to ServiceNow CMDB..."

          # Read all services
          SERVICES=$(jq -c '.services[]' all-services.json)

          while IFS= read -r service; do
            NAME=$(echo $service | jq -r '.name')
            NAMESPACE=$(echo $service | jq -r '.namespace')
            ENV=$(echo $service | jq -r '.environment')
            REPLICAS=$(echo $service | jq -r '.replicas')
            READY_REPLICAS=$(echo $service | jq -r '.ready_replicas')
            IMAGE=$(echo $service | jq -r '.image')
            IMAGE_TAG=$(echo $service | jq -r '.image_tag')
            STATUS=$(echo $service | jq -r '.status')

            echo "Processing: $NAME ($NAMESPACE)"

            # Prepare service payload
            SERVICE_PAYLOAD=$(cat <<EOF
          {
            "u_name": "$NAME",
            "u_namespace": "$NAMESPACE",
            "u_environment": "$ENV",
            "u_replicas": "$REPLICAS",
            "u_ready_replicas": "$READY_REPLICAS",
            "u_image": "$IMAGE",
            "u_image_tag": "$IMAGE_TAG",
            "u_status": "$STATUS",
            "u_cluster": "$CLUSTER_SYS_ID",
            "u_last_discovered": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "u_discovered_by": "GitHub Actions"
          }
          EOF
          )

            # Check if service exists
            EXISTING_SERVICE=$(curl -s -X GET \
              "${{ env.SN_INSTANCE_URL }}/api/now/table/u_microservice?sysparm_query=u_name=$NAME^u_namespace=$NAMESPACE&sysparm_limit=1" \
              -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
              -H "Content-Type: application/json")

            SERVICE_SYS_ID=$(echo $EXISTING_SERVICE | jq -r '.result[0].sys_id // empty')

            if [ -n "$SERVICE_SYS_ID" ]; then
              echo "  Updating existing service: $SERVICE_SYS_ID"
              curl -s -X PUT \
                "${{ env.SN_INSTANCE_URL }}/api/now/table/u_microservice/$SERVICE_SYS_ID" \
                -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
                -H "Content-Type: application/json" \
                -d "$SERVICE_PAYLOAD" > /dev/null
            else
              echo "  Creating new service record"
              curl -s -X POST \
                "${{ env.SN_INSTANCE_URL }}/api/now/table/u_microservice" \
                -H "Authorization: Bearer ${{ env.SN_OAUTH_TOKEN }}" \
                -H "Content-Type: application/json" \
                -d "$SERVICE_PAYLOAD" > /dev/null
            fi
          done <<< "$SERVICES"

          echo "✅ All microservices uploaded to CMDB"

      - name: Create discovery summary
        run: |
          cat << EOF > discovery-summary.md
          # EKS Discovery Summary

          **Discovery Date**: $(date)
          **Cluster**: ${{ env.CLUSTER_NAME }}
          **Region**: ${{ env.AWS_REGION }}

          ## Cluster Information
          - **ARN**: ${{ steps.cluster-info.outputs.cluster_arn }}
          - **Version**: ${{ steps.cluster-info.outputs.cluster_version }}
          - **Status**: ${{ steps.cluster-info.outputs.cluster_status }}
          - **VPC**: ${{ steps.cluster-info.outputs.vpc_id }}

          ## Microservices Discovered
          \`\`\`
          $(jq -r '.services[] | "- \(.name) [\(.environment)]: \(.ready_replicas)/\(.replicas) replicas - \(.status)"' all-services.json)
          \`\`\`

          ## ServiceNow CMDB
          - **Cluster Record**: ${{ env.SN_INSTANCE_URL }}/nav_to.do?uri=u_eks_cluster.do?sys_id=$CLUSTER_SYS_ID
          - **Services**: ${{ env.SN_INSTANCE_URL }}/nav_to.do?uri=u_microservice_list.do

          ---
          Discovery completed successfully ✅
          EOF

          cat discovery-summary.md

      - name: Upload summary as artifact
        uses: actions/upload-artifact@v4
        with:
          name: discovery-summary
          path: |
            discovery-summary.md
            all-services.json
            cluster.json
```

## Security Considerations

### 1. Authentication & Authorization

**ServiceNow Credentials**
- Use OAuth 2.0 tokens instead of basic auth
- Store all credentials in GitHub Secrets (never in code)
- Rotate tokens every 90 days
- Use least-privilege principle for service accounts

**AWS Credentials**
- Use IAM roles with minimal permissions
- Enable MFA for human users
- Use temporary credentials where possible
- Audit access regularly

### 2. Secret Management

**GitHub Secrets Required**
```bash
# ServiceNow
SN_DEVOPS_INTEGRATION_TOKEN  # DevOps integration
SN_INSTANCE_URL              # ServiceNow instance URL
SN_ORCHESTRATION_TOOL_ID     # GitHub tool ID from ServiceNow
SN_OAUTH_TOKEN               # For CMDB API access

# AWS
AWS_ACCESS_KEY_ID            # AWS access key
AWS_SECRET_ACCESS_KEY        # AWS secret key
```

**Best Practices**
- Never log secrets in workflow output
- Use GitHub's encrypted secrets
- Rotate credentials regularly
- Audit secret access
- Use environment-specific secrets where possible

### 3. Network Security

**ServiceNow Access**
- Whitelist GitHub Actions IP ranges in ServiceNow
- Use HTTPS for all API calls
- Implement rate limiting
- Monitor for suspicious activity

**AWS Access**
- Use VPC endpoints for private communication
- Enable VPC Flow Logs
- Implement Security Groups properly
- Use private subnets for workloads

### 4. Data Protection

**Sensitive Information**
- Never include PII in change requests
- Redact sensitive data from logs
- Encrypt data in transit (HTTPS/TLS)
- Follow data retention policies

**Compliance**
- Document all integrations for audit
- Maintain access logs
- Implement change tracking
- Regular security reviews

## Testing Strategy

### 1. Unit Testing

**Test Individual Components**
```bash
# Test ServiceNow API connectivity
curl -X GET \
  "$SN_INSTANCE_URL/api/now/table/sys_user?sysparm_limit=1" \
  -H "Authorization: Bearer $SN_OAUTH_TOKEN" \
  -H "Content-Type: application/json"

# Test AWS EKS access
aws eks describe-cluster --name microservices --region eu-west-2

# Test kubectl connectivity
kubectl cluster-info
kubectl get nodes
```

### 2. Integration Testing

**Test Workflow Components**
```yaml
# Test change request creation
- Run workflow with dev environment
- Verify change request created in ServiceNow
- Check auto-approval for dev
- Confirm deployment proceeds

# Test security scan integration
- Trigger security scan workflow
- Verify results appear in ServiceNow
- Check vulnerability records created
- Confirm severity mapping correct

# Test CMDB discovery
- Run discovery workflow
- Verify cluster record in CMDB
- Check all services discovered
- Confirm relationship mapping
```

### 3. End-to-End Testing

**Full Deployment Cycle**
```bash
# Phase 1: Dev Deployment
1. Push code to main branch
2. Security scans run automatically
3. Change request auto-created for dev
4. Auto-approved for dev
5. Deployment to dev namespace
6. CMDB updated
7. Verify application accessible

# Phase 2: QA Promotion
1. Manual workflow trigger for qa
2. Change request created
3. Approval requested from QA Lead
4. Manual approval in ServiceNow
5. Deployment to qa namespace
6. Smoke tests pass
7. CMDB updated

# Phase 3: Prod Promotion
1. Manual workflow trigger for prod
2. Change request created
3. Approval requested from CAB
4. All approvals obtained
5. Deployment to prod namespace
6. Full smoke tests
7. CMDB updated
8. Change request closed
```

### 4. Failure Testing

**Rollback Scenarios**
```bash
# Test deployment failure
1. Introduce error in manifest
2. Deploy to dev
3. Verify rollback triggered
4. Check ServiceNow change updated with failure
5. Confirm previous version restored

# Test approval rejection
1. Deploy to qa
2. Reject change in ServiceNow
3. Verify deployment blocked
4. Check change request state

# Test security gate
1. Introduce critical vulnerability
2. Run security scan
3. Verify deployment blocked
4. Check ServiceNow security record
```

## Rollout Plan

### Week 1: Foundation Setup

**Day 1-2: ServiceNow Configuration**
- [ ] Install DevOps plugin
- [ ] Create service accounts
- [ ] Configure GitHub integration
- [ ] Set up change templates
- [ ] Create CMDB CI classes

**Day 3-4: GitHub Setup**
- [ ] Add secrets to repository
- [ ] Create security scan workflow
- [ ] Test security result submission
- [ ] Validate ServiceNow connectivity

**Day 5: Testing**
- [ ] Unit test all components
- [ ] Integration test security scans
- [ ] Document any issues
- [ ] Create runbook for troubleshooting

### Week 2: Change Management Integration

**Day 6-7: Dev Environment**
- [ ] Create change automation workflow
- [ ] Configure dev auto-approval
- [ ] Test dev deployment cycle
- [ ] Validate change tracking

**Day 8-9: QA Environment**
- [ ] Configure QA approval workflow
- [ ] Set up approval routing
- [ ] Test manual approval process
- [ ] Document approval procedures

**Day 10: Testing**
- [ ] End-to-end test dev to qa promotion
- [ ] Test rejection scenarios
- [ ] Validate rollback procedures
- [ ] Update documentation

### Week 3: Discovery and Production

**Day 11-13: EKS Discovery**
- [ ] Configure AWS connector
- [ ] Create discovery workflow
- [ ] Test CMDB population
- [ ] Validate data accuracy

**Day 14-15: Production Setup**
- [ ] Configure prod approval workflow
- [ ] Set up CAB approval routing
- [ ] Create production runbook
- [ ] Test prod deployment (staging)

### Week 4: Validation and Launch

**Day 16-18: Full Testing**
- [ ] End-to-end test all environments
- [ ] Performance testing
- [ ] Security audit
- [ ] Documentation review

**Day 19-20: Launch**
- [ ] Team training sessions
- [ ] Enable workflows for all environments
- [ ] Monitor initial deployments
- [ ] Gather feedback and iterate

## Monitoring and Maintenance

### 1. Monitoring

**GitHub Actions Monitoring**
```yaml
# Add to all workflows
- name: Notify on failure
  if: failure()
  run: |
    curl -X POST $SLACK_WEBHOOK_URL \
      -H 'Content-Type: application/json' \
      -d '{
        "text": "GitHub Actions workflow failed",
        "blocks": [{
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Workflow*: ${{ github.workflow }}\n*Status*: Failed\n*URL*: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
          }
        }]
      }'
```

**ServiceNow Monitoring**
- Create ServiceNow dashboard for:
  - Deployment frequency
  - Change success rate
  - Security vulnerabilities discovered
  - CMDB accuracy metrics
  - Approval time metrics

**AWS Monitoring**
- CloudWatch dashboards for:
  - EKS cluster health
  - Pod status across environments
  - Application performance metrics
  - Error rates

### 2. Maintenance Tasks

**Weekly Tasks**
- [ ] Review failed workflows
- [ ] Check security scan results
- [ ] Validate CMDB accuracy
- [ ] Review approval times
- [ ] Check for workflow updates

**Monthly Tasks**
- [ ] Rotate ServiceNow tokens
- [ ] Review and update approval workflows
- [ ] Audit access logs
- [ ] Update documentation
- [ ] Review and optimize workflows

**Quarterly Tasks**
- [ ] Security audit of entire integration
- [ ] Performance review
- [ ] Cost analysis
- [ ] Team training refresh
- [ ] Review and update runbooks

### 3. Troubleshooting Guide

**Common Issues**

1. **Change Request Not Created**
   - Check ServiceNow connectivity
   - Verify integration token valid
   - Check workflow logs for errors
   - Validate tool ID configuration

2. **Security Scans Not Appearing**
   - Verify security tool mapping in ServiceNow
   - Check SARIF file format
   - Validate API permissions
   - Review workflow logs

3. **CMDB Not Updating**
   - Check AWS credentials
   - Verify kubectl configuration
   - Validate ServiceNow API access
   - Check CMDB CI class definitions

4. **Approval Workflow Stuck**
   - Check assignment group configuration
   - Verify approvers have permissions
   - Review workflow conditions
   - Check ServiceNow notifications

## Success Metrics

### Key Performance Indicators (KPIs)

**Deployment Metrics**
- Deployment frequency: Target 10+ per week
- Lead time for changes: Target <1 hour for dev, <4 hours for prod
- Change failure rate: Target <5%
- Mean time to recovery (MTTR): Target <30 minutes

**Security Metrics**
- Security scans per deployment: 100%
- Critical vulnerabilities blocked: 100%
- Mean time to remediate: Target <7 days
- False positive rate: Target <10%

**Approval Metrics**
- Dev auto-approval rate: 100%
- QA approval time: Target <2 hours
- Prod approval time: Target <24 hours
- Approval rejection rate: Target <5%

**CMDB Metrics**
- CMDB accuracy: Target >95%
- Discovery frequency: Every 6 hours
- Data freshness: Target <6 hours old
- Relationship accuracy: Target >90%

## Conclusion

This comprehensive integration plan provides a roadmap for connecting GitHub Actions, AWS EKS, and ServiceNow DevOps. The implementation will enable:

1. **Automated change management** with environment-specific approval workflows
2. **Security vulnerability tracking** from multiple scanning tools
3. **Real-time CMDB updates** with accurate infrastructure information
4. **Full audit trail** of all deployments and changes
5. **Improved collaboration** between development, operations, and security teams

By following this phased approach, the team can gradually implement each component, validate functionality, and ensure a smooth rollout across all environments.

### Next Steps

1. Review this plan with stakeholders
2. Obtain ServiceNow instance access and licensing
3. Begin Phase 1: ServiceNow Setup
4. Schedule weekly check-ins to track progress
5. Document lessons learned and iterate

### Resources

- [ServiceNow DevOps Documentation](https://docs.servicenow.com/bundle/vancouver-devops/page/product/enterprise-dev-ops/reference/devops-landing-page.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Istio Service Mesh Documentation](https://istio.io/latest/docs/)
