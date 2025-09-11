#!/bin/bash
# Network Packet Analysis for Threat Detection
# Uses tcpdump to monitor actual network traffic for threats

OSSEC_LOG="/home/anandhu/AGENT/logs/ossec.log"
INTERFACE="lo"  # Monitor loopback for testing, change to eth0/wlan0 for real networks
CAPTURE_FILE="/tmp/network_capture.pcap"

log_threat() {
    local threat_type="$1"
    local details="$2"
    local timestamp=$(date '+%Y/%m/%d %H:%M:%S')
    echo "${timestamp} ${threat_type}: ${details}" >> "$OSSEC_LOG"
}

# Function to analyze captured packets
analyze_packets() {
    if [ -f "$CAPTURE_FILE" ]; then
        # Check for port scanning patterns
        syn_count=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | grep -c "Flags \[S\]")
        if [ $syn_count -gt 10 ]; then
            log_threat "PORT_SCAN_DETECTED" "High SYN packet count detected: $syn_count packets (potential port scan)"
        fi
        
        # Check for SSH brute force (multiple connections to port 22)
        ssh_attempts=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | grep -c "\.22:")
        if [ $ssh_attempts -gt 5 ]; then
            log_threat "SSH_SCAN_DETECTED" "Multiple SSH connection attempts: $ssh_attempts packets"
        fi
        
        # Check for HTTP scanning
        http_requests=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | grep -c "\.80:")
        if [ $http_requests -gt 20 ]; then
            log_threat "HTTP_SCAN_DETECTED" "High HTTP traffic detected: $http_requests packets (potential web scan)"
        fi
        
        # Check for unusual traffic patterns
        total_packets=$(tcpdump -r "$CAPTURE_FILE" -n 2>/dev/null | wc -l)
        if [ $total_packets -gt 100 ]; then
            log_threat "HIGH_TRAFFIC_VOLUME" "High packet volume detected: $total_packets packets in monitoring window"
        fi
        
        # Clean up old capture file
        rm -f "$CAPTURE_FILE"
    fi
}

# Start packet capture and analysis loop
start_monitoring() {
    log_threat "PACKET_MONITOR_STARTED" "Network packet monitoring started on interface $INTERFACE"
    
    while true; do
        # Capture packets for 10 seconds
        timeout 10 tcpdump -i "$INTERFACE" -w "$CAPTURE_FILE" -c 100 2>/dev/null
        
        # Analyze the captured packets
        analyze_packets
        
        # Short pause before next capture
        sleep 2
    done
}

# Check if tcpdump is available
if ! command -v tcpdump &> /dev/null; then
    log_threat "PACKET_MONITOR_ERROR" "tcpdump not available - packet-level monitoring disabled"
    exit 1
fi

# Start monitoring
start_monitoring
