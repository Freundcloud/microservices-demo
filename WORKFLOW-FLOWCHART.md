# Complete CI/CD Workflow Flowchart

> **Status**: Target Architecture (After Consolidation Complete)
> **Entry Point**: `just promote 1.1.8 all`

---

## High-Level Flow

```mermaid
flowchart TD
    Start([Developer runs: just promote 1.1.8 all]) --> Script[scripts/promote-version.sh]

    Script --> CreateBranch[Create release/v1.1.8 branch]
    CreateBranch --> UpdateKustomize[Update kustomization files<br/>dev/qa/prod to use env tags]
    UpdateKustomize --> Commit[Commit changes]
    Commit --> CreatePR[Create Pull Request]

    CreatePR --> WaitCI{CI Checks<br/>Passing?}
    WaitCI -->|No| FixIssues[Fix issues & push]
    FixIssues --> WaitCI
    WaitCI -->|Yes| AutoApprove[Auto-approve PR]

    AutoApprove --> MergePR[Merge PR to main<br/>Delete branch]
    MergePR --> TriggerPipeline[Trigger MASTER-PIPELINE<br/>automatic on push to main]

    TriggerPipeline --> DevDeploy[DEV Deployment]
    DevDeploy --> QAPrompt{User approves<br/>QA deploy?}
    QAPrompt -->|No| SkipQA[Skip QA]
    QAPrompt -->|Yes| QADeploy[QA Deployment]

    QADeploy --> ProdPrompt{User approves<br/>PROD deploy?}
    SkipQA --> ProdPrompt
    ProdPrompt -->|No| End([Complete])
    ProdPrompt -->|Yes| ProdDeploy[PROD Deployment]

    ProdDeploy --> CreateRelease[Create GitHub Release]
    CreateRelease --> End

    style Start fill:#90EE90
    style End fill:#87CEEB
    style DevDeploy fill:#FFE4B5
    style QADeploy fill:#FFE4B5
    style ProdDeploy fill:#FFE4B5
    style WaitCI fill:#FFD700
    style QAPrompt fill:#FFD700
    style ProdPrompt fill:#FFD700
```

---

## Detailed MASTER-PIPELINE Flow

```mermaid
flowchart TD
    Trigger([Push to main or<br/>Manual workflow_dispatch]) --> Init[Pipeline Init<br/>Determine environment]

    Init --> Policy{Branch Policy<br/>Check}
    Policy -->|Fail| BlockDeploy[❌ Block Deployment<br/>qa/prod require release/* branch]
    Policy -->|Pass| ParallelStart[ ]

    ParallelStart --> Validate[Code Validation<br/>Kustomize, YAML lint]
    ParallelStart --> Security[Security Scanning<br/>CodeQL, Trivy, Gitleaks]

    Validate --> ParallelEnd1[ ]
    Security --> ParallelEnd1

    ParallelEnd1 --> TFCheck{Terraform<br/>Changes?}
    TFCheck -->|Yes| TFPlan[Terraform Plan]
    TFCheck -->|No| ServiceCheck
    TFPlan --> TFApply{Apply<br/>Infrastructure?}
    TFApply -->|Yes| TFDo[Terraform Apply]
    TFApply -->|No| ServiceCheck
    TFDo --> ServiceCheck

    ServiceCheck{Service<br/>Changes?} -->|Yes| Build[Build Docker Images<br/>Smart change detection]
    ServiceCheck -->|No| DeployCheck

    Build --> BuildSuccess{Build<br/>Success?}
    BuildSuccess -->|No| Failed([❌ Pipeline Failed])
    BuildSuccess -->|Yes| ParallelSN[ ]

    ParallelSN --> UploadTests[Upload Test Results<br/>to ServiceNow]
    ParallelSN --> RegisterPkg[Register Packages<br/>in ServiceNow]

    UploadTests --> SNComplete[ ]
    RegisterPkg --> SNComplete

    SNComplete --> DeployCheck{Should<br/>Deploy?}
    DeployCheck -->|No PR| SNChange[Create ServiceNow<br/>Change Request]
    DeployCheck -->|PR| SkipDeploy([ℹ️ Build Only])

    SNChange --> AutoApprove{Environment<br/>= dev?}
    AutoApprove -->|Yes| DevCR[CR State: implement<br/>✅ Auto-Approved]
    AutoApprove -->|No| ManualCR[CR State: assess<br/>⏸️ Awaiting Approval]

    DevCR --> K8sDeploy
    ManualCR --> WaitApproval{ServiceNow<br/>Approved?}
    WaitApproval -->|Timeout| Failed
    WaitApproval -->|Yes| K8sDeploy

    K8sDeploy[Deploy to Kubernetes<br/>kubectl apply -k overlays/ENV] --> Rollout[Wait for Rollout<br/>10 minute timeout]

    Rollout --> RolloutOK{Rollout<br/>Success?}
    RolloutOK -->|No| Failed
    RolloutOK -->|Yes| UploadConfig[Upload Config<br/>to ServiceNow]

    UploadConfig --> Smoke[Smoke Tests<br/>Pod health, frontend URL]

    Smoke --> SmokeOK{Smoke Tests<br/>Pass?}
    SmokeOK -->|No| Failed
    SmokeOK -->|Yes| IsProd{Environment<br/>= prod?}

    IsProd -->|Yes| CreateTag[Create Git Tag<br/>GitHub Release]
    IsProd -->|No| Summary
    CreateTag --> IsRelease{On release/*<br/>branch?}
    IsRelease -->|Yes| Backmerge[Create Backmerge PR<br/>to main]
    IsRelease -->|No| Summary
    Backmerge --> Summary

    Summary[Pipeline Summary<br/>with ServiceNow details] --> Success([✅ Deployment Complete])

    style Trigger fill:#90EE90
    style Success fill:#87CEEB
    style Failed fill:#FFB6C1
    style SkipDeploy fill:#D3D3D3
    style BlockDeploy fill:#FFB6C1
    style DevCR fill:#98FB98
    style ManualCR fill:#FFE4B5
    style AutoApprove fill:#FFD700
    style Policy fill:#FFD700
    style TFCheck fill:#FFD700
    style ServiceCheck fill:#FFD700
    style BuildSuccess fill:#FFD700
    style DeployCheck fill:#FFD700
    style WaitApproval fill:#FFD700
    style RolloutOK fill:#FFD700
    style SmokeOK fill:#FFD700
    style IsProd fill:#FFD700
    style IsRelease fill:#FFD700
```

---

## ServiceNow Integration Flow

```mermaid
flowchart TD
    Build[Build Complete] --> Tests[Collect Test Results]

    Tests --> UploadTests[ServiceNow Action:<br/>servicenow-devops-test-report]
    UploadTests --> TestsUploaded[(ServiceNow<br/>Test Results Table)]

    Build --> Artifacts[Collect Docker Images]
    Artifacts --> RegisterPkg[ServiceNow Action:<br/>servicenow-devops-register-package]
    RegisterPkg --> PkgsRegistered[(ServiceNow<br/>Package Table)]

    TestsUploaded --> ReadyToDeploy[ ]
    PkgsRegistered --> ReadyToDeploy

    ReadyToDeploy --> CreateCR[ServiceNow Action:<br/>servicenow-devops-change]

    CreateCR --> CheckEnv{Environment?}
    CheckEnv -->|dev| DevCR[Create CR with:<br/>state: implement<br/>priority: 3<br/>auto-approved: true]
    CheckEnv -->|qa| QACR[Create CR with:<br/>state: assess<br/>priority: 3<br/>requires approval]
    CheckEnv -->|prod| ProdCR[Create CR with:<br/>state: assess<br/>priority: 2<br/>requires approval]

    DevCR --> CRCreated[(ServiceNow<br/>Change Request)]
    QACR --> CRCreated
    ProdCR --> CRCreated

    CRCreated --> AutoCheck{Auto-approved?}
    AutoCheck -->|Yes DEV| DeployNow[Deployment Proceeds]
    AutoCheck -->|No QA/PROD| WaitApproval[Wait for Manual<br/>Approval in ServiceNow]

    WaitApproval --> Poll{Check every<br/>100 seconds}
    Poll -->|Approved| DeployNow
    Poll -->|Timeout 1hr| Abort([❌ Deployment Aborted])

    DeployNow --> K8sDeploy[Kubernetes Deployment]
    K8sDeploy --> CollectConfig[Collect Kustomize Configs]

    CollectConfig --> UploadConfig[ServiceNow Action:<br/>servicenow-devops-config-validate]
    UploadConfig --> ConfigUploaded[(ServiceNow<br/>Config Snapshot)]

    ConfigUploaded --> Complete([Deployment Complete<br/>All Evidence in ServiceNow])

    style Build fill:#90EE90
    style Complete fill:#87CEEB
    style Abort fill:#FFB6C1
    style DevCR fill:#98FB98
    style QACR fill:#FFE4B5
    style ProdCR fill:#FFE4B5
    style WaitApproval fill:#FFD700
    style TestsUploaded fill:#E0E0E0
    style PkgsRegistered fill:#E0E0E0
    style CRCreated fill:#E0E0E0
    style ConfigUploaded fill:#E0E0E0
```

---

## Environment Promotion Flow

```mermaid
flowchart LR
    Dev[DEV Environment<br/>Tag: dev] -->|Promote| QA[QA Environment<br/>Tag: qa]
    QA -->|Promote| Prod[PROD Environment<br/>Tag: prod]

    Dev --> DevCR[ServiceNow CR<br/>✅ Auto-Approved]
    QA --> QACR[ServiceNow CR<br/>⏸️ Awaiting Approval]
    Prod --> ProdCR[ServiceNow CR<br/>⏸️ Awaiting Approval]

    DevCR --> DevDeploy[Deploy to<br/>microservices-dev]
    QACR --> QAApprove{Approve<br/>in ServiceNow?}
    ProdCR --> ProdApprove{Approve<br/>in ServiceNow?}

    QAApprove -->|Yes| QADeploy[Deploy to<br/>microservices-qa]
    ProdApprove -->|Yes| ProdDeploy[Deploy to<br/>microservices-prod]

    QAApprove -->|No/Timeout| QAAbort([❌ QA Deployment<br/>Aborted])
    ProdApprove -->|No/Timeout| ProdAbort([❌ PROD Deployment<br/>Aborted])

    DevDeploy --> DevEvidence[(ServiceNow Evidence:<br/>Tests, Packages,<br/>CR, Config)]
    QADeploy --> QAEvidence[(ServiceNow Evidence:<br/>Tests, Packages,<br/>CR, Config)]
    ProdDeploy --> ProdEvidence[(ServiceNow Evidence:<br/>Tests, Packages,<br/>CR, Config)]

    ProdDeploy --> Release[Create GitHub<br/>Release Tag]

    style Dev fill:#90EE90
    style QA fill:#FFE4B5
    style Prod fill:#FFB6C1
    style DevCR fill:#98FB98
    style QACR fill:#FFD700
    style ProdCR fill:#FFD700
    style DevDeploy fill:#87CEEB
    style QADeploy fill:#87CEEB
    style ProdDeploy fill:#87CEEB
    style Release fill:#87CEEB
    style QAAbort fill:#FFB6C1
    style ProdAbort fill:#FFB6C1
```

---

## Image Tagging Flow

```mermaid
flowchart TD
    Code[Code Changes] --> Build[Build Docker Images]

    Build --> DevBuild[Build for DEV]
    DevBuild --> DevTag1[Tag: frontend:dev]
    DevBuild --> DevTag2[Tag: frontend:dev-abc123def]

    DevTag1 --> PushDev[Push to ECR]
    DevTag2 --> PushDev

    PushDev --> DevDeploy[Deploy to DEV<br/>using frontend:dev]

    DevDeploy --> QAPrompt{Promote<br/>to QA?}
    QAPrompt -->|Yes| QARetag[Pull: frontend:dev<br/>Tag as: frontend:qa]
    QARetag --> QATag2[Tag: frontend:qa-abc123def]
    QATag2 --> PushQA[Push to ECR]
    PushQA --> QADeploy[Deploy to QA<br/>using frontend:qa]

    QADeploy --> ProdPrompt{Promote<br/>to PROD?}
    ProdPrompt -->|Yes| ProdRetag[Pull: frontend:qa<br/>Tag as: frontend:prod]
    ProdRetag --> ProdTag2[Tag: frontend:prod-abc123def]
    ProdTag2 --> PushProd[Push to ECR]
    PushProd --> ProdDeploy[Deploy to PROD<br/>using frontend:prod]

    ProdDeploy --> ReleaseTag[Create Release Tag<br/>v1.0.0-prod-abc123def]

    style Code fill:#90EE90
    style DevDeploy fill:#E0FFE0
    style QADeploy fill:#FFFACD
    style ProdDeploy fill:#FFE4E1
    style ReleaseTag fill:#87CEEB
    style QAPrompt fill:#FFD700
    style ProdPrompt fill:#FFD700
```

---

## Job Dependency Graph

```mermaid
graph TD
    Init[pipeline-init] --> Validate[validate-code]
    Init --> Security[security-scans]
    Init --> TFDetect[detect-terraform-changes]
    Init --> SvcDetect[detect-service-changes]

    TFDetect --> TFPlan[terraform-plan]
    Security --> TFPlan
    TFPlan --> TFApply[terraform-apply]

    SvcDetect --> Build[build-and-push]
    Security --> Build

    Build --> Tests[upload-test-results]
    Build --> Packages[register-packages]

    Tests --> SNChange[servicenow-change]
    Packages --> SNChange

    SNChange --> Deploy[deploy-to-environment]

    Deploy --> UploadCfg[upload-config-to-servicenow]

    UploadCfg --> Smoke[smoke-tests]

    Smoke --> Release[create-github-release]
    Smoke --> Backmerge[backmerge-release-to-main]

    Release --> Summary[pipeline-summary]
    Backmerge --> Summary

    Init -.-> Summary
    Security -.-> Summary
    TFDetect -.-> Summary
    SvcDetect -.-> Summary
    Build -.-> Summary
    Tests -.-> Summary
    Packages -.-> Summary
    SNChange -.-> Summary
    Deploy -.-> Summary
    UploadCfg -.-> Summary
    Smoke -.-> Summary

    style Init fill:#90EE90
    style Summary fill:#87CEEB
    style Security fill:#FFB6C1
    style SNChange fill:#FFE4B5
    style Deploy fill:#98FB98
    style Release fill:#87CEEB
```

---

## Automated Promotion Script Flow

```mermaid
flowchart TD
    Start([just promote 1.1.8 all]) --> Checkout[git checkout main<br/>git pull origin main]

    Checkout --> CreateBranch[git checkout -b release/v1.1.8]

    CreateBranch --> UpdateDev[Update kustomize/overlays/dev:<br/>newTag: dev]
    UpdateDev --> UpdateQA[Update kustomize/overlays/qa:<br/>newTag: qa]
    UpdateQA --> UpdateProd[Update kustomize/overlays/prod:<br/>newTag: prod]

    UpdateProd --> Commit[git commit -m<br/>'chore: Promote to version 1.1.8']

    Commit --> Push[git push origin release/v1.1.8]

    Push --> CreatePR[gh pr create<br/>--base main<br/>--head release/v1.1.8]

    CreatePR --> WaitCI[Wait for CI checks<br/>gh pr checks --watch]

    WaitCI --> CIPassed{CI Checks<br/>Passed?}
    CIPassed -->|No| ShowError[Show error<br/>Exit with instructions]
    CIPassed -->|Yes| AutoReview[gh pr review --approve]

    AutoReview --> AutoMerge[gh pr merge --squash<br/>--delete-branch --auto]

    AutoMerge --> UpdateMain[git checkout main<br/>git pull origin main]

    UpdateMain --> WaitPipeline[Wait for MASTER-PIPELINE<br/>to start on push to main]

    WaitPipeline --> DevRun[Get DEV workflow run ID<br/>gh run list --limit 1]

    DevRun --> WatchDev[Watch DEV deployment<br/>gh run watch RUN_ID]

    WatchDev --> DevDone{DEV<br/>Success?}
    DevDone -->|No| DevFailed([❌ DEV Failed])
    DevDone -->|Yes| DevComplete[✅ DEV Deployment Complete<br/>ServiceNow CR Auto-Approved]

    DevComplete --> PromptQA{Prompt:<br/>Deploy to QA?}
    PromptQA -->|No| SkipQA[Skip QA]
    PromptQA -->|Yes| TriggerQA[gh workflow run MASTER-PIPELINE<br/>-f environment=qa]

    TriggerQA --> WatchQA[Watch QA deployment<br/>gh run watch RUN_ID]

    WatchQA --> QAApproval[⏸️ Waiting for<br/>ServiceNow CR Approval]

    QAApproval --> QADone{QA<br/>Success?}
    QADone -->|No| QAFailed([❌ QA Failed])
    QADone -->|Yes| QAComplete[✅ QA Deployment Complete]

    QAComplete --> PromptProd
    SkipQA --> PromptProd

    PromptProd{Prompt:<br/>Deploy to PROD?}
    PromptProd -->|No| Complete
    PromptProd -->|Yes| TriggerProd[gh workflow run MASTER-PIPELINE<br/>-f environment=prod]

    TriggerProd --> WatchProd[Watch PROD deployment<br/>gh run watch RUN_ID]

    WatchProd --> ProdApproval[⏸️ Waiting for<br/>ServiceNow CR Approval]

    ProdApproval --> ProdDone{PROD<br/>Success?}
    ProdDone -->|No| ProdFailed([❌ PROD Failed])
    ProdDone -->|Yes| ProdComplete[✅ PROD Deployment Complete<br/>GitHub Release Created]

    ProdComplete --> Complete

    Complete([🎉 Version Promotion Complete<br/>Show Summary])

    style Start fill:#90EE90
    style Complete fill:#87CEEB
    style DevFailed fill:#FFB6C1
    style QAFailed fill:#FFB6C1
    style ProdFailed fill:#FFB6C1
    style ShowError fill:#FFB6C1
    style DevComplete fill:#98FB98
    style QAComplete fill:#FFE4B5
    style ProdComplete fill:#FFE4B5
    style PromptQA fill:#FFD700
    style PromptProd fill:#FFD700
    style CIPassed fill:#FFD700
    style DevDone fill:#FFD700
    style QADone fill:#FFD700
    style ProdDone fill:#FFD700
    style QAApproval fill:#FFD700
    style ProdApproval fill:#FFD700
```

---

## Comparison: Before vs After

### Before (Broken)

```mermaid
flowchart TD
    User[User runs:<br/>just promote-all 1.1.8] --> UpdateDev[Update dev kustomization<br/>newTag: 1.1.8]
    UpdateDev --> CommitDev[Commit to main]
    CommitDev --> FullPromo[Trigger: full-promotion-pipeline]

    FullPromo --> UpdateQA[Update qa kustomization<br/>newTag: 1.1.8]
    UpdateQA --> PromoQA[Trigger: promote-environments QA]
    PromoQA --> DeployQA[Trigger: deploy-environment QA]

    DeployQA --> ImagePull[kubectl apply -k overlays/qa]
    ImagePull --> Error[❌ ImagePullBackOff<br/>Image frontend:1.1.8 not found!]

    style User fill:#90EE90
    style Error fill:#FFB6C1
```

**Problems**:
- ❌ Semantic version tags (1.1.8) don't exist in ECR
- ❌ Multiple workflows (full-promotion-pipeline, promote-environments, deploy-environment)
- ❌ Broken logic spread across files
- ❌ No ServiceNow integration in MASTER-PIPELINE
- ❌ Manual git commits to main (no PR review)

### After (Fixed)

```mermaid
flowchart TD
    User[User runs:<br/>just promote 1.1.8 all] --> Script[scripts/promote-version.sh]
    Script --> PR[Create PR with<br/>environment tags: dev/qa/prod]
    PR --> Merge[Auto-merge after CI]
    Merge --> Master[MASTER-PIPELINE<br/>with ServiceNow integration]

    Master --> DevOK[✅ DEV deployed<br/>frontend:dev from ECR]
    DevOK --> QAOK[✅ QA deployed<br/>frontend:qa from ECR]
    QAOK --> ProdOK[✅ PROD deployed<br/>frontend:prod from ECR]

    style User fill:#90EE90
    style DevOK fill:#98FB98
    style QAOK fill:#98FB98
    style ProdOK fill:#98FB98
```

**Benefits**:
- ✅ Environment tags that exist in ECR
- ✅ Single workflow (MASTER-PIPELINE)
- ✅ Complete ServiceNow integration
- ✅ Proper PR workflow with CI checks
- ✅ Automated promotion script

---

## Legend

```mermaid
flowchart LR
    Start([Entry Point]) --> Decision{Decision Point}
    Decision -->|Yes| Success([Success])
    Decision -->|No| Failure([Failure])

    Success --> Process[Process Step]
    Process --> Data[(Data Store)]

    style Start fill:#90EE90
    style Success fill:#87CEEB
    style Failure fill:#FFB6C1
    style Decision fill:#FFD700
    style Data fill:#E0E0E0
```

**Colors**:
- 🟢 Green: Start/trigger points
- 🔵 Blue: Success/completion
- 🔴 Pink: Failure/error states
- 🟡 Yellow: Decision points/waiting states
- ⚪ Gray: Data stores (ServiceNow tables)
- 🟠 Orange: Manual approval required
- 🟣 Light green: Automated approvals

---

## Key Takeaways

**Automation Points**:
1. ✅ Feature branch creation
2. ✅ Kustomization file updates
3. ✅ PR creation and merge
4. ✅ DEV deployment (auto-approved)
5. ⏸️ QA deployment (manual trigger + ServiceNow approval)
6. ⏸️ PROD deployment (manual trigger + ServiceNow approval)
7. ✅ GitHub release creation

**ServiceNow Touchpoints**:
1. Test results upload (after build)
2. Package registration (after build)
3. Change Request creation (before deployment)
4. Config upload (after deployment)

**Manual Intervention Points**:
1. QA deployment approval (in ServiceNow)
2. PROD deployment approval (in ServiceNow)
3. Optional: Skip QA/PROD in promotion script

**Safety Gates**:
1. CI checks must pass before PR merge
2. Branch policy enforcement (qa/prod require release/* branches)
3. ServiceNow CR approval for qa/prod
4. Rollout status monitoring
5. Smoke tests before marking success
