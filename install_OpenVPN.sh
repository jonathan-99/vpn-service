#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

# Set locales to generate
locales_to_generate=("en_GB.UTF-8 UTF-8")

# Generate locales
for locale_entry in "${locales_to_generate[@]}"; do
    sudo locale-gen "$locale_entry"
done

# Define the network interface and gateway IP address
interface="eth0"
gateway_ip="192.168.1.1"

# Prepare the configuration to be added
config="auto $interface\n"
config+="iface $interface inet dhcp\n"
config+="    post-up route add default gw $gateway_ip\n"

# Insert the configuration into the /etc/network/interfaces file
echo -e "$config" | sudo tee -a /etc/network/interfaces > /dev/null

# Check if the external IP address is set as an environment variable
if [ -z "$FIRST_EXTERNAL_IP" ]; then
    echo "ERROR: FIRST_EXTERNAL_IP environment variable is not set. Running the script to get the external IP..."
    ./get_external_ip_addr.sh
    if [ $? -ne 0 ]; then
        echo "Failed to retrieve the external IP address. Exiting."
        exit 1
    fi
fi

# Update package lists
apt-get update

# Install OpenVPN
apt-get install -y openvpn

# Check if the folder structure exists
if [ ! -d "/usr/share/doc/openvpn/examples/easy-rsa/" ]; then
    echo "Error: easy-rsa directory not found. OpenVPN installation might be incomplete."
    exit 1
fi

# Copy example configuration files to the OpenVPN directory
cp -r /usr/share/doc/openvpn/examples/easy-rsa/ /etc/openvpn

# Change directory to the EasyRSA directory
cd /etc/openvpn/easy-rsa || exit

# Initialize the EasyRSA environment
./easyrsa init-pki

# Amend copied configuration files for OpenVPN
sed -i 's/KEY_NAME="EasyRSA"/KEY_NAME="server"/g' /etc/openvpn/easy-rsa/vars

# Build the certificate authority
./easyrsa build-ca nopass

# Generate server key and certificate
./easyrsa build-server-full server nopass

# Generate Diffie-Hellman parameters
./easyrsa gen-dh

# Move the generated files to the OpenVPN directory
cp pki/private/server.key /etc/openvpn
cp pki/issued/server.crt /etc/openvpn
cp pki/ca.crt /etc/openvpn
cp pki/dh.pem /etc/openvpn

# Generate a static key (optional)
openvpn --genkey --secret /etc/openvpn/static.key

# Update OpenVPN server configuration to use the external IP address
echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.8.8\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.4.4\"" >> /etc/openvpn/server.conf
echo "push \"route-metric 512\"" >> /etc/openvpn/server.conf
echo "server $(echo $FIRST_EXTERNAL_IP | cut -d '.' -f 1-3).0 255.255.255.0" >> /etc/openvpn/server.conf

# Copy sample server configuration file
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf

# Enable IP forwarding
sed -i '/#net.ipv4.ip_forward=1/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p

# Start OpenVPN service
systemctl start openvpn@server

# Enable OpenVPN service to start on boot
systemctl enable openvpn@server

echo "OpenVPN has been installed and configured on your Raspberry Pi."
