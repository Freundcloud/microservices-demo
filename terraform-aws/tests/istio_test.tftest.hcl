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

# Istio Service Mesh Configuration Tests
# Tests to verify Istio installation and configuration

run "istio_enabled_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_istio = true
  }

  # Verify Istio base is installed
  assert {
    condition     = length(helm_release.istio_base) == 1
    error_message = "Istio base should be installed when enable_istio is true"
  }

  # Verify istiod is installed
  assert {
    condition     = length(helm_release.istiod) == 1
    error_message = "Istiod should be installed when enable_istio is true"
  }

  # Verify Istio ingress gateway is installed
  assert {
    condition     = length(helm_release.istio_ingressgateway) == 1
    error_message = "Istio ingress gateway should be installed when enable_istio is true"
  }
}

run "istio_disabled_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_istio = false
  }

  # Verify Istio components are not created when disabled
  assert {
    condition     = length(helm_release.istio_base) == 0
    error_message = "Istio components should not be created when enable_istio is false"
  }
}

run "istio_version_test" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    aws_region    = "eu-west-2"
    environment   = "test"
    enable_istio  = true
    istio_version = "1.20.0"
  }

  # Verify correct Istio version is used
  assert {
    condition     = helm_release.istio_base[0].version == "1.20.0"
    error_message = "Istio version should be 1.20.0"
  }

  assert {
    condition     = helm_release.istiod[0].version == "1.20.0"
    error_message = "Istiod version should be 1.20.0"
  }

  assert {
    condition     = helm_release.istio_ingressgateway[0].version == "1.20.0"
    error_message = "Istio ingress gateway version should be 1.20.0"
  }
}

run "istio_addons_enabled_test" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    aws_region          = "eu-west-2"
    environment         = "test"
    enable_istio        = true
    enable_istio_addons = true
  }

  # Verify Kiali is installed
  assert {
    condition     = length(helm_release.kiali) == 1
    error_message = "Kiali should be installed when addons are enabled"
  }

  # Verify Prometheus is installed
  assert {
    condition     = length(helm_release.prometheus) == 1
    error_message = "Prometheus should be installed when addons are enabled"
  }

  # Verify Jaeger is installed
  assert {
    condition     = length(helm_release.jaeger) == 1
    error_message = "Jaeger should be installed when addons are enabled"
  }

  # Verify Grafana is installed
  assert {
    condition     = length(helm_release.grafana) == 1
    error_message = "Grafana should be installed when addons are enabled"
  }
}

run "istio_addons_disabled_test" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    aws_region          = "eu-west-2"
    environment         = "test"
    enable_istio        = true
    enable_istio_addons = false
  }

  # Verify add-ons are not installed when disabled
  assert {
    condition     = length(helm_release.kiali) == 0
    error_message = "Kiali should not be installed when addons are disabled"
  }
}

run "istio_mtls_enforcement_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_istio = true
  }

  # Verify PeerAuthentication for mTLS is created
  assert {
    condition     = length(kubectl_manifest.peer_authentication) == 1
    error_message = "PeerAuthentication should be created to enforce mTLS"
  }

  # Verify DestinationRule for mTLS is created
  assert {
    condition     = length(kubectl_manifest.destination_rule_mtls) == 1
    error_message = "DestinationRule should be created for mTLS traffic policy"
  }
}

run "istio_namespace_test" {
  command = plan

  variables {
    cluster_name = "test-cluster"
    aws_region   = "eu-west-2"
    environment  = "test"
    enable_istio = true
    namespace    = "microservices"
  }

  # Verify Istio-enabled namespace is created
  assert {
    condition     = length(kubernetes_namespace.istio_enabled) == 1
    error_message = "Istio-enabled namespace should be created"
  }

  # Verify namespace has Istio injection label
  assert {
    condition     = lookup(kubernetes_namespace.istio_enabled[0].metadata[0].labels, "istio-injection", "") == "enabled"
    error_message = "Namespace should have istio-injection=enabled label"
  }
}
