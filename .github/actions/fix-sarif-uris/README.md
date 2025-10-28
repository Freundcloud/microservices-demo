# Fix SARIF URI Schemes Composite Action

This composite action fixes URI schemes in SARIF (Static Analysis Results Interchange Format) files to ensure compatibility with GitHub Code Scanning.

## Purpose

Many security scanning tools generate SARIF files with `git://` URI schemes, which GitHub Code Scanning cannot process. This action converts all `git://` URIs to `file://` URIs, making the SARIF files compatible with GitHub's security features.

## Usage

### Basic Usage

```yaml
- name: Fix SARIF URI Schemes
  uses: ./.github/actions/fix-sarif-uris
  with:
    sarif-file: results.sarif
```

### Multiple Files

```yaml
- name: Fix SARIF URI Schemes
  uses: ./.github/actions/fix-sarif-uris
  with:
    sarif-file: 'semgrep-results.sarif trivy-results.sarif'
```

### With Continue on Error

```yaml
- name: Fix SARIF URI Schemes
  uses: ./.github/actions/fix-sarif-uris
  with:
    sarif-file: grype-results.sarif
  continue-on-error: true
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `sarif-file` | Path to SARIF file(s) to fix (space-separated for multiple) | Yes | - |

## What This Action Does

1. Makes the `scripts/fix-sarif-uris.sh` script executable
2. Runs the script on the specified SARIF file(s)
3. Converts all `git://` URIs to `file://` URIs
4. Validates JSON integrity after transformation
5. Creates backup and restores on error

## URI Transformations

The script performs the following transformations:

- `git://path/to/file.py` → `file://path/to/file.py`
- `git:path/to/file.py` → `file://path/to/file.py`
- Removes duplicate `file://file://` if created

## Error Handling

- Skips non-existent files with warning
- Skips files without `git://` URIs (already fixed)
- Creates backup before transformation
- Restores backup if JSON becomes invalid
- Exits with error code if transformation fails

## Benefits

- **Consistency**: Same SARIF fixing logic across all security scans
- **Maintainability**: Update once, applies everywhere
- **Reliability**: Built-in validation and backup/restore
- **Readability**: Workflows are cleaner and easier to understand

## Workflows Using This Action

- `security-scan.yaml` (Grype, Semgrep, Trivy, Checkov, tfsec, OWASP)

## Example: Full Workflow

```yaml
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Security Scanner
        run: semgrep scan --config=auto --sarif --output=results.sarif

      - name: Fix SARIF URI Schemes
        uses: ./.github/actions/fix-sarif-uris
        with:
          sarif-file: results.sarif
        continue-on-error: true

      - name: Upload Results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

## Related Actions

- [Setup AWS Credentials](./../setup-aws-credentials/README.md) - AWS credentials configuration
- [Setup Terraform](./../setup-terraform/README.md) - Terraform CLI setup

## Script Location

The underlying script is located at:
- `scripts/fix-sarif-uris.sh`

The script is shared across all workflows and can also be run manually:
```bash
./scripts/fix-sarif-uris.sh results.sarif
```
