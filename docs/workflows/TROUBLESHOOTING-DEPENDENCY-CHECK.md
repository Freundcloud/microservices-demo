# Troubleshooting OWASP Dependency-Check Action

> **Purpose**: Resolve common issues with OWASP Dependency-Check in GitHub Actions
> **Related Workflow**: `.github/workflows/security-scan-servicenow.yaml`
> **Last Updated**: 2025-10-16

## Table of Contents

1. [Quick Fixes](#quick-fixes)
2. [Common Errors](#common-errors)
3. [Configuration Solutions](#configuration-solutions)
4. [Alternative Approaches](#alternative-approaches)
5. [Monitoring and Validation](#monitoring-and-validation)

---

## Quick Fixes

### Current Error Summary

The workflow is encountering these issues:

1. **Maven Central Connectivity** - HTTP 502 errors when reaching Maven Central
2. **Missing Node Modules** - Scanner can't analyze Node.js dependencies without `node_modules/`
3. **OSS Index Authentication** - Missing credentials for comprehensive scanning

### Immediate Solutions

#### Option 1: Configure Dependency-Check Properly (Recommended)

Update the `owasp-dependency-check` job in [security-scan-servicenow.yaml:298-320](/.github/workflows/security-scan-servicenow.yaml#L298-L320):

```yaml
owasp-dependency-check:
  name: OWASP Dependency Check
  runs-on: ubuntu-latest

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    # Install Node.js dependencies before scanning
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '22'
        cache: 'npm'

    - name: Install Node.js Dependencies
      run: |
        # Install dependencies for Node.js services
        for service in currencyservice paymentservice; do
          if [ -f "src/$service/package-lock.json" ]; then
            echo "Installing dependencies for $service..."
            cd "src/$service"
            npm ci --ignore-scripts
            cd ../..
          fi
        done
      continue-on-error: true

    # Setup Java for Java services
    - name: Setup Java 21
      uses: actions/setup-java@v4
      with:
        distribution: 'temurin'
        java-version: '21'

    - name: Run OWASP Dependency Check
      uses: dependency-check/Dependency-Check_Action@main
      with:
        project: 'online-boutique'
        path: 'src/'
        format: 'SARIF'
        out: 'dependency-check-report'
        # Add arguments to improve reliability
        args: >-
          --enableRetired
          --suppression .github/dependency-check-suppressions.xml
          --nodeAuditSkipDevDependencies
          --nodePackageSkipDevDependencies
          --failOnCVSS 7
          --log dependency-check.log
      env:
        # Optional: Add OSS Index credentials for more comprehensive scanning
        OSSINDEX_USER: ${{ secrets.OSSINDEX_USER }}
        OSSINDEX_TOKEN: ${{ secrets.OSSINDEX_TOKEN }}
      continue-on-error: true

    - name: Upload Dependency-Check Log
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: dependency-check-log
        path: dependency-check.log

    - name: Upload Results to GitHub
      uses: github/codeql-action/upload-sarif@v3
      if: always() && hashFiles('dependency-check-report/dependency-check-report.sarif') != ''
      with:
        sarif_file: dependency-check-report/dependency-check-report.sarif
        category: owasp-dependency-check
      continue-on-error: true

    - name: Upload Dependency-Check results to ServiceNow
      if: always() && env.SN_DEVOPS_TOKEN != '' && hashFiles('dependency-check-report/dependency-check-report.sarif') != ''
      uses: ServiceNow/servicenow-devops-security-result@v3.1.0
      with:
        devops-integration-token: ${{ secrets.SN_DEVOPS_INTEGRATION_TOKEN }}
        instance-url: ${{ secrets.SN_INSTANCE_URL }}
        tool-id: ${{ secrets.SN_ORCHESTRATION_TOOL_ID }}
        context-github: ${{ toJSON(github) }}
        job-name: 'OWASP Dependency Check'
        security-result-attributes: |
          {
            "scanner": "OWASP Dependency-Check",
            "applicationName": "microservices-demo",
            "securityToolId": "owasp-dependency-check",
            "scanType": "Dependency Vulnerability"
          }
        security-result-file: 'dependency-check-report/dependency-check-report.sarif'
      continue-on-error: true
```

#### Option 2: Use Language-Specific Scanners (Alternative)

Replace OWASP Dependency-Check with specialized tools that are more reliable:

```yaml
# For Node.js services - npm audit
nodejs-audit:
  name: Node.js Security Audit
  runs-on: ubuntu-latest

  strategy:
    matrix:
      service: [currencyservice, paymentservice]

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '22'

    - name: Run npm audit
      run: |
        cd src/${{ matrix.service }}
        npm audit --json > ../../audit-${{ matrix.service }}.json || true
        npm audit --audit-level=moderate
      continue-on-error: true

    - name: Upload npm audit results
      uses: actions/upload-artifact@v4
      with:
        name: npm-audit-${{ matrix.service }}
        path: audit-${{ matrix.service }}.json

# For Java services - Snyk or GitHub Dependency Scanning
java-dependency-scan:
  name: Java Dependency Scan
  runs-on: ubuntu-latest

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Setup Java 21
      uses: actions/setup-java@v4
      with:
        distribution: 'temurin'
        java-version: '21'

    - name: Build and scan adservice
      run: |
        cd src/adservice
        ./gradlew build dependencyCheckAnalyze --info
      continue-on-error: true

# For Python services - Safety or pip-audit
python-dependency-scan:
  name: Python Dependency Scan
  runs-on: ubuntu-latest

  strategy:
    matrix:
      service: [emailservice, recommendationservice]

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.12'

    - name: Install pip-audit
      run: pip install pip-audit

    - name: Run pip-audit
      run: |
        cd src/${{ matrix.service }}
        if [ -f "requirements.txt" ]; then
          pip-audit -r requirements.txt --format json > ../../audit-${{ matrix.service }}.json || true
        fi
      continue-on-error: true

    - name: Upload audit results
      uses: actions/upload-artifact@v4
      with:
        name: python-audit-${{ matrix.service }}
        path: audit-${{ matrix.service }}.json

# For Go services - govulncheck
go-vulnerability-scan:
  name: Go Vulnerability Scan
  runs-on: ubuntu-latest

  strategy:
    matrix:
      service: [frontend, productcatalogservice, shippingservice, checkoutservice]

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.22'

    - name: Install govulncheck
      run: go install golang.org/x/vuln/cmd/govulncheck@latest

    - name: Run govulncheck
      run: |
        cd src/${{ matrix.service }}
        govulncheck -json ./... > ../../vuln-${{ matrix.service }}.json || true
      continue-on-error: true

    - name: Upload vulnerability results
      uses: actions/upload-artifact@v4
      with:
        name: go-vuln-${{ matrix.service }}
        path: vuln-${{ matrix.service }}.json
```

---

## Common Errors

### Error 1: Maven Central Connection Failure

**Error Message:**
```
Could not connect to Central search. Analysis failed
java.io.IOException: https://search.maven.org/solrsearch/select - Server status: 502 - Server reason: Bad Gateway
```

**Root Cause:**
- Maven Central API is experiencing downtime or rate limiting
- Network connectivity issues from GitHub Actions runners
- Transient infrastructure problems at Maven Central

**Solutions:**

1. **Add Retry Logic:**
```yaml
- name: Run OWASP Dependency Check with Retry
  uses: nick-fields/retry@v3
  with:
    timeout_minutes: 30
    max_attempts: 3
    retry_wait_seconds: 120
    command: |
      docker run --rm \
        -v $(pwd):/src \
        owasp/dependency-check:latest \
        --project "online-boutique" \
        --scan /src/src/ \
        --format SARIF \
        --out /src/dependency-check-report \
        --enableRetired \
        --nodeAuditSkipDevDependencies
```

2. **Use Local NVD Data Cache:**
```yaml
- name: Cache NVD Database
  uses: actions/cache@v4
  with:
    path: ~/.gradle/dependency-check-data
    key: ${{ runner.os }}-nvd-${{ hashFiles('**/build.gradle') }}
    restore-keys: |
      ${{ runner.os }}-nvd-

- name: Run OWASP Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'
    args: '--data ~/.gradle/dependency-check-data'
```

3. **Disable Central Analyzer (Temporary):**
```yaml
- name: Run OWASP Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'
    args: '--disableCentral --enableRetired'
```

### Error 2: Missing node_modules Directory

**Error Message:**
```
Analyzing `/github/workspace/src/paymentservice/package-lock.json` - however, the node_modules directory does not exist. Please run `npm install` prior to running dependency-check
```

**Root Cause:**
- OWASP Dependency-Check expects installed dependencies to analyze
- `node_modules/` is not committed to Git (correctly ignored)

**Solutions:**

1. **Install Dependencies Before Scanning:**
```yaml
- name: Install Node.js Dependencies
  run: |
    services=("currencyservice" "paymentservice")
    for service in "${services[@]}"; do
      if [ -f "src/$service/package-lock.json" ]; then
        echo "Installing dependencies for $service..."
        cd "src/$service"
        npm ci --ignore-scripts --audit=false
        cd ../..
      fi
    done
```

2. **Use npm audit Instead:**
```yaml
- name: Node.js Security Audit
  run: |
    services=("currencyservice" "paymentservice")
    for service in "${services[@]}"; do
      cd "src/$service"
      npm audit --audit-level=moderate --json > "../../$service-audit.json" || true
      cd ../..
    done
```

### Error 3: OSS Index Authentication Warning

**Error Message:**
```
Disabling OSS Index analyzer due to missing user/password credentials. Authentication is now required: https://ossindex.sonatype.org/doc/auth-required
```

**Root Cause:**
- OSS Index now requires authentication for API access
- Enhanced security prevents anonymous high-volume scanning

**Solutions:**

1. **Register for OSS Index API:**
   - Go to https://ossindex.sonatype.org/user/register
   - Create free account
   - Get API token from account settings
   - Add to GitHub Secrets:
     - `OSSINDEX_USER`: your email
     - `OSSINDEX_TOKEN`: your API token

2. **Configure in Workflow:**
```yaml
- name: Run OWASP Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'
  env:
    OSSINDEX_USER: ${{ secrets.OSSINDEX_USER }}
    OSSINDEX_TOKEN: ${{ secrets.OSSINDEX_TOKEN }}
```

3. **Disable OSS Index (Not Recommended):**
```yaml
- name: Run OWASP Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'
    args: '--disableOssIndex'
```

---

## Configuration Solutions

### Create Suppressions File

Create `.github/dependency-check-suppressions.xml` to suppress false positives:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <!-- Suppress false positives for development dependencies -->
    <suppress>
        <notes>
            Development dependencies not included in production builds
        </notes>
        <filePath regex="true">.*node_modules.*</filePath>
    </suppress>

    <!-- Suppress known issues with mitigations in place -->
    <suppress>
        <notes>
            Example: CVE-2024-XXXX is not applicable because we use feature X
        </notes>
        <cve>CVE-2024-XXXX</cve>
    </suppress>

    <!-- Suppress low severity issues -->
    <suppress until="2025-12-31">
        <notes>
            Low severity issues deferred for next major release
        </notes>
        <cvssBelow>4.0</cvssBelow>
    </suppress>
</suppressions>
```

### Optimize Scan Performance

Create `.github/workflows/dependency-check-config.properties`:

```properties
# Cache NVD data for 12 hours (reduces API calls)
cve.check.valid.for.hours=12

# Disable unused analyzers for faster scans
analyzer.assembly.enabled=false
analyzer.msbuild.project.enabled=false
analyzer.nuspec.enabled=false
analyzer.nugetconf.enabled=false
analyzer.bundle.audit.enabled=false
analyzer.cocoapods.enabled=false
analyzer.swift.package.manager.enabled=false
analyzer.golang.dep.enabled=false
analyzer.golang.mod.enabled=true

# Enable Node.js analyzers
analyzer.node.package.enabled=true
analyzer.node.audit.enabled=true

# Enable Java analyzers
analyzer.jar.enabled=true
analyzer.central.enabled=true

# Database settings
data.directory=~/.gradle/dependency-check-data
db.driver.name=org.h2.Driver
```

Use in workflow:

```yaml
- name: Run OWASP Dependency Check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'
    args: '--propertyfile .github/workflows/dependency-check-config.properties'
```

---

## Alternative Approaches

### Approach 1: Use GitHub's Native Dependency Scanning

GitHub provides built-in dependency scanning via Dependabot:

1. **Enable Dependabot** in repository settings
2. **Configure** `.github/dependabot.yml`:

```yaml
version: 2
updates:
  # Node.js services
  - package-ecosystem: "npm"
    directory: "/src/currencyservice"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  - package-ecosystem: "npm"
    directory: "/src/paymentservice"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  # Go services
  - package-ecosystem: "gomod"
    directory: "/src/frontend"
    schedule:
      interval: "weekly"

  - package-ecosystem: "gomod"
    directory: "/src/productcatalogservice"
    schedule:
      interval: "weekly"

  # Python services
  - package-ecosystem: "pip"
    directory: "/src/emailservice"
    schedule:
      interval: "weekly"

  - package-ecosystem: "pip"
    directory: "/src/recommendationservice"
    schedule:
      interval: "weekly"

  # Java services
  - package-ecosystem: "gradle"
    directory: "/src/adservice"
    schedule:
      interval: "weekly"

  # Docker images
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
```

3. **Benefits:**
   - Native GitHub integration
   - Automatic PR creation for updates
   - Advanced Security features (if enabled)
   - No workflow configuration needed

### Approach 2: Snyk Integration

Use Snyk for comprehensive dependency scanning:

```yaml
snyk-scan:
  name: Snyk Security Scan
  runs-on: ubuntu-latest

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    - name: Run Snyk to check for vulnerabilities
      uses: snyk/actions@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: --all-projects --sarif-file-output=snyk-results.sarif
      continue-on-error: true

    - name: Upload Snyk Results to GitHub
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: snyk-results.sarif
```

### Approach 3: Trivy for Comprehensive Scanning

Trivy can scan dependencies, containers, and IaC:

```yaml
trivy-comprehensive:
  name: Trivy Comprehensive Scan
  runs-on: ubuntu-latest

  steps:
    - name: Checkout Code
      uses: actions/checkout@v4

    # Scan filesystem for dependencies
    - name: Run Trivy Filesystem Scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: 'src/'
        format: 'sarif'
        output: 'trivy-dependencies.sarif'
        severity: 'CRITICAL,HIGH,MEDIUM'
        scanners: 'vuln,secret,config'

    - name: Upload Trivy Results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: trivy-dependencies.sarif
        category: trivy-dependencies
```

---

## Monitoring and Validation

### Test Dependency Scanning Locally

Before committing changes, test locally:

```bash
# Run OWASP Dependency-Check locally
docker run --rm \
  -v $(pwd):/src \
  owasp/dependency-check:latest \
  --project "online-boutique" \
  --scan /src/src/ \
  --format HTML \
  --out /src/dependency-check-report \
  --enableRetired

# View results
open dependency-check-report/dependency-check-report.html
```

### Validate SARIF Output

Check if SARIF files are valid:

```bash
# Install SARIF validator
npm install -g @microsoft/sarif-multitool

# Validate SARIF file
sarif-multitool validate dependency-check-report/dependency-check-report.sarif
```

### Monitor Scan Performance

Add timing metrics to workflow:

```yaml
- name: Run OWASP Dependency Check
  id: dependency-check
  uses: dependency-check/Dependency-Check_Action@main
  with:
    project: 'online-boutique'
    path: 'src/'
    format: 'SARIF'
    out: 'dependency-check-report'

- name: Report Scan Duration
  if: always()
  run: |
    echo "Dependency-Check Duration: ${{ steps.dependency-check.outputs.duration }}"
    echo "### Dependency Scan Metrics" >> $GITHUB_STEP_SUMMARY
    echo "- Duration: ${{ steps.dependency-check.outputs.duration }}" >> $GITHUB_STEP_SUMMARY
    echo "- Status: ${{ steps.dependency-check.outcome }}" >> $GITHUB_STEP_SUMMARY
```

### Create Alerting

Set up GitHub Actions notifications:

```yaml
- name: Notify on Scan Failure
  if: failure() && github.event_name != 'pull_request'
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'OWASP Dependency-Check failed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Best Practices

### 1. Incremental Adoption

Start with one language ecosystem:
- Week 1: Enable for Node.js services only
- Week 2: Add Go services
- Week 3: Add Python services
- Week 4: Add Java services

### 2. Tiered Severity Response

Configure different actions based on severity:

```yaml
- name: Check for Critical Vulnerabilities
  run: |
    CRITICAL=$(jq '[.runs[].results[] | select(.level == "error")] | length' dependency-check-report/dependency-check-report.sarif)
    if [ "$CRITICAL" -gt 0 ]; then
      echo "::error::Found $CRITICAL critical vulnerabilities!"
      exit 1
    fi
```

### 3. Regular Updates

Keep scanning tools updated:

```yaml
# Update weekly
- name: Update NVD Database
  run: |
    docker run --rm \
      -v ~/.gradle/dependency-check-data:/data \
      owasp/dependency-check:latest \
      --updateonly
```

### 4. Documentation

Maintain a vulnerability remediation log:

```markdown
# Vulnerability Remediation Log

| Date | CVE | Service | Severity | Status | Notes |
|------|-----|---------|----------|--------|-------|
| 2025-10-16 | CVE-2024-XXXX | frontend | HIGH | Fixed | Updated dependency to 1.2.3 |
```

---

## Support and Resources

### Official Documentation
- [OWASP Dependency-Check](https://jeremylong.github.io/DependencyCheck/)
- [GitHub Action](https://github.com/dependency-check/Dependency-Check_Action)
- [Suppression File Format](https://jeremylong.github.io/DependencyCheck/general/suppression.html)

### Community Resources
- [OWASP Slack](https://owasp.slack.com) - #dependency-check channel
- [GitHub Discussions](https://github.com/jeremylong/DependencyCheck/discussions)

### Internal Contacts
- Security Team: `security@yourcompany.com`
- DevOps Team: `devops@yourcompany.com`

---

**Last Updated**: 2025-10-16
**Maintained By**: DevOps Team
**Review Frequency**: Monthly
