# Setup AWS Credentials Composite Action

This composite action configures AWS credentials for use in GitHub Actions workflows.

## Purpose

Reduces code duplication by centralizing AWS credentials configuration that was previously repeated across 7+ workflow files.

## Usage

```yaml
- name: Setup AWS Credentials
  uses: ./.github/actions/setup-aws-credentials
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### With Custom Region

```yaml
- name: Setup AWS Credentials
  uses: ./.github/actions/setup-aws-credentials
  with:
    aws-region: us-east-1
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `aws-region` | AWS region to configure | No | `eu-west-2` |

## Environment Variables Required

The action expects the following environment variables to be set:

- `AWS_ACCESS_KEY_ID` - AWS access key (from secrets)
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key (from secrets)

**Note**: Composite actions cannot directly access secrets. You must pass secrets via environment variables as shown in the usage examples above.

## What This Action Does

1. Configures AWS credentials using `aws-actions/configure-aws-credentials@v4`
2. Sets up AWS CLI and SDK with the provided credentials
3. Configures the specified AWS region (default: eu-west-2)

## Benefits

- **Consistency**: Single source of truth for AWS credentials setup
- **Maintainability**: Update once, applies everywhere
- **Readability**: Workflows are cleaner and easier to understand
- **Error Prevention**: Reduces risk of misconfiguration

## Workflows Using This Action

- `terraform-plan.yaml`
- `terraform-apply.yaml`
- `build-images.yaml`
- `deploy-environment.yaml`
- `MASTER-PIPELINE.yaml` (2 jobs)
- `aws-infrastructure-discovery.yaml`

## Related Actions

- [Configure kubectl](./../configure-kubectl/README.md) - Configure kubectl for EKS access
