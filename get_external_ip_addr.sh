#!/bin/bash

# Check if traceroute is installed
if ! command -v traceroute &> /dev/null; then
    echo "Traceroute is not installed. Installing..."
    # Install traceroute
    sudo apt-get update
    sudo apt-get install -y traceroute
fi

# Function to extract the first external IP address from a traceroute
extract_external_ip() {
    traceroute_output=$(traceroute -n $1)
    # Extract the first IP address that is not a local or private IP
    external_ip=$(echo "$traceroute_output" | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | grep -vE '^(10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.)' | head -n1)
    echo "$external_ip"
}

# Call the function with a domain or IP address
first_external_ip=$(extract_external_ip "example.com")

# Check if an external IP was found
if [ -n "$first_external_ip" ]; then
    echo "First external IP found: $first_external_ip"
    # Export the external IP as an environment variable
    export FIRST_EXTERNAL_IP="$first_external_ip"
    echo "Exported as FIRST_EXTERNAL_IP"
else
    echo "No external IP found in the traceroute."
fi
