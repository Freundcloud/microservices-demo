# ServiceNow Integration Architecture

## Overview Diagram

This document provides visual representations of the ServiceNow integration architecture.

## Full Integration Architecture

```mermaid
graph TB
    subgraph "GitHub Repository"
        CODE[Code Changes]
        PR[Pull Request]
        MERGE[Merge to Main]
    end

    subgraph "GitHub Actions Workflows"
        SEC_SCAN[Security Scan<br/>Workflow]
        DEPLOY[Deploy with<br/>ServiceNow Workflow]
        DISCOVERY[EKS Discovery<br/>Workflow]

        subgraph "Security Scanners"
            TRIVY[Trivy<br/>Container Scan]
            CODEQL[CodeQL<br/>SAST]
            CHECKOV[Checkov<br/>IaC Security]
            GITLEAKS[Gitleaks<br/>Secrets]
            SEMGREP[Semgrep<br/>SAST]
        end
    end

    subgraph "ServiceNow Platform"
        subgraph "DevOps Module"
            DEVOPS_SEC[Security Results]
            CHANGE_MGT[Change Management]
            DEPLOY_TRACK[Deployment Tracking]
        end

        subgraph "CMDB"
            EKS_CI[EKS Cluster CI]
            SVC_CI[Microservices CIs]
            REL[Relationships]
        end

        subgraph "Approval Workflows"
            DEV_AUTO[Dev Auto-Approve]
            QA_MANUAL[QA Manual Approve]
            PROD_CAB[Prod CAB Approve]
        end

        subgraph "Vulnerability Response"
            VULN[Vulnerabilities]
            REMEDIATE[Remediation Tasks]
        end
    end

    subgraph "AWS EKS"
        CLUSTER[EKS Cluster<br/>microservices]

        subgraph "Environments"
            DEV_NS[Dev Namespace]
            QA_NS[QA Namespace]
            PROD_NS[Prod Namespace]
        end

        subgraph "Microservices"
            FRONTEND[Frontend]
            CART[Cart Service]
            PRODUCT[Product Catalog]
            CURRENCY[Currency Service]
            PAYMENT[Payment Service]
            SHIPPING[Shipping Service]
            EMAIL[Email Service]
            CHECKOUT[Checkout Service]
            RECOMMEND[Recommendation]
            ADS[Ad Service]
            LOAD[Load Generator]
            ASSISTANT[Shopping Assistant]
        end
    end

    %% Workflow Triggers
    CODE --> PR
    PR --> SEC_SCAN
    MERGE --> DEPLOY
    DEPLOY --> DISCOVERY

    %% Security Scan Flow
    SEC_SCAN --> TRIVY
    SEC_SCAN --> CODEQL
    SEC_SCAN --> CHECKOV
    SEC_SCAN --> GITLEAKS
    SEC_SCAN --> SEMGREP

    TRIVY --> DEVOPS_SEC
    CODEQL --> DEVOPS_SEC
    CHECKOV --> DEVOPS_SEC
    GITLEAKS --> DEVOPS_SEC
    SEMGREP --> DEVOPS_SEC

    DEVOPS_SEC --> VULN
    VULN --> REMEDIATE

    %% Deployment Flow
    DEPLOY --> CHANGE_MGT
    CHANGE_MGT --> DEV_AUTO
    CHANGE_MGT --> QA_MANUAL
    CHANGE_MGT --> PROD_CAB

    DEV_AUTO --> DEV_NS
    QA_MANUAL --> QA_NS
    PROD_CAB --> PROD_NS

    DEV_NS --> FRONTEND
    QA_NS --> FRONTEND
    PROD_NS --> FRONTEND

    %% Discovery Flow
    DISCOVERY --> CLUSTER
    CLUSTER --> EKS_CI
    DEV_NS --> SVC_CI
    QA_NS --> SVC_CI
    PROD_NS --> SVC_CI
    EKS_CI --> REL
    SVC_CI --> REL

    %% Tracking
    DEV_NS --> DEPLOY_TRACK
    QA_NS --> DEPLOY_TRACK
    PROD_NS --> DEPLOY_TRACK

    style CODE fill:#e1f5ff
    style PR fill:#e1f5ff
    style MERGE fill:#e1f5ff

    style SEC_SCAN fill:#fff4e6
    style DEPLOY fill:#fff4e6
    style DISCOVERY fill:#fff4e6

    style TRIVY fill:#ffe6e6
    style CODEQL fill:#ffe6e6
    style CHECKOV fill:#ffe6e6
    style GITLEAKS fill:#ffe6e6
    style SEMGREP fill:#ffe6e6

    style DEVOPS_SEC fill:#e8f5e9
    style CHANGE_MGT fill:#e8f5e9
    style DEPLOY_TRACK fill:#e8f5e9

    style EKS_CI fill:#f3e5f5
    style SVC_CI fill:#f3e5f5
    style REL fill:#f3e5f5

    style DEV_AUTO fill:#c8e6c9
    style QA_MANUAL fill:#fff9c4
    style PROD_CAB fill:#ffcdd2

    style CLUSTER fill:#e3f2fd
    style DEV_NS fill:#e3f2fd
    style QA_NS fill:#e3f2fd
    style PROD_NS fill:#e3f2fd
```

## Security Scan Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant Scanners as Security Scanners
    participant SN as ServiceNow
    participant VULN as Vulnerability Response

    Dev->>GH: Push code / Create PR
    GH->>GHA: Trigger security-scan workflow

    par Parallel Security Scans
        GHA->>Scanners: Trivy (containers)
        GHA->>Scanners: CodeQL (SAST)
        GHA->>Scanners: Checkov (IaC)
        GHA->>Scanners: Gitleaks (secrets)
        GHA->>Scanners: Semgrep (patterns)
    end

    Scanners-->>GHA: Scan results (SARIF/JSON)

    GHA->>GH: Upload to Security tab
    GHA->>SN: Upload to DevOps Security

    SN->>VULN: Create vulnerability records
    VULN->>VULN: Assess severity

    alt Critical vulnerabilities found
        VULN->>Dev: Block deployment notification
        VULN->>Dev: Remediation tasks created
    else No critical issues
        VULN->>GHA: Approve for deployment
    end
```

## Change Management Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GHA as GitHub Actions
    participant SN as ServiceNow
    participant Approval as Approvers
    participant EKS as AWS EKS

    Dev->>GHA: Trigger deployment workflow
    GHA->>GHA: Select environment (dev/qa/prod)
    GHA->>SN: Create change request

    alt Dev Environment
        SN->>SN: Auto-approve (dev policy)
        SN->>GHA: Deployment approved
    else QA Environment
        SN->>Approval: Request QA Lead approval
        Approval->>SN: Approve/Reject
        alt Approved
            SN->>GHA: Deployment approved
        else Rejected
            SN->>GHA: Deployment blocked
            GHA->>Dev: Notify rejection
        end
    else Prod Environment
        SN->>Approval: Request CAB approval
        Note over Approval: Change Manager<br/>App Owner<br/>Security Team
        Approval->>SN: All approve/reject
        alt All approved
            SN->>GHA: Deployment approved
        else Any rejected
            SN->>GHA: Deployment blocked
            GHA->>Dev: Notify rejection
        end
    end

    GHA->>GHA: Run pre-deployment checks
    GHA->>EKS: Deploy via kubectl/Kustomize
    EKS-->>GHA: Deployment status

    alt Deployment successful
        GHA->>SN: Update change - success
        GHA->>SN: Update CMDB
        SN->>SN: Close change request
        SN->>Dev: Notify success
    else Deployment failed
        GHA->>EKS: Rollback deployment
        GHA->>SN: Update change - failed
        SN->>Dev: Notify failure + logs
    end
```

## EKS Discovery Flow

```mermaid
sequenceDiagram
    participant Schedule as Scheduled Trigger
    participant GHA as GitHub Actions
    participant AWS as AWS APIs
    participant K8s as Kubernetes API
    participant SN as ServiceNow CMDB

    Schedule->>GHA: Every 6 hours (or manual)
    GHA->>AWS: Describe EKS cluster
    AWS-->>GHA: Cluster metadata

    GHA->>GHA: Extract cluster info
    Note over GHA: Name, Version, ARN<br/>Endpoint, VPC, Status

    GHA->>K8s: List namespaces
    K8s-->>GHA: dev, qa, prod namespaces

    loop For each namespace
        GHA->>K8s: Get deployments
        K8s-->>GHA: Deployment details
        GHA->>GHA: Extract service info
        Note over GHA: Name, Replicas, Image<br/>Status, Labels
    end

    GHA->>SN: Check if cluster exists
    alt Cluster exists
        GHA->>SN: Update cluster CI
    else New cluster
        GHA->>SN: Create cluster CI
    end

    loop For each microservice
        GHA->>SN: Check if service exists
        alt Service exists
            GHA->>SN: Update service CI
        else New service
            GHA->>SN: Create service CI
        end
    end

    GHA->>SN: Update relationships
    Note over SN: Link services to cluster<br/>Link to change requests

    SN-->>GHA: CMDB updated successfully
    GHA->>GHA: Generate discovery report
```

## Environment-Specific Approval Matrix

```mermaid
graph LR
    subgraph "Dev Environment"
        DEV_CHG[Change Request]
        DEV_AUTO[Auto-Approval]
        DEV_DEPLOY[Deploy Immediately]

        DEV_CHG --> DEV_AUTO --> DEV_DEPLOY
    end

    subgraph "QA Environment"
        QA_CHG[Change Request]
        QA_WAIT[Wait for Approval]
        QA_LEAD[QA Lead]
        QA_DEPLOY[Deploy on Approval]

        QA_CHG --> QA_WAIT
        QA_WAIT --> QA_LEAD
        QA_LEAD -->|Approve| QA_DEPLOY
        QA_LEAD -->|Reject| QA_BLOCKED[Deployment Blocked]
    end

    subgraph "Prod Environment"
        PROD_CHG[Change Request]
        PROD_WAIT[Wait for All Approvals]
        PROD_CM[Change Manager]
        PROD_AO[App Owner]
        PROD_SEC[Security Team]
        PROD_DEPLOY[Deploy on All Approved]

        PROD_CHG --> PROD_WAIT
        PROD_WAIT --> PROD_CM
        PROD_WAIT --> PROD_AO
        PROD_WAIT --> PROD_SEC
        PROD_CM --> PROD_CHECK{All Approved?}
        PROD_AO --> PROD_CHECK
        PROD_SEC --> PROD_CHECK
        PROD_CHECK -->|Yes| PROD_DEPLOY
        PROD_CHECK -->|No| PROD_BLOCKED[Deployment Blocked]
    end

    style DEV_AUTO fill:#c8e6c9
    style QA_LEAD fill:#fff9c4
    style PROD_CM fill:#ffcdd2
    style PROD_AO fill:#ffcdd2
    style PROD_SEC fill:#ffcdd2
    style QA_BLOCKED fill:#ffcccc
    style PROD_BLOCKED fill:#ffcccc
```

## Data Flow: Security Scan Results

```mermaid
graph TD
    A[Security Scan Triggered] --> B{Scan Type}

    B -->|Trivy| C1[Container Image Scan]
    B -->|CodeQL| C2[SAST - 5 Languages]
    B -->|Checkov| C3[IaC Security]
    B -->|Gitleaks| C4[Secret Detection]
    B -->|Semgrep| C5[Pattern Analysis]

    C1 --> D1[SARIF Output]
    C2 --> D2[SARIF Output]
    C3 --> D3[JSON Output]
    C4 --> D4[JSON Output]
    C5 --> D5[SARIF Output]

    D1 --> E[GitHub Security Tab]
    D2 --> E
    D3 --> E
    D4 --> E
    D5 --> E

    D1 --> F[Transform to ServiceNow Format]
    D2 --> F
    D3 --> F
    D4 --> F
    D5 --> F

    F --> G[ServiceNow DevOps Security]

    G --> H{Severity Check}

    H -->|Critical| I1[Create High Priority Vulnerability]
    H -->|High| I2[Create Medium Priority Vulnerability]
    H -->|Medium/Low| I3[Create Low Priority Vulnerability]

    I1 --> J[Block Deployment]
    I2 --> K[Require Approval]
    I3 --> L[Allow with Warning]

    J --> M[Notify Development Team]
    K --> M
    L --> M

    I1 --> N[Create Remediation Tasks]
    I2 --> N
    I3 --> O[Optional: Create Tasks]

    style A fill:#e1f5ff
    style J fill:#ffcccc
    style K fill:#fff9c4
    style L fill:#c8e6c9
```

## CMDB Structure

```mermaid
erDiagram
    EKS_CLUSTER ||--o{ MICROSERVICE : contains
    EKS_CLUSTER ||--o{ NODE_GROUP : has
    EKS_CLUSTER ||--|| VPC : runs-in
    MICROSERVICE ||--o{ POD : deployed-as
    MICROSERVICE ||--|| NAMESPACE : belongs-to
    MICROSERVICE ||--|| IMAGE : uses
    CHANGE_REQUEST ||--o{ MICROSERVICE : deploys-to
    CHANGE_REQUEST ||--|| EKS_CLUSTER : targets
    VULNERABILITY ||--o{ MICROSERVICE : affects

    EKS_CLUSTER {
        string name
        string arn
        string version
        string endpoint
        string region
        string vpc_id
        string status
        datetime last_discovered
    }

    MICROSERVICE {
        string name
        string namespace
        string environment
        int replicas
        int ready_replicas
        string image
        string image_tag
        string status
        datetime last_discovered
    }

    NAMESPACE {
        string name
        string environment
        string resource_quota
    }

    NODE_GROUP {
        string name
        string instance_type
        int desired_size
        int min_size
        int max_size
    }

    CHANGE_REQUEST {
        string number
        string state
        string environment
        datetime scheduled_date
        string approval_status
    }

    VULNERABILITY {
        string id
        string severity
        string scanner
        string cve_id
        string remediation
        string status
    }
```

## Timeline: 4-Week Implementation

```mermaid
gantt
    title ServiceNow Integration Implementation Timeline
    dateFormat YYYY-MM-DD

    section Week 1: Foundation
    ServiceNow Plugin Installation :a1, 2025-10-15, 2d
    Create Service Accounts :a2, after a1, 1d
    Configure GitHub Integration :a3, after a2, 1d
    Create CMDB CI Classes :a4, after a3, 1d

    section Week 2: Security Integration
    Add GitHub Secrets :b1, 2025-10-22, 1d
    Create Security Scan Workflow :b2, after b1, 2d
    Test Security Submissions :b3, after b2, 1d
    Configure Security Gates :b4, after b3, 1d

    section Week 2-3: Change Management
    Create Dev Workflow :c1, 2025-10-24, 2d
    Configure Dev Auto-Approval :c2, after c1, 1d
    Create QA Workflow :c3, after c2, 2d
    Configure QA Manual Approval :c4, after c3, 1d
    Create Prod Workflow :c5, after c4, 2d

    section Week 3: Discovery
    Install AWS Connector :d1, 2025-10-29, 1d
    Create Discovery Workflow :d2, after d1, 2d
    Test CMDB Population :d3, after d2, 1d
    Validate Data Accuracy :d4, after d3, 1d

    section Week 4: Testing & Launch
    End-to-End Testing :e1, 2025-11-05, 3d
    Team Training :e2, after e1, 2d
    Production Launch :milestone, after e2, 0d
    Monitor & Iterate :e3, after e2, 5d
```

## Component Interaction Matrix

| Component | GitHub Actions | ServiceNow | AWS EKS | Purpose |
|-----------|---------------|------------|---------|---------|
| **Security Scanners** | ✅ Runs | ✅ Receives | ❌ | Vulnerability detection |
| **Change Requests** | ✅ Creates | ✅ Manages | ❌ | Approval workflow |
| **Deployment** | ✅ Executes | ✅ Tracks | ✅ Receives | Application deployment |
| **CMDB Discovery** | ✅ Discovers | ✅ Stores | ✅ Scans | Infrastructure inventory |
| **Approval Workflows** | ✅ Waits | ✅ Processes | ❌ | Governance |
| **Rollback** | ✅ Triggers | ✅ Updates | ✅ Executes | Failure recovery |

## Legend

- 🔵 GitHub Components
- 🟢 ServiceNow Components
- 🔷 AWS Components
- 🔴 Security Components
- 🟡 Approval Components
- ⚠️ Critical Path
- ✅ Success Flow
- ❌ Failure/Block Flow

---

**Note**: All diagrams are written in Mermaid syntax and can be rendered in:
- GitHub Markdown (native support)
- VS Code with Mermaid extension
- Mermaid Live Editor (https://mermaid.live)
