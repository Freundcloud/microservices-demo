# Setup Node.js Environment Composite Action

This composite action installs Node.js with npm dependency caching configured.

## Purpose

Reduces code duplication by centralizing Node.js environment setup that was previously repeated across 4 workflow files.

## Usage

### Basic Usage (with caching)

```yaml
- name: Setup Node.js Environment
  uses: ./.github/actions/setup-node-env
  with:
    service: 'paymentservice'
```

### For Matrix Builds

```yaml
- name: Setup Node.js Environment
  if: |
    matrix.service == 'paymentservice' ||
    matrix.service == 'currencyservice'
  uses: ./.github/actions/setup-node-env
  with:
    service: ${{ matrix.service }}
```

### Without Caching (multiple services)

```yaml
- name: Setup Node.js Environment
  uses: ./.github/actions/setup-node-env
  with:
    node-version: '20'
```

Note: When `service` is not provided, caching is disabled.

### Custom Node Version

```yaml
- name: Setup Node.js Environment
  uses: ./.github/actions/setup-node-env
  with:
    node-version: '22'
    service: 'currencyservice'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `node-version` | Node.js version to install | No | `20` |
| `service` | Service name for npm cache path | No | `''` (no caching) |

## What This Action Does

1. Installs Node.js using `actions/setup-node@v4`
2. If `service` is provided:
   - Enables npm dependency caching
   - Sets cache path to `src/{service}/package-lock.json`
3. If `service` is empty, skips caching (for multi-service setups)

## npm Caching

When a service is specified, this action automatically enables npm caching:
- **Cache location**: `~/.npm`
- **Cache key**: Based on `package-lock.json` in service directory
- **Expected speedup**: 40-60% faster builds on cache hits

### First Run (cache miss):
```
Setup Node.js Environment
  cache: 'npm'
Cache not found
npm install takes ~2-3 minutes
```

### Subsequent Runs (cache hit):
```
Setup Node.js Environment
  cache: 'npm'
✓ Cache restored
npm install takes ~1-1.5 minutes (50% faster!)
```

## When to Use Caching vs No Caching

### ✅ Use caching (provide `service`):
- Single service builds
- Matrix builds where each job builds one service
- When `package-lock.json` is in `src/{service}/`

### ❌ Don't use caching (omit `service`):
- Installing dependencies for multiple services in one job
- When using manual cache actions instead
- Test/scan jobs that install multiple services

## Benefits

- **Performance**: 40-60% faster builds via caching
- **Consistency**: Same Node.js version across all workflows
- **Maintainability**: Update once, applies everywhere
- **Flexibility**: Caching optional based on use case

## Workflows Using This Action

- `build-images.yaml` (paymentservice, currencyservice builds)
- `run-unit-tests.yaml` (Node.js service tests)
- `security-scan.yaml` (for npm install in OWASP scans)

## Example: Full Workflow

```yaml
jobs:
  test-node-service:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [paymentservice, currencyservice]
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Node.js Environment
        uses: ./.github/actions/setup-node-env
        with:
          node-version: '20'
          service: ${{ matrix.service }}

      - name: Install Dependencies
        run: npm ci
        working-directory: src/${{ matrix.service }}

      - name: Run Tests
        run: npm test
        working-directory: src/${{ matrix.service }}
```

## Related Actions

- [Setup Java Environment](./../setup-java-env/README.md) - Java with Gradle caching
- [Setup Terraform](./../setup-terraform/README.md) - Terraform CLI setup
