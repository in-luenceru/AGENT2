#!/bin/bash

# Wazuh Agent Runner - Uses system binaries with custom config
# This script provides proper Wazuh agent functionality for testing

AGENT_DIR="/home/anandhu/AGENT"
OSSEC_CONF="$AGENT_DIR/etc/ossec.conf"
CLIENT_KEYS="$AGENT_DIR/etc/client.keys"
AGENT_PID_FILE="$AGENT_DIR/var/run/wazuh-agentd.pid"
AGENT_LOG="$AGENT_DIR/logs/ossec.log"

# Ensure directories exist
mkdir -p "$AGENT_DIR/var/run" "$AGENT_DIR/logs"

# Export environment variables for Wazuh agent
export OSSEC_ROOT="$AGENT_DIR"

echo "[$(date)] Starting Wazuh agent with custom configuration..."
echo "[$(date)] Config: $OSSEC_CONF"
echo "[$(date)] Keys: $CLIENT_KEYS"

# Check if keys exist
if [[ ! -f "$CLIENT_KEYS" ]]; then
    echo "[$(date)] ERROR: Client keys not found at $CLIENT_KEYS"
    exit 1
fi

# Check if config exists
if [[ ! -f "$OSSEC_CONF" ]]; then
    echo "[$(date)] ERROR: Configuration not found at $OSSEC_CONF"
    exit 1
fi

# Kill any existing agent
if [[ -f "$AGENT_PID_FILE" ]]; then
    OLD_PID=$(cat "$AGENT_PID_FILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[$(date)] Killing existing agent (PID: $OLD_PID)"
        kill "$OLD_PID"
        sleep 2
    fi
fi

# Start the agent using system binary but custom config
echo "[$(date)] Starting wazuh-agentd..."

# Use system wazuh-agentd but point to custom config
sudo OSSEC_ROOT="$AGENT_DIR" /var/ossec/bin/wazuh-agentd -c "$OSSEC_CONF" &
AGENT_PID=$!

echo $AGENT_PID > "$AGENT_PID_FILE"
echo "[$(date)] Wazuh agent started (PID: $AGENT_PID)"

# Monitor for a few seconds
sleep 5
if kill -0 $AGENT_PID 2>/dev/null; then
    echo "[$(date)] Agent is running successfully"
    echo "[$(date)] Check logs: tail -f $AGENT_LOG"
else
    echo "[$(date)] ERROR: Agent failed to start or died"
    exit 1
fi
