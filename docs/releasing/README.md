# Releasing Online Boutique on AWS

This document walks through the process of creating a new release of Online Boutique for AWS deployment.

## Prerequisites for Tagging a Release

1. Choose the logical [next release tag](https://github.com/your-org/microservices-demo/releases), using [semantic versioning](https://semver.org/): `vX.Y.Z`.

   If this release includes significant feature changes, update the minor version (`Y`). Otherwise, for bug-fix releases or standard quarterly release, update the patch version (`Z`).

2. Ensure that the following commands are in your `PATH`:
   - `sed` (Linux) or `gsed` (macOS via `brew install gnu-sed`)
   - `aws` (AWS CLI v2)
   - `docker` with buildx support
   - `helm` (for Helm chart releases)
   - `git`

3. Make sure that your AWS credentials are configured:

   ```sh
   # Option 1: AWS CLI configuration
   aws configure

   # Option 2: Use .envrc (project standard)
   source .envrc

   # Verify credentials
   aws sts get-caller-identity
   ```

4. Login to AWS ECR:

   ```sh
   aws ecr get-login-password --region eu-west-2 | \
     docker login --username AWS --password-stdin \
     $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-west-2.amazonaws.com
   ```

## Create and Tag the New Release

Run the `make-release.sh` script found inside the `docs/releasing/` directory:

```sh
# Assuming you are inside the root path of the microservices-demo repository
export TAG=vX.Y.Z  # This is the new version (e.g. `v0.3.5`)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=eu-west-2  # Optional, defaults to eu-west-2

./docs/releasing/make-release.sh
```

This script does the following:
1. Uses `make-docker-images.sh` to build and push multi-architecture Docker images to AWS ECR
2. Uses `make-release-artifacts.sh` to regenerate (and update the image tags) in:
   - `./release/kubernetes-manifests.yaml`
   - `./release/istio-manifests.yaml`
   - `./kustomize/base/`
3. Uses `make-helm-chart.sh` to package and push the Helm chart to ECR
4. Runs `git tag` and pushes a new branch (e.g., `release/v0.3.5`) with the changes

You can then browse the [ECR repositories in AWS Console](https://console.aws.amazon.com/ecr/repositories) to verify that Docker images were created for each microservice with the new version tag.

## Create the Pull Request

Now that the release branch has been created, you can find it in the [list of branches](https://github.com/your-org/microservices-demo/branches) and create a pull request targeting `main` (the default branch).

This process will trigger multiple CI checks including:
- Terraform validation and tests
- Security scanning (CodeQL, Trivy, Gitleaks, Semgrep, Checkov)
- Container image builds
- SBOM generation

Once the PR has been approved and all checks are successfully passing, you can then merge the branch. Make sure to include the release draft (see next section) in the pull-request description for reviewers to see.

**Important**: When merging, do NOT delete the release branch or the tags.

## Add Notes to the Release

Once the PR has been fully merged, you are ready to create a new release for the newly created [tag](https://github.com/your-org/microservices-demo/tags).

1. Navigate to the [tags page](https://github.com/your-org/microservices-demo/tags)
2. Click the breadcrumbs on the row of the latest tag that was created
3. Select the `Create release` option

The release notes should contain a brief description of the changes since the previous release (like bugs fixed and new features). For inspiration, you can look at the list of [releases](https://github.com/your-org/microservices-demo/releases).

> **Note:** No assets need to be uploaded. They are picked up automatically from the tagged revision.

## Deploy to Production Environment

Once the release notes are published, you should deploy the new version to your production EKS cluster.

### Option 1: Using kubectl

1. Connect to your production EKS cluster:

   ```sh
   aws eks update-kubeconfig \
     --region eu-west-2 \
     --name microservices-prod
   ```

2. Deploy the new release:

   ```sh
   kubectl apply -f ./release/kubernetes-manifests.yaml
   kubectl apply -f ./release/istio-manifests.yaml
   ```

3. Verify the deployment:

   ```sh
   kubectl get pods -n default
   kubectl get svc istio-ingressgateway -n istio-system
   ```

4. Check the application URL:

   ```sh
   kubectl get svc istio-ingressgateway -n istio-system \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

### Option 2: Using Helm

1. Connect to your production EKS cluster (same as above)

2. Upgrade using Helm:

   ```sh
   helm upgrade online-boutique \
     oci://$(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-west-2.amazonaws.com/helm-charts/onlineboutique \
     --version ${TAG:1} \
     --namespace default
   ```

### Option 3: Using GitHub Actions

Trigger the `deploy-application` workflow with the production environment:

```sh
# Via GitHub CLI
gh workflow run deploy-application.yaml -f environment=prod -f tag=${TAG}

# Or manually via GitHub Actions UI
```

## Update Major Tags

1. Update the relevant major tag (for example, `v0`):

   ```sh
   export MAJOR_TAG=v0  # Edit this as needed (to v1/v2/v3/etc)
   git checkout release/${TAG}
   git pull
   git push --delete origin ${MAJOR_TAG}  # Delete the remote tag (if it exists)
   git tag --delete ${MAJOR_TAG}  # Delete the local tag (if it exists)
   git tag -a ${MAJOR_TAG} -m "Updating ${MAJOR_TAG} to its most recent release: ${TAG}"
   git push origin ${MAJOR_TAG}  # Push the new tag to origin
   ```

## Verify the Release

After deploying to production, verify:

1. **Application Health**:
   ```sh
   kubectl get pods -n default
   # All pods should be Running with 2/2 containers (app + istio-proxy)
   ```

2. **Istio Service Mesh**:
   ```sh
   kubectl get gateway,virtualservice -n default
   istioctl analyze -n default
   ```

3. **Access Application**:
   ```sh
   # Get the URL
   INGRESS_URL=$(kubectl get svc istio-ingressgateway -n istio-system \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   echo "Application: http://$INGRESS_URL"

   # Test endpoint
   curl -I http://$INGRESS_URL
   ```

4. **Check Observability Dashboards**:
   ```sh
   # Kiali (service mesh)
   kubectl port-forward svc/kiali-server -n istio-system 20001:20001

   # Grafana (metrics)
   kubectl port-forward svc/grafana -n istio-system 3000:80

   # Jaeger (tracing)
   kubectl port-forward svc/jaeger-query -n istio-system 16686:16686
   ```

## Rollback Procedure

If issues are discovered after deployment:

### Quick Rollback (kubectl)

```sh
# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n default

# Or rollback all deployments
for deployment in $(kubectl get deployments -n default -o name); do
  kubectl rollout undo $deployment -n default
done
```

### Full Rollback (Helm)

```sh
# List releases
helm list -n default

# Rollback to previous revision
helm rollback online-boutique -n default
```

### Redeploy Previous Version

```sh
# Checkout previous release tag
git checkout v0.3.4  # Previous version

# Redeploy
kubectl apply -f ./release/kubernetes-manifests.yaml
kubectl apply -f ./release/istio-manifests.yaml
```

## Manual Build and Push (Without Release Script)

If you need to build and push images without creating a full release:

### Build Specific Service

```sh
export TAG=v0.3.5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=eu-west-2

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push
cd src/frontend
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/frontend:$TAG \
  --push \
  .
```

### Update Manifests Only

```sh
export TAG=v0.3.5
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=eu-west-2

./docs/releasing/make-release-artifacts.sh
```

## Troubleshooting

### Docker buildx Not Available

```sh
# Install buildx
docker buildx install

# Create builder
docker buildx create --use --name multiarch-builder
```

### ECR Repository Not Found

```sh
# Create ECR repository for a service
aws ecr create-repository \
  --repository-name frontend \
  --region eu-west-2

# Or run Terraform to create all repositories
cd terraform-aws
terraform apply -target=module.ecr
```

### AWS Credentials Not Found

```sh
# Verify credentials
aws sts get-caller-identity

# If not configured, set up credentials
source .envrc  # or
aws configure
```

### Helm Registry Login Failed

```sh
# Login to ECR for Helm
aws ecr get-login-password --region eu-west-2 | \
  helm registry login --username AWS --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.eu-west-2.amazonaws.com
```

### Git Push Failed

```sh
# Check if branch already exists
git branch -a | grep release/${TAG}

# Delete local branch and retry
git branch -D release/${TAG}
./docs/releasing/make-release.sh
```

## Environment-Specific Releases

To release to specific environments:

### Development Release

```sh
export TAG=v0.3.5-dev
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

./docs/releasing/make-docker-images.sh
./docs/releasing/make-release-artifacts.sh

kubectl apply -f ./release/kubernetes-manifests.yaml --context dev-cluster
```

### QA Release

```sh
export TAG=v0.3.5-qa
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

./docs/releasing/make-docker-images.sh
./docs/releasing/make-release-artifacts.sh

kubectl apply -f ./release/kubernetes-manifests.yaml --context qa-cluster
```

## Security Considerations

1. **Image Scanning**: All images are automatically scanned by ECR on push
2. **SBOM Generation**: Software Bill of Materials is generated during build
3. **Vulnerability Reports**: Check ECR console for vulnerability findings
4. **Sign Images**: Consider using AWS Signer or Cosign for image signing
5. **Access Control**: Ensure proper IAM policies for ECR access

## Additional Resources

- [AWS ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/)
- [Semantic Versioning](https://semver.org/)
- [Helm Documentation](https://helm.sh/docs/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)

## Support

For issues with the release process:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review [GitHub Actions logs](.github/workflows/)
3. Check [AWS CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/)
4. Open an issue on GitHub with details
