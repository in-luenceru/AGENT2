#!/bin/bash
# Real-time Network Threat Detection Daemon
# This script monitors actual network traffic and system logs for threats

LOGFILE="/home/anandhu/AGENT/logs/network_threats.log"
OSSEC_LOG="/home/anandhu/AGENT/logs/ossec.log"
PID_FILE="/tmp/network_monitor.pid"

# Function to log detected threats
log_threat() {
    local threat_type="$1"
    local details="$2"
    local timestamp=$(date '+%Y/%m/%d %H:%M:%S')
    
    echo "${timestamp} ${threat_type}: ${details}" >> "$OSSEC_LOG"
    echo "${timestamp} [AUTO-DETECTED] ${threat_type}: ${details}" >> "$LOGFILE"
}

# Function to monitor network connections
monitor_connections() {
    # Monitor for suspicious connection patterns
    netstat -tuln 2>/dev/null | while read line; do
        if echo "$line" | grep -q ":22.*ESTABLISHED"; then
            # Check for multiple SSH connections (potential brute force)
            ssh_count=$(netstat -tuln | grep -c ":22.*ESTABLISHED")
            if [ $ssh_count -gt 3 ]; then
                log_threat "BRUTE_FORCE_DETECTED" "Multiple SSH connections detected ($ssh_count active)"
            fi
        fi
        
        if echo "$line" | grep -qE ":(445|139|2049)" && echo "$line" | grep -q "LISTEN"; then
            log_threat "NFS_SMB_SERVICE" "Network file sharing service detected on $(echo $line | awk '{print $4}')"
        fi
    done
}

# Function to monitor system logs for authentication failures
monitor_auth_logs() {
    if [ -f "/var/log/auth.log" ]; then
        # Monitor for SSH brute force attempts
        failed_ssh=$(tail -n 50 /var/log/auth.log 2>/dev/null | grep "Failed password" | tail -n 5)
        if [ ! -z "$failed_ssh" ]; then
            source_ip=$(echo "$failed_ssh" | tail -n 1 | grep -o "from [0-9.]*" | cut -d' ' -f2)
            if [ ! -z "$source_ip" ]; then
                log_threat "SSH_BRUTE_FORCE" "Failed SSH login attempts detected from $source_ip"
            fi
        fi
    fi
}

# Function to monitor for port scans using network statistics
monitor_port_scans() {
    # Check for rapid connection attempts (potential port scan)
    current_conns=$(ss -tuln | wc -l)
    sleep 1
    new_conns=$(ss -tuln | wc -l)
    
    if [ $new_conns -gt $((current_conns + 5)) ]; then
        log_threat "PORT_SCAN_DETECTED" "Rapid connection increase detected (potential port scan)"
    fi
    
    # Monitor for SYN flood patterns
    syn_recv_count=$(netstat -an | grep -c "SYN_RECV")
    if [ $syn_recv_count -gt 10 ]; then
        log_threat "SYN_FLOOD_DETECTED" "High number of SYN_RECV connections ($syn_recv_count)"
    fi
}

# Function to monitor system resources for DDoS
monitor_ddos() {
    # Check network interface statistics for unusual traffic
    rx_bytes=$(cat /proc/net/dev | grep "lo:" | awk '{print $2}')
    sleep 2
    rx_bytes_new=$(cat /proc/net/dev | grep "lo:" | awk '{print $2}')
    
    if [ ! -z "$rx_bytes" ] && [ ! -z "$rx_bytes_new" ]; then
        diff=$((rx_bytes_new - rx_bytes))
        # If more than 1MB in 2 seconds on localhost (unusual)
        if [ $diff -gt 1048576 ]; then
            log_threat "HIGH_TRAFFIC_DETECTED" "Unusual network traffic spike: $diff bytes in 2 seconds"
        fi
    fi
}

# Function to monitor file system for suspicious mounts
monitor_file_mounts() {
    # Check for new network mounts
    current_mounts=$(mount | grep -E "(nfs|cifs|smb)" | wc -l)
    if [ $current_mounts -gt 0 ]; then
        mount | grep -E "(nfs|cifs|smb)" | while read mount_line; do
            if echo "$mount_line" | grep -q "rw"; then
                log_threat "NETWORK_MOUNT_DETECTED" "Network filesystem mounted: $mount_line"
            fi
        done
    fi
}

# Function to monitor kernel messages for network events
monitor_kernel_messages() {
    if [ -f "/var/log/kern.log" ]; then
        # Check for iptables/netfilter drops (potential attacks)
        recent_drops=$(tail -n 20 /var/log/kern.log 2>/dev/null | grep -i "drop\|reject\|block")
        if [ ! -z "$recent_drops" ]; then
            drop_count=$(echo "$recent_drops" | wc -l)
            log_threat "FIREWALL_DROPS" "Recent firewall drops detected ($drop_count entries)"
        fi
    fi
}

# Main monitoring loop
main_monitor() {
    echo "Starting Real-time Network Threat Detection..."
    echo "PID: $$" > "$PID_FILE"
    
    log_threat "MONITOR_STARTED" "Real-time network threat detection daemon started"
    
    while true; do
        monitor_connections
        monitor_auth_logs
        monitor_port_scans
        monitor_ddos
        monitor_file_mounts
        monitor_kernel_messages
        
        # Wait before next check
        sleep 5
    done
}

# Handle script termination
cleanup() {
    log_threat "MONITOR_STOPPED" "Real-time network threat detection daemon stopped"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start monitoring
main_monitor
