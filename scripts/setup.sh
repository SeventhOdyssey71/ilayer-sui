#!/bin/bash

# Setup script for iLayer on Sui development environment

set -e

echo "=== iLayer Sui Development Setup ==="

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v sui &> /dev/null; then
    echo "Error: Sui CLI not found."
    echo "Please install Sui CLI: https://docs.sui.io/guides/developer/getting-started/sui-install"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "Error: Node.js not found."
    echo "Please install Node.js: https://nodejs.org/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Warning: jq not found. Installing via npm..."
    npm install -g node-jq
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p build
mkdir -p deployments
mkdir -p logs

# Copy environment file if not exists
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please edit .env file with your configuration"
fi

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
cd scripts
npm install
cd ..

# Configure Sui client
echo "Configuring Sui client..."
sui client new-env --alias ilayer-devnet --rpc https://fullnode.devnet.sui.io:443
sui client switch --env ilayer-devnet

# Get active address
ACTIVE_ADDRESS=$(sui client active-address)
echo "Active address: $ACTIVE_ADDRESS"

# Check balance
echo "Checking SUI balance..."
sui client gas

# Build the project
echo "Building Move modules..."
sui move build

# Run tests
echo "Running tests..."
sui move test

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Fund your wallet with SUI tokens"
echo "3. Run './scripts/deploy.sh' to deploy contracts"
echo "4. Use the TypeScript scripts to interact with the protocol"
echo ""
echo "Useful commands:"
echo "- Build: sui move build"
echo "- Test: sui move test"
echo "- Deploy: ./scripts/deploy.sh"
echo "- Create order: npm run create-order"
echo "- Fill order: npm run fill-order"