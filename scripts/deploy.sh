#!/bin/bash

# Deploy script for iLayer on Sui

set -e

echo "=== iLayer Sui Deployment Script ==="

# Check if sui CLI is installed
if ! command -v sui &> /dev/null; then
    echo "Error: Sui CLI not found. Please install it first."
    echo "Visit: https://docs.sui.io/guides/developer/getting-started/sui-install"
    exit 1
fi

# Build the project
echo "Building Move modules..."
sui move build

# Run tests
echo "Running tests..."
sui move test

# Get current environment
NETWORK=${NETWORK:-"devnet"}
echo "Deploying to network: $NETWORK"

# Check active address
echo "Current active address:"
sui client active-address

# Check gas balance
echo "Gas balance:"
sui client gas

# Deploy with specified gas budget
GAS_BUDGET=${GAS_BUDGET:-"100000000"}
echo "Deploying with gas budget: $GAS_BUDGET"

# Deploy the package
echo "Publishing package..."
PUBLISH_OUTPUT=$(sui client publish --gas-budget $GAS_BUDGET --json)

# Extract package ID from output
PACKAGE_ID=$(echo $PUBLISH_OUTPUT | jq -r '.effects.created[0].reference.objectId' 2>/dev/null || echo "Failed to extract package ID")

echo "=== Deployment Complete ==="
echo "Package ID: $PACKAGE_ID"
echo ""
echo "Save this Package ID for future interactions!"

# Save deployment info
DEPLOYMENT_FILE="deployments/$NETWORK-deployment.json"
mkdir -p deployments

cat > $DEPLOYMENT_FILE <<EOF
{
  "network": "$NETWORK",
  "packageId": "$PACKAGE_ID",
  "deployedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "modules": [
    "types",
    "validator", 
    "executor",
    "token_registry",
    "cross_chain",
    "order_hub",
    "order_spoke"
  ]
}
EOF

echo "Deployment info saved to: $DEPLOYMENT_FILE"