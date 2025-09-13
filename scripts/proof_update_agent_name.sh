#!/bin/bash

# Proof script: update agent name, restart agent, verify on manager, and record proof
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENT_CONTROL="$ROOT_DIR/monitor-control"
IDENTITY_LIB="$ROOT_DIR/lib/agent_identity.sh"
PROOF_FILE="$ROOT_DIR/PROOF_AGENT_NAME_UPDATE.md"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 NEW_AGENT_NAME"
    exit 2
fi

NEW_NAME="$1"

if [[ ! -f "$IDENTITY_LIB" ]]; then
    echo "Identity library not found: $IDENTITY_LIB"
    exit 1
fi

source "$IDENTITY_LIB"

echo "Setting agent name to: $NEW_NAME"
# Call with explicit second parameter to avoid unbound variable when library is sourced with set -u
if ! set_agent_name "$NEW_NAME" ""; then
    echo "Failed to set agent name via identity library"
    exit 1
fi

echo "Restarting agent to apply name change..."
sudo "$AGENT_CONTROL" restart

echo "Collecting evidence from manager..."
MANAGER_LIST=$(docker exec wazuh-manager /var/ossec/bin/agent_control -l || true)
# Attempt to derive agent id from identity file
AGENT_ID=$(grep -m1 '^AGENT_ID=' "$ROOT_DIR/etc/agent.identity" 2>/dev/null | cut -d'"' -f2 || echo "")
MANAGER_INFO=""
if [[ -n "$AGENT_ID" ]]; then
    MANAGER_INFO=$(docker exec wazuh-manager /var/ossec/bin/agent_control -i $AGENT_ID 2>/dev/null || true)
fi
RECENT_ALERTS=$(docker exec wazuh-manager tail -50 /var/ossec/logs/alerts/alerts.log | grep -E "\($NEW_NAME\)" -n -B 2 -A 3 || true)
IDENTITY_FILE=$(sudo cat "$ROOT_DIR/etc/agent.identity" || true)
CLIENT_KEYS=$(sudo cat "$ROOT_DIR/etc/client.keys" || true)

cat > "$PROOF_FILE" <<EOF
# Proof of Agent Name Update

Date: $(date -u)

Requested new agent name: $NEW_NAME

Manager agent list output:

$MANAGER_LIST

Detailed agent info (if available):

$MANAGER_INFO

Recent alerts mentioning the agent name:

$RECENT_ALERTS

Local identity file contents:

$IDENTITY_FILE

Local client.keys contents:

$CLIENT_KEYS

EOF

echo "Proof written to: $PROOF_FILE"

exit 0
