# Configure kubectl Composite Action

This composite action configures kubectl to access an AWS EKS cluster.

## Purpose

Reduces code duplication by centralizing kubectl configuration that was previously repeated across multiple workflow files.

## Prerequisites

- AWS credentials must be configured before using this action (use `setup-aws-credentials` action first)
- The specified EKS cluster must exist in the AWS account

## Usage

### Basic Usage

```yaml
- name: Configure kubectl
  uses: ./.github/actions/configure-kubectl
  with:
    cluster-name: microservices
```

### With Custom Region

```yaml
- name: Configure kubectl
  uses: ./.github/actions/configure-kubectl
  with:
    cluster-name: microservices
    aws-region: us-east-1
```

### Skip Connection Verification

```yaml
- name: Configure kubectl
  uses: ./.github/actions/configure-kubectl
  with:
    cluster-name: microservices
    verify-connection: 'false'
```

### Using Environment Variables

```yaml
- name: Configure kubectl
  uses: ./.github/actions/configure-kubectl
  with:
    cluster-name: ${{ env.CLUSTER_NAME }}
    aws-region: ${{ env.AWS_REGION }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cluster-name` | EKS cluster name to connect to | Yes | - |
| `aws-region` | AWS region where the cluster is located | No | `eu-west-2` |
| `verify-connection` | Verify kubectl connection after configuration | No | `true` |

## What This Action Does

1. Runs `aws eks update-kubeconfig` to configure kubectl
2. Updates `~/.kube/config` with cluster credentials
3. Optionally verifies connection by running:
   - `kubectl version --client` - Shows kubectl version
   - `kubectl cluster-info` - Displays cluster information

## Benefits

- **Consistency**: Same kubectl setup across all workflows
- **Maintainability**: Update once, applies everywhere
- **Readability**: Workflows are cleaner and easier to understand
- **Error Prevention**: Reduces risk of misconfiguration
- **Verification**: Optional connection check ensures configuration succeeded

## Workflows Using This Action

- `deploy-environment.yaml`
- `MASTER-PIPELINE.yaml` (2 jobs)

## Example: Full Workflow

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup AWS Credentials
        uses: ./.github/actions/setup-aws-credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Configure kubectl
        uses: ./.github/actions/configure-kubectl
        with:
          cluster-name: microservices

      - name: Deploy Application
        run: |
          kubectl apply -k kustomize/overlays/dev
```

## Troubleshooting

### Error: "You must be logged in to the server"

**Cause**: AWS credentials not configured or expired.

**Solution**: Ensure `setup-aws-credentials` action runs before this action.

### Error: "cluster not found"

**Cause**: Cluster name or region is incorrect.

**Solution**: Verify cluster name and region match your EKS cluster.

### Error: "kubectl: command not found"

**Cause**: kubectl not installed on runner.

**Solution**: GitHub-hosted runners have kubectl pre-installed. If using self-hosted runners, install kubectl first.

## Related Actions

- [Setup AWS Credentials](./../setup-aws-credentials/README.md) - Configure AWS credentials (prerequisite)
