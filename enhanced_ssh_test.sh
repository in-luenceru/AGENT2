#!/bin/bash

# 🎯 ENHANCED SSH ATTACK SIMULATION
# Tests improved detection capabilities

echo "🔥 ENHANCED SSH BRUTE FORCE SIMULATION"
echo "======================================"

# Start SSH service if not running
if ! systemctl is-active --quiet ssh; then
    echo "Starting SSH service..."
    sudo systemctl start ssh
fi

# Generate SSH failures that should now be detected
echo "Generating SSH authentication failures..."
for i in {1..8}; do
    echo "Attempt $i: SSH login failure"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PasswordAuthentication=yes fakeuser@127.0.0.1 "echo test" 2>/dev/null || true
    sleep 3
done

echo "Waiting 30 seconds for detection..."
sleep 30

echo "Checking for SSH-related alerts..."
docker exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.log | grep -i ssh || echo "No SSH alerts yet"

echo "Checking auth.log monitoring..."
sudo tail -10 /var/log/auth.log | grep ssh || echo "No SSH events in auth.log"
