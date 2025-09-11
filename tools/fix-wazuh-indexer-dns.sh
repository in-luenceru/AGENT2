#!/usr/bin/env bash
set -euo pipefail

# Fix /etc/hosts in the running wazuh-manager container so 'wazuh.indexer' resolves.
# Strategy:
# 1. Try to find an indexer container (wazuh-indexer, indexer, elasticsearch).
# 2. If found, use its container IP. If not, fall back to 127.0.0.1 and warn.
# 3. Add an idempotent entry to /etc/hosts inside the wazuh-manager container.
# 4. Verify resolution.

CONTAINER_MANAGER="wazuh-manager"

echo "[info] Fixing DNS for 'wazuh.indexer' in container: $CONTAINER_MANAGER"

# Ensure docker is available
if ! command -v docker >/dev/null 2>&1; then
  echo "[error] docker not found on PATH" >&2
  exit 1
fi

# Find an indexer-like container
INDEXER_NAME=$(docker ps -a --format '{{.Names}}' | grep -E 'wazuh[-_]?indexer|indexer|elasticsearch' | head -n1 || true)

if [ -n "$INDEXER_NAME" ]; then
  echo "[info] Found indexer container: $INDEXER_NAME"
  INDEXER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$INDEXER_NAME" 2>/dev/null || true)
  if [ -z "$INDEXER_IP" ]; then
    echo "[warn] Could not determine indexer container IP; falling back to 127.0.0.1"
    INDEXER_IP="127.0.0.1"
  fi
else
  echo "[warn] No indexer container found. Falling back to 127.0.0.1"
  INDEXER_IP="127.0.0.1"
fi

# Ensure the manager container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_MANAGER}$"; then
  echo "[error] Container '$CONTAINER_MANAGER' not found. Aborting." >&2
  exit 1
fi

# Check existing hosts entry inside container
EXISTS=$(docker exec "$CONTAINER_MANAGER" bash -lc "grep -E '\\b(wazuh\\.indexer)\\b' /etc/hosts || true")
if [ -n "$EXISTS" ]; then
  echo "[info] /etc/hosts inside $CONTAINER_MANAGER already contains an entry for wazuh.indexer:\n$EXISTS"
  # If present but different IP, update it
  CURRENT_IP=$(echo "$EXISTS" | awk '{print $1}' | head -n1)
  if [ "$CURRENT_IP" != "$INDEXER_IP" ]; then
    echo "[info] Updating wazuh.indexer mapping from $CURRENT_IP to $INDEXER_IP"
    docker exec "$CONTAINER_MANAGER" bash -lc "sed -i.bak '/wazuh.indexer/d' /etc/hosts && echo '${INDEXER_IP} wazuh.indexer' >> /etc/hosts"
  else
    echo "[info] Mapping already correct"
  fi
else
  echo "[info] Adding mapping: $INDEXER_IP wazuh.indexer"
  docker exec "$CONTAINER_MANAGER" bash -lc "echo '${INDEXER_IP} wazuh.indexer' >> /etc/hosts"
fi

# Verify
echo "[info] Verifying resolution inside container"
# Use getent if available, fallback to ping -c0 or grep
RES=$(docker exec "$CONTAINER_MANAGER" bash -lc "getent hosts wazuh.indexer || awk '/wazuh.indexer/ {print \$1}' /etc/hosts || true")
if [ -n "$RES" ]; then
  echo "[success] wazuh.indexer resolves to:"
  docker exec "$CONTAINER_MANAGER" bash -lc "getent hosts wazuh.indexer || grep wazuh.indexer /etc/hosts || true"
else
  echo "[error] Resolution failed inside container. Show /etc/hosts:"
  docker exec "$CONTAINER_MANAGER" cat /etc/hosts
  exit 1
fi

# Optional: restart manager container to ensure services pick up change if needed
# echo "[info] Restarting $CONTAINER_MANAGER to ensure services pick up hosts change"
# docker restart "$CONTAINER_MANAGER"

echo "[done] fix applied. If the indexer is on a different machine, consider using a stable IP or Docker network alias (recommended)."
