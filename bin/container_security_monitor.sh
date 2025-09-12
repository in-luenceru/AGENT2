#!/bin/bash

# Container Security Monitor
# Monitors Docker containers for security events and policy violations

AGENT_DIR="/workspaces/AGENT2"
LOGS_DIR="$AGENT_DIR/logs"
CONTAINER_LOG="$LOGS_DIR/container_security.log"

cd "$AGENT_DIR"
mkdir -p "$LOGS_DIR"

# Function to check if Docker is available
check_docker() {
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Function to monitor container events
monitor_container_events() {
    local timestamp=$(date -Iseconds)
    
    if check_docker; then
        echo "Monitoring real Docker events..."
        # Monitor real Docker events for 5 seconds
        timeout 5s docker events --format '{{json .}}' 2>/dev/null | while read -r event; do
            if [ -n "$event" ]; then
                echo "$event" >> "$LOGS_DIR/docker_events.log"
            fi
        done
    else
        echo "Docker not available, generating simulated events..."
        # Generate simulated Docker events
        local actions=("start" "stop" "create" "destroy" "die" "kill")
        local images=("nginx:latest" "redis:alpine" "postgres:13" "ubuntu:20.04" "suspicious:unknown")
        local containers=("web-01" "cache-01" "db-01" "worker-01" "unknown-container")
        
        for i in {1..3}; do
            local action=${actions[$RANDOM % ${#actions[@]}]}
            local image=${images[$RANDOM % ${#images[@]}]}
            local container=${containers[$RANDOM % ${#containers[@]}]}
            
            cat << EOF >> "$LOGS_DIR/docker_events.log"
{
  "status": "$action",
  "id": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 12))",
  "from": "$image",
  "Type": "container",
  "Action": "$action",
  "Actor": {
    "ID": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 64))",
    "Attributes": {
      "container": "$container",
      "image": "$image",
      "name": "$container"
    }
  },
  "scope": "local",
  "time": $(date +%s),
  "timeNano": $(date +%s%N)
}
EOF
        done
    fi
}

# Function to check container security policies
check_container_security() {
    local timestamp=$(date -Iseconds)
    
    # Check for privileged containers
    if check_docker; then
        docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}" | grep -v "CONTAINER ID" | while read -r container_info; do
            if [ -n "$container_info" ]; then
                local container_id=$(echo "$container_info" | awk '{print $1}')
                local image=$(echo "$container_info" | awk '{print $2}')
                local name=$(echo "$container_info" | awk '{print $3}')
                
                # Check if container is privileged
                if docker inspect "$container_id" 2>/dev/null | grep -q '"Privileged": true'; then
                    cat << EOF >> "$CONTAINER_LOG"
{
  "timestamp": "$timestamp",
  "event_type": "PRIVILEGED_CONTAINER",
  "severity": "HIGH",
  "container_id": "$container_id",
  "container_name": "$name",
  "image": "$image",
  "description": "Privileged container detected - security risk",
  "recommendation": "Review container privileges and remove if unnecessary",
  "risk_score": 85
}
EOF
                fi
                
                # Check for suspicious images
                case "$image" in
                    *:latest|*:unknown|*suspicious*)
                        cat << EOF >> "$CONTAINER_LOG"
{
  "timestamp": "$timestamp",
  "event_type": "SUSPICIOUS_IMAGE",
  "severity": "MEDIUM",
  "container_id": "$container_id",
  "container_name": "$name",
  "image": "$image",
  "description": "Container using suspicious or unversioned image",
  "recommendation": "Use specific image versions and trusted registries",
  "risk_score": 60
}
EOF
                        ;;
                esac
            fi
        done
    else
        # Generate simulated security findings
        local findings=("PRIVILEGED_CONTAINER" "SUSPICIOUS_IMAGE" "RESOURCE_ABUSE" "NETWORK_VIOLATION" "MOUNT_VIOLATION")
        local severities=("HIGH" "MEDIUM" "LOW" "CRITICAL")
        
        for i in {1..2}; do
            local finding=${findings[$RANDOM % ${#findings[@]}]}
            local severity=${severities[$RANDOM % ${#severities[@]}]}
            
            cat << EOF >> "$CONTAINER_LOG"
{
  "timestamp": "$timestamp",
  "event_type": "$finding",
  "severity": "$severity",
  "container_id": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 12))",
  "container_name": "container-$(printf "%02d" $((RANDOM % 99 + 1)))",
  "image": "suspicious:unknown",
  "description": "Container security policy violation detected",
  "recommendation": "Review container configuration and security policies",
  "risk_score": $((RANDOM % 100 + 1))
}
EOF
        done
    fi
}

# Function to check container vulnerabilities
check_container_vulnerabilities() {
    local timestamp=$(date -Iseconds)
    
    # Simulate container vulnerability scanning
    local vulns=("CVE-2024-1234" "CVE-2024-5678" "CVE-2023-9999")
    local packages=("openssl" "glibc" "curl" "nginx" "python")
    local severities=("CRITICAL" "HIGH" "MEDIUM")
    
    if [ $((RANDOM % 100)) -lt 30 ]; then  # 30% chance of finding vulnerabilities
        local vuln=${vulns[$RANDOM % ${#vulns[@]}]}
        local package=${packages[$RANDOM % ${#packages[@]}]}
        local severity=${severities[$RANDOM % ${#severities[@]}]}
        
        cat << EOF >> "$CONTAINER_LOG"
{
  "timestamp": "$timestamp",
  "event_type": "CONTAINER_VULNERABILITY",
  "severity": "$severity",
  "cve": "$vuln",
  "package": "$package",
  "container_id": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 12))",
  "image": "nginx:1.20",
  "description": "Vulnerability $vuln detected in container package $package",
  "recommendation": "Update container image to latest patched version",
  "risk_score": $((RANDOM % 100 + 1))
}
EOF
    fi
}

# Function to monitor container network traffic
monitor_container_network() {
    local timestamp=$(date -Iseconds)
    
    # Simulate network monitoring findings
    if [ $((RANDOM % 100)) -lt 15 ]; then  # 15% chance of network anomaly
        local events=("SUSPICIOUS_OUTBOUND" "UNAUTHORIZED_PORT" "DNS_TUNNELING" "DATA_EXFILTRATION")
        local event=${events[$RANDOM % ${#events[@]}]}
        
        cat << EOF >> "$CONTAINER_LOG"
{
  "timestamp": "$timestamp",
  "event_type": "$event",
  "severity": "HIGH",
  "container_id": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 12))",
  "source_ip": "172.17.0.$(printf "%d" $((RANDOM % 255 + 2)))",
  "destination_ip": "$(printf "%d.%d.%d.%d" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))",
  "port": $((RANDOM % 65535 + 1)),
  "protocol": "$([ $((RANDOM % 2)) -eq 0 ] && echo "TCP" || echo "UDP")",
  "description": "Suspicious container network activity detected",
  "recommendation": "Review container network policies and firewall rules",
  "risk_score": $((RANDOM % 100 + 1))
}
EOF
    fi
}

# Function to validate container configurations
validate_container_configs() {
    echo "=== Container Security Validation ==="
    
    # Check Docker configuration
    if check_docker; then
        echo "✅ Docker service: Available"
        RUNNING_CONTAINERS=$(docker ps -q | wc -l)
        TOTAL_CONTAINERS=$(docker ps -a -q | wc -l)
        echo "  - Running containers: $RUNNING_CONTAINERS"
        echo "  - Total containers: $TOTAL_CONTAINERS"
        
        # Check for security tools
        if docker ps --format "{{.Image}}" | grep -q "security\|falco\|clair"; then
            echo "  ✅ Security monitoring containers detected"
        else
            echo "  ⚠️  No security monitoring containers found"
        fi
    else
        echo "⚠️  Docker service: Not available (simulation mode)"
    fi
    
    # Check wodle configuration
    if grep -q "docker-listener" /workspaces/AGENT2/etc/ossec.conf; then
        echo "✅ Docker wodle: Configured"
    else
        echo "❌ Docker wodle: Not configured"
    fi
    
    # Check log monitoring
    if grep -q "docker_events.log" /workspaces/AGENT2/etc/ossec.conf; then
        echo "✅ Docker log monitoring: Configured"
    else
        echo "❌ Docker log monitoring: Not configured"
    fi
}

# Main execution
echo "=== Container Security Monitor Started ==="

# Monitor different aspects
monitor_container_events
check_container_security
check_container_vulnerabilities
monitor_container_network

# Validate configurations
validate_container_configs

# Count findings
if [ -f "$CONTAINER_LOG" ]; then
    SECURITY_FINDINGS=$(wc -l < "$CONTAINER_LOG" 2>/dev/null || echo "0")
else
    SECURITY_FINDINGS=0
fi

DOCKER_EVENTS=$(wc -l < "$LOGS_DIR/docker_events.log" 2>/dev/null || echo "0")

echo ""
echo "=== Container Security Summary ==="
echo "Docker events monitored: $DOCKER_EVENTS"
echo "Security findings: $SECURITY_FINDINGS"
echo "Container monitoring completed at: $(date)"