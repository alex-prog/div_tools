#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

# Check if ip address is supplied
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ip_address>"
    exit 1
fi

IP_ADDRESS=$1

# Validate IP address (simple validation)
if ! echo "$IP_ADDRESS" | grep -Eo '^([0-9]{1,3}\.){3}[0-9]{1,3}$' > /dev/null; then
    echo "Invalid IP address format"
    exit 1
fi

# Automatically select the interface used for the default route
INTERFACE_NAME=$(ip route | grep default | awk '{print $5}' | head -n 1)

# Check if an interface could be found
if [[ -z "$INTERFACE_NAME" ]]; then
    echo "Could not find a network interface for the default route"
    exit 1
fi

# Calculate the gateway: replace the last octet of the IP address with .2
GATEWAY=$(echo "$IP_ADDRESS" | sed -r 's/([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+/\1.2/')

# Set static IP and default route
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE_NAME:
      dhcp4: no
      addresses:
        - $IP_ADDRESS/24 # <-- Update the subnet mask if necessary
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
          metric: 100
      nameservers:
        addresses: [$GATEWAY, 8.8.8.8] # <-- Update your DNS server addresses if needed
EOF

echo "[WARN] The network interface will be restarted. You will be disconnected from the server."
echo "[INFO] Applying changes..."
# Apply changes
netplan apply

echo "IP address set to $IP_ADDRESS with gateway $GATEWAY successfully on interface $INTERFACE_NAME!"
