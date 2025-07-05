#!/bin/bash

# Load environment variables
source .env

# Example interaction scripts for iLayer Sui contracts

# Function to create an order on OrderHub
create_order() {
    echo "Creating order on OrderHub..."
    sui client call \
        --package $PACKAGE_ID \
        --module order_hub \
        --function create_order \
        --args $ORDER_HUB_ID \
        "[{\"user\": \"$1\", \"recipient\": \"$2\", \"inputs\": [{\"token_type\": 0, \"token_address\": [], \"token_id\": 0, \"amount\": 1000000}], \"outputs\": [{\"token_type\": 0, \"token_address\": [], \"token_id\": 0, \"amount\": 950000}], \"deadline\": 1751100000000, \"primary_filler_deadline\": 1751050000000, \"filler\": \"0x0\", \"destination_chain_id\": 2, \"call_recipient\": \"0x0\", \"call_data\": [], \"call_value\": 0, \"sponsored\": false}]" \
        "0x1234567890abcdef" \
        "0xabcdef1234567890" \
        "0x1" \
        "0x6" \
        --gas-budget 50000000
}

# Function to register a solver
register_solver() {
    echo "Registering solver..."
    sui client call \
        --package $PACKAGE_ID \
        --module solver_registry \
        --function register_solver \
        --args $SOLVER_REGISTRY_ID "$1" \
        --gas-budget 10000000
}

# Function to register a token
register_token() {
    echo "Registering token..."
    sui client call \
        --package $PACKAGE_ID \
        --module token_registry \
        --function register_token \
        --args $TOKEN_REGISTRY_ID "\"$1\"" "\"$2\"" $3 $4 $5 "0x$6" \
        --gas-budget 10000000
}

# Function to check order status
check_order() {
    echo "Checking order status..."
    sui client object $1
}

# Function to view hub state
view_hub() {
    echo "Viewing OrderHub state..."
    sui client object $ORDER_HUB_ID
}

# Function to view spoke state
view_spoke() {
    echo "Viewing OrderSpoke state..."
    sui client object $ORDER_SPOKE_ID
}

# Main menu
echo "iLayer Sui Interaction Script"
echo "============================"
echo "1. Create Order"
echo "2. Register Solver"
echo "3. Register Token"
echo "4. Check Order"
echo "5. View Hub"
echo "6. View Spoke"
echo "7. Exit"

read -p "Select option: " option

case $option in
    1)
        read -p "Enter user address: " user
        read -p "Enter recipient address: " recipient
        create_order $user $recipient
        ;;
    2)
        read -p "Enter solver address: " solver
        register_solver $solver
        ;;
    3)
        read -p "Enter token type string: " token_type
        read -p "Enter symbol: " symbol
        read -p "Enter decimals: " decimals
        read -p "Enter token type (0-3): " type_num
        read -p "Enter chain ID: " chain_id
        read -p "Enter token address (hex): " address
        register_token "$token_type" "$symbol" $decimals $type_num $chain_id "$address"
        ;;
    4)
        read -p "Enter order ID: " order_id
        check_order $order_id
        ;;
    5)
        view_hub
        ;;
    6)
        view_spoke
        ;;
    7)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
esac