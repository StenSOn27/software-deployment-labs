#!/bin/bash
# Manual DNS Testing Guide
# Step-by-step instructions for conducting DNS experiments

echo "DNS Resolution Research - Manual Testing Guide"
echo "=============================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

echo "This script guides you through manual DNS testing."
echo ""
echo "Opening 3 terminals is recommended:"
echo "  Terminal 1: DNS Server (this script)"
echo "  Terminal 2: Ubuntu test"
echo "  Terminal 3: Alpine test"
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 1: Create network
echo "Step 1: Creating Docker network..."
docker network create dns-lab 2>/dev/null && echo "✓ Network created" || echo "✓ Network already exists"
echo ""

read -p "Press Enter to start DNS server in background..."

# Step 2: Start DNS server
echo ""
echo "Step 2: Starting DNS server..."
echo "Watch for DNS queries below. This window will show all DNS activity."
echo ""
echo "DNS Server logs:"
echo "==========================================="

docker run --rm --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  echo 'log-queries' >> /etc/dnsmasq.conf && \
  dnsmasq -k --log-facility=-" &

DNS_PID=$!
sleep 2

# Get DNS server IP
DNS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)
echo "==========================================="
echo ""
echo "DNS Server IP: $DNS_IP"
echo ""
echo "Now open another terminal and run these commands:"
echo ""
echo "--- Ubuntu (glibc) test ---"
echo "DNS_IP=$DNS_IP"
echo "docker run --rm --network dns-lab \\"
echo "  --dns=\$DNS_IP \\"
echo "  --dns-search=\"corp\" \\"
echo "  ubuntu:latest getent hosts myservice.internal"
echo ""
echo "--- Alpine (musl) test ---"
echo "DNS_IP=$DNS_IP"
echo "docker run --rm --network dns-lab \\"
echo "  --dns=\$DNS_IP \\"
echo "  --dns-search=\"corp\" \\"
echo "  alpine:latest getent hosts myservice.internal"
echo ""
echo "When done, press Ctrl+C to stop the DNS server"
echo ""

wait $DNS_PID
