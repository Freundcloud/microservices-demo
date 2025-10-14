#!/usr/bin/env bash
# Fix Istiod installation timeout
set -e

echo "=== Fixing Istiod Installation Timeout ==="
echo ""

# Check if AWS credentials are configured
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "ERROR: AWS credentials not configured"
    echo "Please run: source .envrc"
    exit 1
fi

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name microservices --region eu-west-2

# Check Istio Base status
echo ""
echo "Checking Istio Base status..."
helm status istio-base -n istio-system

# Uninstall failed Istiod if exists
echo ""
echo "Checking for failed Istiod installation..."
if helm status istiod -n istio-system &>/dev/null; then
    echo "Found existing Istiod installation, uninstalling..."
    helm uninstall istiod -n istio-system || true
    sleep 10
fi

# Wait for any pending pods to terminate
echo ""
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=istiod -n istio-system --timeout=60s 2>/dev/null || true

# Install Istiod with increased timeout
echo ""
echo "Installing Istiod with increased timeout..."
helm upgrade --install istiod istio/istiod \
    --namespace istio-system \
    --wait \
    --timeout 10m \
    --version 1.23.0 \
    --set global.hub=docker.io/istio \
    --set global.tag=1.23.0

echo ""
echo "✓ Istiod installation completed"

# Check installation
echo ""
echo "Verifying installation..."
kubectl get pods -n istio-system

echo ""
echo "=== Fix Complete ==="
