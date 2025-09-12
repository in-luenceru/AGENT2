#!/bin/bash

# Set same environment as monitor-control
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAZUH_HOME="${WAZUH_HOME:-$SCRIPT_DIR}"
BIN_DIR="${WAZUH_HOME}/bin"

REQUIRED_DAEMONS=(
    "monitor-agentd"
    "monitor-logcollector"
    "monitor-syscheckd"
    "monitor-execd"
    "monitor-modulesd"
)

echo "WAZUH_HOME: $WAZUH_HOME"
echo "BIN_DIR: $BIN_DIR"
echo "Checking for required daemons:"

for daemon in "${REQUIRED_DAEMONS[@]}"; do
    echo -n "  $daemon: "
    if [[ -f "$BIN_DIR/$daemon" ]] && [[ -x "$BIN_DIR/$daemon" ]]; then
        echo "FOUND"
    else
        echo "NOT FOUND"
    fi
done
