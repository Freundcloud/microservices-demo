# Use Online Boutique with Kustomize

This page contains instructions on deploying variations of the Online Boutique sample application using [Kustomize](https://kustomize.io/). Each variation is designed as a [**Kustomize component**](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/components.md), so multiple variations can be composed together in the deployment.

## What is Kustomize?

Kustomize is a Kubernetes configuration management tool that allows users to customize their manifest configurations without duplication. Its commands are built into `kubectl` as `apply -k`. More information on Kustomize can be found on the [official Kustomize website](https://kustomize.io/).

## Prerequisites

Optionally, [install the `kustomize` binary](https://kubectl.docs.kubernetes.io/installation/) to avoid manually editing a `kustomization.yaml` file. Online Boutique's instructions will often use `kustomize edit` (like `kustomize edit add component components/some-component`), but you can skip these commands and instead add components manually to the [`/kustomize/kustomization.yaml` file](/kustomize/kustomization.yaml).

You need to have a Kubernetes cluster where you will deploy the Online Boutique's Kubernetes manifests. To set up an AWS EKS (Elastic Kubernetes Service) cluster, you can follow the instructions in the [AWS Deployment Guide](/docs/README-AWS.md) or use the Terraform configuration in [`/terraform-aws`](/terraform-aws).

## Deploy Online Boutique with Kustomize

1. From the root folder of this repository, navigate to the `kustomize/` directory.

    ```bash
    cd kustomize/
    ```

1. See what the default Kustomize configuration defined by `kustomize/kustomization.yaml` will generate (without actually deploying them yet).

    ```bash
    kubectl kustomize .
    ```

1. Apply the default Kustomize configuration (`kustomize/kustomization.yaml`).

    ```bash
    kubectl apply -k .
    ```

1. Wait for all Pods to show `STATUS` of `Running`.

    ```bash
    kubectl get pods
    ```

    The output should be similar to the following:

    ```terminal
    NAME                                     READY   STATUS    RESTARTS   AGE
    adservice-76bdd69666-ckc5j               1/1     Running   0          2m58s
    cartservice-66d497c6b7-dp5jr             1/1     Running   0          2m59s
    checkoutservice-666c784bd6-4jd22         1/1     Running   0          3m1s
    currencyservice-5d5d496984-4jmd7         1/1     Running   0          2m59s
    emailservice-667457d9d6-75jcq            1/1     Running   0          3m2s
    frontend-6b8d69b9fb-wjqdg                1/1     Running   0          3m1s
    loadgenerator-665b5cd444-gwqdq           1/1     Running   0          3m
    paymentservice-68596d6dd6-bf6bv          1/1     Running   0          3m
    productcatalogservice-557d474574-888kr   1/1     Running   0          3m
    recommendationservice-69c56b74d4-7z8r5   1/1     Running   0          3m1s
    shippingservice-6ccc89f8fd-v686r         1/1     Running   0          2m58s
    ```

    _Note: It may take 2-3 minutes before the changes are reflected on the deployment._

1. Access the web frontend in a browser using the frontend's `EXTERNAL_IP`.

    ```bash
    kubectl get service frontend-external | awk '{print $4}'
    ```

    Note: you may see `<pending>` while AWS provisions the load balancer. If this happens, wait a few minutes and re-run the command.

## Deploy Online Boutique variations with Kustomize

Here is the list of the variations available as Kustomize components that you could leverage:

- [**Integrate with AWS ElastiCache (Redis)**](components/elasticache)
  - The default Online Boutique deployment uses the in-cluster `redis` database for storing the contents of its shopping cart. This variation overrides the default database with AWS ElastiCache (Redis). These changes directly affect `cartservice`. See the [terraform-aws/elasticache.tf](/terraform-aws/elasticache.tf) configuration.
- [**Secure with Network Policies**](components/network-policies)
  - Deploy fine granular `NetworkPolicies` for Online Boutique.
- [**Update the registry name of the container images**](components/container-images-registry)
  - Configure custom container registry (e.g., AWS ECR repository URL).
- [**Update the image tag of the container images**](components/container-images-tag)
  - Set specific image tags for deployments (e.g., `dev`, `qa`, `prod`, or semantic versions).
- [**Add an image tag suffix to the container images**](components/container-images-tag-suffix)
  - Add a suffix to image tags for versioning or environment identification.
- [**Do not expose the `frontend` publicly**](components/non-public-frontend)
  - Remove public load balancer exposure for internal-only deployments.
- [**Configure `Istio` service mesh resources**](components/service-mesh-istio)
  - Deploy Istio Gateway and VirtualService for service mesh integration. See [istio-manifests/](/istio-manifests) for complete configuration.

### Select variations

To customize Online Boutique with its variations, you need to update the default `kustomize/kustomization.yaml` file. You could do that manually, use `sed`, or use the `kustomize edit` command like illustrated below.

#### Use `kustomize edit` to select variations

Here is an example with the [**Istio Service Mesh**](components/service-mesh-istio) variation, from the `kustomize/` folder, run the command below:

```bash
kustomize edit add component components/service-mesh-istio
```

You could now combine it with other variations, like for example with the [**Network Policies**](components/network-policies) variation:

```bash
kustomize edit add component components/network-policies
```

### Deploy selected variations

Like explained earlier, you can locally render these manifests by running `kubectl kustomize .` as well as deploying them by running `kubectl apply -k .`.

So for example, the associated `kustomization.yaml` could look like:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- base
components:
- components/service-mesh-istio
- components/network-policies
```

## Multi-Environment Deployments

This repository includes pre-configured overlays for multi-environment deployments:

- **Dev** (`overlays/dev/`) - 1 replica per service, minimal resources, `microservices-dev` namespace
- **QA** (`overlays/qa/`) - 2 replicas per service, moderate resources, `microservices-qa` namespace, includes load generator
- **Prod** (`overlays/prod/`) - 3 replicas per service, high resources, `microservices-prod` namespace, production-ready

### Deploy to specific environments

```bash
# Deploy to dev environment
kubectl apply -k overlays/dev

# Deploy to qa environment
kubectl apply -k overlays/qa

# Deploy to prod environment
kubectl apply -k overlays/prod
```

For complete multi-environment deployment guide, see [overlays/README.md](overlays/README.md).

## AWS-Specific Configuration

This deployment is optimized for AWS EKS with:

- **AWS ElastiCache (Redis)** for cart service persistent storage
- **AWS ECR** for container image storage
- **AWS NLB** via Istio Ingress Gateway for external traffic
- **Istio Service Mesh** with strict mTLS for service-to-service communication
- **EBS CSI Driver** for persistent volumes

All infrastructure is managed via Terraform in [`/terraform-aws`](/terraform-aws).

Learn more about [Kustomize remote targets](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/remoteBuild.md).
