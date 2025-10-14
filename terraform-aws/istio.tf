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

# Istio Service Mesh Configuration
# NOTE: Istio Helm installations moved to helm-installs.tf using null_resource + local-exec
# This file only contains Kubernetes resource configurations (PeerAuthentication, etc.)

# All helm_release resources for Istio are now in helm-installs.tf:
# - istio_base
# - istiod
# - istio_ingressgateway
# - prometheus (if enable_istio_addons)
# - grafana (if enable_istio_addons)
# - jaeger (if enable_istio_addons)
# - kiali (if enable_istio_addons)

# See helm-installs.tf for the actual installations
