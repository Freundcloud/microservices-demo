# Documentation Index

> **Last Updated**: 2025-10-28
> **Project**: Online Boutique Microservices Demo on AWS EKS

This is the complete documentation index for the microservices demo project. All documentation has been reorganized for clarity and ease of navigation.

---

## 🚀 Quick Start

| Document | Description | Audience |
|----------|-------------|----------|
| [**Getting Started**](guides/GETTING-STARTED.md) | Complete onboarding guide for new developers | New Team Members |
| [**AWS Deployment**](guides/AWS-DEPLOYMENT.md) | Deploy infrastructure and application to AWS | DevOps Engineers |
| [**Demo Guide**](guides/DEMO-GUIDE.md) | How to demo the platform to stakeholders | Sales, Architects |

---

## 📚 Core Documentation

### Architecture

- [**System Architecture**](architecture/SYSTEM-ARCHITECTURE.md) - High-level system design and components
- [**Repository Structure**](architecture/REPOSITORY-STRUCTURE.md) - Codebase organization and patterns
- [**Istio Service Mesh**](architecture/ISTIO-DEPLOYMENT.md) - Service mesh configuration and usage

### Workflows & CI/CD

- [**Workflow Overview**](workflows/OVERVIEW.md) - Complete CI/CD pipeline explanation
- [**Workflow Refactoring**](workflows/REFACTORING-GUIDE.md) - How we optimized workflows (40-60% faster builds)
- [**Composite Actions**](workflows/COMPOSITE-ACTIONS.md) - Reusable workflow components

### ServiceNow Integration

- [**ServiceNow Overview**](servicenow/OVERVIEW.md) - Complete integration guide
- [**Change Management**](servicenow/CHANGE-MANAGEMENT.md) - Automated change request lifecycle
- [**Test Results Integration**](servicenow/TEST-INTEGRATION.md) - Test result registration
- [**Security Integration**](servicenow/SECURITY-INTEGRATION.md) - Vulnerability and SBOM upload

### Setup Guides

- [**AWS Setup**](setup/AWS-SETUP.md) - AWS account and IAM configuration
- [**GitHub Actions Setup**](setup/GITHUB-ACTIONS-SETUP.md) - Repository secrets and configuration
- [**Security Scanning Setup**](setup/SECURITY-SCANNING.md) - Enable all 10 security scanners

---

## 🎯 By Use Case

### For New Developers

1. Read [Getting Started](guides/GETTING-STARTED.md)
2. Follow [AWS Deployment](guides/AWS-DEPLOYMENT.md)
3. Review [Development Guide](guides/DEVELOPMENT.md)

### For DevOps Engineers

1. Review [Workflow Overview](workflows/OVERVIEW.md)
2. Study [Workflow Refactoring Guide](workflows/REFACTORING-GUIDE.md)
3. Understand [ServiceNow Integration](servicenow/OVERVIEW.md)

### For Security Teams

1. Check [Security Scanning Setup](setup/SECURITY-SCANNING.md)
2. Review [Security Integration](servicenow/SECURITY-INTEGRATION.md)
3. See [Compliance Guide](compliance/SOC-ISO27001.md)

### For Managers/Stakeholders

1. Read [Executive Summary](guides/EXECUTIVE-SUMMARY.md)
2. Review [Demo Guide](guides/DEMO-GUIDE.md)
3. Check [Compliance Coverage](compliance/SOC-ISO27001.md)

---

## 📖 Reference Documentation

### Terraform

- [Terraform Backend Guide](reference/TERRAFORM-BACKEND.md)
- [Infrastructure Discovery](reference/AWS-INFRASTRUCTURE-DISCOVERY.md)

### Troubleshooting

- [Common Issues](reference/TROUBLESHOOTING.md)
- [ServiceNow Troubleshooting](servicenow/TROUBLESHOOTING.md)

### Historical Records

- [Session Summaries](_archive/sessions/)
- [Implementation Details](_archive/implementation-details/)

---

## 🗂️ Documentation Structure

```
docs/
├── INDEX.md                    # This file
├── README.md                   # Main documentation entry point
│
├── guides/                     # User-facing guides
│   ├── GETTING-STARTED.md     # New developer onboarding
│   ├── AWS-DEPLOYMENT.md      # Complete deployment guide
│   ├── DEMO-GUIDE.md          # How to demo the platform
│   ├── DEVELOPMENT.md         # Development workflows
│   └── EXECUTIVE-SUMMARY.md   # High-level overview
│
├── workflows/                  # CI/CD documentation
│   ├── OVERVIEW.md            # Pipeline explanation
│   ├── REFACTORING-GUIDE.md   # Optimization summary
│   └── COMPOSITE-ACTIONS.md   # Reusable components
│
├── servicenow/                 # ServiceNow integration
│   ├── OVERVIEW.md            # Complete integration guide
│   ├── CHANGE-MANAGEMENT.md   # Change automation
│   ├── TEST-INTEGRATION.md    # Test results
│   └── SECURITY-INTEGRATION.md # Vulnerability/SBOM
│
├── setup/                      # Configuration guides
│   ├── AWS-SETUP.md           # AWS prerequisites
│   ├── GITHUB-ACTIONS-SETUP.md # GitHub configuration
│   └── SECURITY-SCANNING.md   # Security scanner setup
│
├── architecture/               # System design
│   ├── SYSTEM-ARCHITECTURE.md # High-level architecture
│   ├── REPOSITORY-STRUCTURE.md # Code organization
│   └── ISTIO-DEPLOYMENT.md    # Service mesh
│
├── compliance/                 # Compliance & audit
│   └── SOC-ISO27001.md        # Compliance coverage
│
├── reference/                  # Technical reference
│   ├── TERRAFORM-BACKEND.md   # Terraform state management
│   ├── TROUBLESHOOTING.md     # Common issues
│   └── AWS-INFRASTRUCTURE-DISCOVERY.md
│
└── _archive/                   # Historical documentation
    ├── sessions/              # Session summaries
    └── implementation-details/ # Implementation records
```

---

## 🔄 Documentation Maintenance

### When to Update

- **After infrastructure changes**: Update architecture and setup docs
- **After workflow changes**: Update workflow and CI/CD docs
- **After ServiceNow changes**: Update integration docs
- **After security changes**: Update security scanning docs

### Contribution Guidelines

1. Keep documentation concise and actionable
2. Use diagrams where helpful
3. Include examples and code snippets
4. Test all commands before documenting
5. Update INDEX.md when adding new docs

---

## 📊 Documentation Statistics

- **Total Documents**: 25 active documents
- **Archived Documents**: 35+ historical records
- **Last Major Reorganization**: 2025-10-28
- **Documentation Coverage**: Core workflows, setup, integration, compliance

---

## 🤝 Getting Help

- **Issues**: Check [Troubleshooting Guide](reference/TROUBLESHOOTING.md)
- **Questions**: Review [FAQ](guides/FAQ.md) (coming soon)
- **Updates**: See [CHANGELOG.md](CHANGELOG.md) (coming soon)

---

*This documentation supports the Online Boutique microservices demo running on AWS EKS with comprehensive DevOps automation.*
