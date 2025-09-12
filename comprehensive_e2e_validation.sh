#!/bin/bash
# Comprehensive End-to-End Alert Validation Test
# Generates specific triggers on agent and verifies corresponding alerts on manager

echo "================================================================="
echo "COMPREHENSIVE END-TO-END ALERT VALIDATION TEST"
echo "================================================================="
echo "Testing that every agent trigger generates corresponding manager alert..."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# Configuration
AGENT_ID="003"
AGENT_NAME="codespaces-672813"
TEST_LOG="/workspaces/AGENT2/logs/e2e_validation.log"
MANAGER_CONTAINER="wazuh-manager"

# Initialize test log
echo "$(date '+%Y/%m/%d %H:%M:%S') [INFO] Starting End-to-End Alert Validation" > "$TEST_LOG"

# Test counters
TOTAL_TRIGGERS=0
VERIFIED_ALERTS=0
MISSING_ALERTS=0

# Helper function to wait for alert propagation
wait_for_alert() {
    local description="$1"
    local search_pattern="$2"
    local timeout=30
    local count=0
    
    echo "   Waiting for alert: $description"
    
    while [ $count -lt $timeout ]; do
        # Check manager alerts log
        if docker exec $MANAGER_CONTAINER grep -q "$search_pattern" /var/ossec/logs/alerts/alerts.log 2>/dev/null; then
            echo "   ✅ Alert verified: $description"
            echo "$(date '+%Y/%m/%d %H:%M:%S') [VERIFIED] $description" >> "$TEST_LOG"
            VERIFIED_ALERTS=$((VERIFIED_ALERTS + 1))
            return 0
        fi
        
        sleep 2
        count=$((count + 2))
    done
    
    echo "   ❌ Alert missing: $description"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [MISSING] $description" >> "$TEST_LOG"
    MISSING_ALERTS=$((MISSING_ALERTS + 1))
    return 1
}

# Function to generate trigger and verify alert
test_trigger() {
    local category="$1"
    local description="$2"
    local trigger_command="$3"
    local alert_pattern="$4"
    
    TOTAL_TRIGGERS=$((TOTAL_TRIGGERS + 1))
    echo
    echo "TEST $TOTAL_TRIGGERS: $category - $description"
    echo "   Generating trigger..."
    
    # Execute trigger command
    eval "$trigger_command"
    
    # Wait for corresponding alert
    wait_for_alert "$description" "$alert_pattern"
}

# Clear any existing alerts to start fresh
echo "Clearing existing manager alerts..."
docker exec $MANAGER_CONTAINER sh -c "> /var/ossec/logs/alerts/alerts.log" 2>/dev/null || true

# Wait for agent to reconnect
echo "Waiting for agent connectivity..."
sleep 5

echo
echo "Starting comprehensive trigger and alert validation..."

# Category 1: File Integrity Monitoring (FIM) Tests
echo
echo "1. FILE INTEGRITY MONITORING TESTS"

test_trigger "FIM" "File creation detection" \
    "echo 'test content' > /tmp/fim_test_file.txt" \
    "File added.*fim_test_file.txt"

test_trigger "FIM" "File modification detection" \
    "echo 'modified content' >> /tmp/fim_test_file.txt" \
    "File modified.*fim_test_file.txt"

test_trigger "FIM" "File deletion detection" \
    "rm -f /tmp/fim_test_file.txt" \
    "File deleted.*fim_test_file.txt"

test_trigger "FIM" "Suspicious file creation" \
    "echo 'malware' > /tmp/suspicious_file.exe" \
    "Suspicious.*exe"

# Category 2: Log Analysis Tests
echo
echo "2. LOG ANALYSIS TESTS"

test_trigger "LOG" "SSH failed login attempt" \
    "logger -p auth.info 'sshd[12345]: Failed password for root from 192.168.1.100 port 22 ssh2'" \
    "Failed password.*root.*192.168.1.100"

test_trigger "LOG" "Multiple authentication failures" \
    "for i in {1..5}; do logger -p auth.info \"sshd[\$\$]: Failed password for admin from 10.0.0.100 port 22 ssh2\"; done" \
    "authentication failure.*admin"

test_trigger "LOG" "Privilege escalation attempt" \
    "logger -p auth.warning 'sudo: user : TTY=pts/0 ; PWD=/home/user ; USER=root ; COMMAND=/bin/bash'" \
    "privilege.*escalation"

test_trigger "LOG" "System error message" \
    "logger -p kern.err 'kernel: Out of memory: Kill process'" \
    "kernel.*memory"

# Category 3: Process Monitoring Tests
echo
echo "3. PROCESS MONITORING TESTS"

test_trigger "PROCESS" "Suspicious process execution" \
    "sleep 1 &" \
    "New process.*sleep"

test_trigger "PROCESS" "Root process execution" \
    "(sleep 1 &)" \
    "process.*started"

# Category 4: Rootkit Detection Tests
echo
echo "4. ROOTKIT DETECTION TESTS"

test_trigger "ROOTKIT" "Suspicious binary detection" \
    "echo '#!/bin/bash\necho rootkit' > /tmp/suspicious_binary && chmod +x /tmp/suspicious_binary" \
    "Suspicious.*binary"

test_trigger "ROOTKIT" "Hidden file detection" \
    "touch /tmp/...hidden_file" \
    "hidden.*file"

# Category 5: Vulnerability Detection Tests
echo
echo "5. VULNERABILITY DETECTION TESTS"

test_trigger "VULN" "Package vulnerability scan" \
    "/workspaces/AGENT2/bin/vulnerability_scanner.sh > /dev/null 2>&1" \
    "vulnerability.*detected"

test_trigger "VULN" "CVE correlation test" \
    "echo 'openssh-server 8.0' > /tmp/test_packages.txt && /workspaces/AGENT2/bin/vulnerability_scanner.sh /tmp/test_packages.txt > /dev/null 2>&1" \
    "CVE.*openssh"

# Category 6: Network Security Tests
echo
echo "6. NETWORK SECURITY TESTS"

test_trigger "NETWORK" "Suspicious network connection" \
    "logger -p daemon.info 'Connection from 192.168.1.100:1234 to 22'" \
    "Connection.*192.168.1.100"

test_trigger "NETWORK" "Port scan detection" \
    "logger -p daemon.warning 'Multiple connection attempts from 10.0.0.200'" \
    "Multiple.*connection.*10.0.0.200"

# Category 7: Cloud Integration Tests
echo
echo "7. CLOUD INTEGRATION TESTS"

test_trigger "CLOUD" "AWS CloudTrail event" \
    "/workspaces/AGENT2/bin/cloud_monitor.sh aws > /dev/null 2>&1" \
    "AWS.*CloudTrail"

test_trigger "CLOUD" "Azure activity log" \
    "/workspaces/AGENT2/bin/cloud_monitor.sh azure > /dev/null 2>&1" \
    "Azure.*activity"

test_trigger "CLOUD" "GCP audit log" \
    "/workspaces/AGENT2/bin/cloud_monitor.sh gcp > /dev/null 2>&1" \
    "GCP.*audit"

# Category 8: Container Security Tests
echo
echo "8. CONTAINER SECURITY TESTS"

test_trigger "CONTAINER" "Docker container monitoring" \
    "/workspaces/AGENT2/bin/container_security_monitor.sh > /dev/null 2>&1" \
    "container.*security"

if command -v docker >/dev/null 2>&1; then
    test_trigger "CONTAINER" "Container privilege escalation" \
        "logger -p daemon.warning 'Container privilege escalation detected'" \
        "Container.*privilege"
fi

# Category 9: Active Response Tests
echo
echo "9. ACTIVE RESPONSE TESTS"

test_trigger "ACTIVE_RESPONSE" "IP blocking trigger" \
    "echo 'COMMAND:iptables-block\nSRCIP:203.0.113.100\nTIMEOUT:60' > /workspaces/AGENT2/queue/ar/test_block.req" \
    "Active.*response.*iptables"

test_trigger "ACTIVE_RESPONSE" "File quarantine trigger" \
    "echo 'malware sample' > /tmp/malware_test.exe && /workspaces/AGENT2/active-response/bin/file-quarantine add /tmp/malware_test.exe 0" \
    "quarantine.*malware"

# Category 10: System Integrity Tests
echo
echo "10. SYSTEM INTEGRITY TESTS"

test_trigger "INTEGRITY" "System file modification" \
    "touch /tmp/system_config_change" \
    "system.*config"

test_trigger "INTEGRITY" "Security policy violation" \
    "logger -p auth.crit 'Security policy violation detected'" \
    "policy.*violation"

# Wait for final alert processing
echo
echo "Waiting for final alert processing..."
sleep 10

# Detailed Alert Analysis
echo
echo "================================================================="
echo "DETAILED ALERT ANALYSIS"
echo "================================================================="

echo "1. Getting complete manager alert log..."
docker exec $MANAGER_CONTAINER cat /var/ossec/logs/alerts/alerts.log > /tmp/manager_alerts.log 2>/dev/null

if [ -f /tmp/manager_alerts.log ]; then
    TOTAL_MANAGER_ALERTS=$(grep -c "Alert Level" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Total alerts in manager: $TOTAL_MANAGER_ALERTS"
    
    echo
    echo "2. Alert breakdown by category:"
    
    # FIM alerts
    FIM_ALERTS=$(grep -c "syscheck" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   File Integrity: $FIM_ALERTS alerts"
    
    # Log analysis alerts
    LOG_ALERTS=$(grep -c -E "(Failed|failed|authentication)" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Log Analysis: $LOG_ALERTS alerts"
    
    # Security alerts
    SEC_ALERTS=$(grep -c -E "(security|privilege|violation)" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Security Events: $SEC_ALERTS alerts"
    
    # Network alerts
    NET_ALERTS=$(grep -c -E "(connection|network)" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Network Events: $NET_ALERTS alerts"
    
    # Cloud alerts
    CLOUD_ALERTS=$(grep -c -E "(AWS|Azure|GCP|cloud)" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Cloud Events: $CLOUD_ALERTS alerts"
    
    echo
    echo "3. Sample alerts from manager:"
    echo "   Recent alerts (last 10):"
    tail -20 /tmp/manager_alerts.log | grep -E "Alert Level|Rule|Description" | head -10
    
    echo
    echo "4. Agent-specific alerts:"
    AGENT_SPECIFIC=$(grep -c "$AGENT_NAME\|$AGENT_ID" /tmp/manager_alerts.log 2>/dev/null || echo "0")
    echo "   Alerts from our agent: $AGENT_SPECIFIC"
    
    if [ $AGENT_SPECIFIC -gt 0 ]; then
        echo "   Sample agent alerts:"
        grep -A 2 -B 2 "$AGENT_NAME\|$AGENT_ID" /tmp/manager_alerts.log | head -10
    fi
else
    echo "   ⚠️  Could not access manager alert log"
fi

# Cross-reference with agent logs
echo
echo "5. Cross-referencing with agent logs:"
if [ -d "/workspaces/AGENT2/logs" ]; then
    AGENT_EVENTS=$(find /workspaces/AGENT2/logs -name "*.log" -exec grep -c "$(date '+%Y-%m-%d')" {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')
    echo "   Agent events today: ${AGENT_EVENTS:-0}"
    
    echo "   Recent agent activity:"
    find /workspaces/AGENT2/logs -name "*.log" -exec tail -5 {} \; 2>/dev/null | head -10
fi

# Final Results Summary
echo
echo "================================================================="
echo "END-TO-END VALIDATION RESULTS"
echo "================================================================="

echo "📊 TRIGGER AND ALERT SUMMARY:"
echo "   Total Triggers Generated: $TOTAL_TRIGGERS"
echo "   Verified Manager Alerts: $VERIFIED_ALERTS"
echo "   Missing Alerts: $MISSING_ALERTS"

if [ $MISSING_ALERTS -eq 0 ]; then
    VALIDATION_RATE=100
else
    VALIDATION_RATE=$(( (VERIFIED_ALERTS * 100) / TOTAL_TRIGGERS ))
fi

echo "   Validation Rate: $VALIDATION_RATE%"

echo
echo "🔍 ALERT VERIFICATION STATUS:"
if [ $MISSING_ALERTS -eq 0 ]; then
    echo "   ✅ ALL TRIGGERS SUCCESSFULLY ALERTED"
    echo "   🎉 End-to-end validation: COMPLETE"
    echo "   The manager is properly receiving and alerting on all agent triggers!"
elif [ $VALIDATION_RATE -ge 80 ]; then
    echo "   ✅ MOSTLY SUCCESSFUL ($VALIDATION_RATE%)"
    echo "   ⚠️  Some alerts may need investigation"
    echo "   The system is largely functional with minor gaps"
else
    echo "   ❌ SIGNIFICANT GAPS DETECTED"
    echo "   🔧 Alert correlation needs attention"
    echo "   Only $VALIDATION_RATE% of triggers generated corresponding alerts"
fi

echo
echo "📋 INVESTIGATION AREAS:"
if [ $MISSING_ALERTS -gt 0 ]; then
    echo "   Check detailed log: $TEST_LOG"
    echo "   Review manager connectivity"
    echo "   Verify rule configurations"
    echo "   Check agent-manager communication"
fi

echo
echo "📁 LOG FILES FOR ANALYSIS:"
echo "   E2E Test Log: $TEST_LOG"
echo "   Manager Alerts: /tmp/manager_alerts.log"
echo "   Agent Logs: /workspaces/AGENT2/logs/"

echo
echo "================================================================="
if [ $VALIDATION_RATE -eq 100 ]; then
    echo "🎯 END-TO-END VALIDATION: PERFECT! 🎯"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [SUCCESS] All triggers properly alerted" >> "$TEST_LOG"
else
    echo "🔍 END-TO-END VALIDATION: NEEDS REVIEW"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [REVIEW] $MISSING_ALERTS triggers need investigation" >> "$TEST_LOG"
fi
echo "================================================================="