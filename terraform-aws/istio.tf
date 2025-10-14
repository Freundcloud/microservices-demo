# Copyright 2024
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Istio Service Mesh Installation
# This configures Istio for the EKS cluster to provide:
# - Service-to-service communication security (mTLS)
# - Traffic management and routing
# - Observability (metrics, logs, traces)
# - Circuit breaking and fault injection

# Install Istio using Helm
resource "helm_release" "istio_base" {
  count = var.enable_istio ? 1 : 0

  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = var.istio_version

  create_namespace = true

  set {
    name  = "defaultRevision"
    value = "default"
  }

  depends_on = [module.eks]
}

# Install Istio discovery (istiod)
resource "helm_release" "istiod" {
  count = var.enable_istio ? 1 : 0

  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = var.istio_version

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }

  set {
    name  = "global.tag"
    value = var.istio_version
  }

  set {
    name  = "meshConfig.accessLogFile"
    value = "/dev/stdout"
  }

  set {
    name  = "meshConfig.enableTracing"
    value = "true"
  }

  # Enable strict mTLS by default
  set {
    name  = "meshConfig.defaultConfig.proxyMetadata.ISTIO_META_TLS_MODE"
    value = "ISTIO_MUTUAL"
  }

  # Integration with AWS CloudWatch
  set {
    name  = "meshConfig.defaultConfig.tracing.zipkin.address"
    value = "zipkin.istio-system:9411"
  }

  depends_on = [helm_release.istio_base]
}

# Install Istio Ingress Gateway
resource "helm_release" "istio_ingressgateway" {
  count = var.enable_istio ? 1 : 0

  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  version    = var.istio_version

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  # Resource limits
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "2000m"
  }

  set {
    name  = "resources.limits.memory"
    value = "1024Mi"
  }

  # Autoscaling
  set {
    name  = "autoscaling.enabled"
    value = "true"
  }

  set {
    name  = "autoscaling.minReplicas"
    value = "2"
  }

  set {
    name  = "autoscaling.maxReplicas"
    value = "5"
  }

  depends_on = [helm_release.istiod]
}

# Install Kiali (Istio dashboard)
resource "helm_release" "kiali" {
  count = var.enable_istio && var.enable_istio_addons ? 1 : 0

  name       = "kiali-server"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-server"
  namespace  = "istio-system"
  version    = "1.79.0"

  set {
    name  = "auth.strategy"
    value = "anonymous"
  }

  set {
    name  = "deployment.ingress_enabled"
    value = "false"
  }

  set {
    name  = "external_services.prometheus.url"
    value = "http://prometheus-server.istio-system:80"
  }

  set {
    name  = "external_services.grafana.url"
    value = "http://grafana.istio-system:80"
  }

  set {
    name  = "external_services.tracing.url"
    value = "http://jaeger-query.istio-system:16686"
  }

  depends_on = [helm_release.istiod]
}

# Install Prometheus for metrics
resource "helm_release" "prometheus" {
  count = var.enable_istio && var.enable_istio_addons ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = "istio-system"
  version    = "25.8.0"

  set {
    name  = "server.persistentVolume.enabled"
    value = "false"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  depends_on = [helm_release.istiod]
}

# Install Jaeger for distributed tracing
resource "helm_release" "jaeger" {
  count = var.enable_istio && var.enable_istio_addons ? 1 : 0

  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  namespace  = "istio-system"
  version    = "0.76.0"

  set {
    name  = "provisionDataStore.cassandra"
    value = "false"
  }

  set {
    name  = "allInOne.enabled"
    value = "true"
  }

  set {
    name  = "storage.type"
    value = "memory"
  }

  set {
    name  = "agent.enabled"
    value = "false"
  }

  set {
    name  = "collector.enabled"
    value = "false"
  }

  set {
    name  = "query.enabled"
    value = "false"
  }

  depends_on = [helm_release.istiod]
}

# Install Grafana for visualization
resource "helm_release" "grafana" {
  count = var.enable_istio && var.enable_istio_addons ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "istio-system"
  version    = "7.0.0"

  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://prometheus-server.istio-system:80"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  depends_on = [helm_release.prometheus]
}

# Create namespace with Istio injection enabled
resource "kubernetes_namespace" "istio_enabled" {
  count = var.enable_istio ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      "istio-injection" = "enabled"
      "environment"     = var.environment
    }
  }

  depends_on = [helm_release.istiod]
}

# Peer Authentication - enforce strict mTLS
resource "kubectl_manifest" "peer_authentication" {
  count = var.enable_istio ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: default
      namespace: istio-system
    spec:
      mtls:
        mode: STRICT
  YAML

  depends_on = [helm_release.istiod]
}

# Destination Rule - enforce mTLS for all services
resource "kubectl_manifest" "destination_rule_mtls" {
  count = var.enable_istio ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: DestinationRule
    metadata:
      name: default
      namespace: istio-system
    spec:
      host: "*.local"
      trafficPolicy:
        tls:
          mode: ISTIO_MUTUAL
  YAML

  depends_on = [helm_release.istiod]
}
