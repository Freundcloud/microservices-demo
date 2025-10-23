# Single-Cluster Migration Guide (Placeholder)

This file is referenced by the README to describe the migration to a single EKS cluster with multiple node groups and namespaces (dev/qa/prod). A full guide can be added here. For now, see:

- docs/README-AWS.md
- docs/architecture/REPOSITORY-STRUCTURE.md
- docs/README.md (Project Structure and Kustomize Overlays)

Summary:

- One EKS cluster named `microservices` with dedicated node groups per environment
- Namespaces: `microservices-dev`, `microservices-qa`, `microservices-prod`
- Taints/tolerations and node labels ensure workload isolation
- Istio shared control plane, per-namespace workloads

Deployment commands:

- just tf-apply
- just k8s-config
- kubectl apply -k kustomize/overlays/dev
- kubectl apply -k kustomize/overlays/qa
- kubectl apply -k kustomize/overlays/prod

TODO:

- Add diagrams and migration steps
- Document resource sizing and cost trade-offs
- Add rollback considerations
