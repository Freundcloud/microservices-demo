# Setup Terraform Composite Action

This composite action installs and configures the Terraform CLI.

## Purpose

Reduces code duplication by centralizing Terraform setup that was previously repeated across 3 workflow files.

## Usage

### Basic Usage (with defaults)

```yaml
- name: Setup Terraform
  uses: ./.github/actions/setup-terraform
```

This uses default version `1.6.0` with terraform-wrapper enabled.

### Custom Version

```yaml
- name: Setup Terraform
  uses: ./.github/actions/setup-terraform
  with:
    terraform-version: '1.9.0'
```

### Disable Terraform Wrapper

```yaml
- name: Setup Terraform
  uses: ./.github/actions/setup-terraform
  with:
    terraform-version: '1.6.0'
    terraform-wrapper: 'false'
```

### Using Input Variables

```yaml
- name: Setup Terraform
  uses: ./.github/actions/setup-terraform
  with:
    terraform-version: ${{ inputs.tf_version }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `terraform-version` | Terraform version to install | No | `1.6.0` |
| `terraform-wrapper` | Whether to install terraform-wrapper | No | `true` |

## What This Action Does

1. Installs Terraform CLI using `hashicorp/setup-terraform@v3`
2. Configures the specified version
3. Optionally installs terraform-wrapper for capturing outputs

## Terraform Wrapper

The terraform-wrapper is a shell script that:
- Captures Terraform outputs and makes them available as step outputs
- Useful for getting plan/apply outputs in subsequent steps
- Can be disabled with `terraform-wrapper: 'false'` for cleaner outputs

## Benefits

- **Consistency**: Same Terraform version across all workflows
- **Maintainability**: Update version once, applies everywhere
- **Readability**: Workflows are cleaner and easier to understand
- **Flexibility**: Can override version per workflow if needed

## Workflows Using This Action

- `terraform-plan.yaml`
- `terraform-apply.yaml`
- `aws-infrastructure-discovery.yaml`

## Example: Full Workflow

```yaml
jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup AWS Credentials
        uses: ./.github/actions/setup-aws-credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Setup Terraform
        uses: ./.github/actions/setup-terraform
        with:
          terraform-version: '1.6.0'

      - name: Terraform Init
        run: terraform init
        working-directory: terraform-aws

      - name: Terraform Plan
        run: terraform plan
        working-directory: terraform-aws
```

## Related Actions

- [Setup AWS Credentials](./../setup-aws-credentials/README.md) - Configure AWS credentials (often used before Terraform)
- [Configure kubectl](./../configure-kubectl/README.md) - Configure kubectl for EKS access
