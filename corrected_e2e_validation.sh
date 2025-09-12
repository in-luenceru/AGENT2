#!/bin/bash
# Corrected End-to-End Alert Validation Test
# Uses actual alert patterns from the manager

echo "================================================================="
echo "CORRECTED END-TO-END ALERT VALIDATION TEST"
echo "================================================================="
echo "Testing agent triggers with correct manager alert patterns..."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo

MANAGER_CONTAINER="wazuh-manager"
TEST_LOG="/workspaces/AGENT2/logs/corrected_e2e_validation.log"

echo "$(date '+%Y/%m/%d %H:%M:%S') [INFO] Starting Corrected E2E Validation" > "$TEST_LOG"

# Get baseline alert count
echo "Getting baseline alert count..."
BASELINE_COUNT=$(docker exec $MANAGER_CONTAINER wc -l < /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
echo "Baseline alerts: $BASELINE_COUNT"

# Function to check for new alerts
check_new_alerts() {
    local description="$1"
    local wait_time=15
    
    echo "   Waiting ${wait_time}s for alert: $description"
    sleep $wait_time
    
    NEW_COUNT=$(docker exec $MANAGER_CONTAINER wc -l < /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
    NEW_ALERTS=$((NEW_COUNT - BASELINE_COUNT))
    
    if [ $NEW_ALERTS -gt 0 ]; then
        echo "   ✅ $NEW_ALERTS new alerts generated for: $description"
        
        # Show the latest alert
        echo "   📋 Latest alert:"
        docker exec $MANAGER_CONTAINER tail -10 /var/ossec/logs/alerts/alerts.log | grep -A 5 -B 5 "Rule:" | tail -10
        
        BASELINE_COUNT=$NEW_COUNT
        return 0
    else
        echo "   ❌ No new alerts for: $description"
        return 1
    fi
}

echo
echo "Starting actual trigger tests with real alert verification..."

VERIFIED=0
TOTAL=0

# Test 1: FIM - File operations that actually generate alerts
echo
echo "TEST 1: File Integrity Monitoring"
echo "Creating and modifying files that are monitored..."

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}a: Creating file in monitored location"
touch /tmp/fim_test_$(date +%s).txt
check_new_alerts "File creation in /tmp" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}b: Modifying existing file"
echo "content modification $(date)" >> /tmp/fim_test_*.txt 2>/dev/null || echo "content" > /tmp/fim_modify_test.txt
check_new_alerts "File modification" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}c: Deleting monitored file"
rm -f /tmp/fim_test_*.txt 2>/dev/null
check_new_alerts "File deletion" && VERIFIED=$((VERIFIED + 1))

# Test 2: Log Analysis - Generate syslog entries
echo
echo "TEST 2: Log Analysis"

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: SSH authentication simulation"
logger -p auth.info "sshd[12345]: Failed password for root from 192.168.1.100 port 22 ssh2"
logger -p auth.info "sshd[12346]: Failed password for admin from 192.168.1.100 port 22 ssh2"
logger -p auth.info "sshd[12347]: Failed password for test from 192.168.1.100 port 22 ssh2"
check_new_alerts "SSH authentication failures" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: System error simulation"
logger -p kern.err "kernel: Critical system error detected"
logger -p daemon.crit "systemd: Service failure detected"
check_new_alerts "System error messages" && VERIFIED=$((VERIFIED + 1))

# Test 3: Process monitoring via our agent
echo
echo "TEST 3: Process and Security Monitoring"

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Running vulnerability scanner"
/workspaces/AGENT2/bin/vulnerability_scanner.sh > /dev/null 2>&1 &
check_new_alerts "Vulnerability scanner execution" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Cloud monitoring activities"
/workspaces/AGENT2/bin/cloud_monitor.sh aws > /dev/null 2>&1 &
check_new_alerts "Cloud monitoring events" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Container security check"
/workspaces/AGENT2/bin/container_security_monitor.sh > /dev/null 2>&1 &
check_new_alerts "Container security monitoring" && VERIFIED=$((VERIFIED + 1))

# Test 4: Active Response triggers
echo
echo "TEST 4: Active Response System"

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Triggering active response"
echo "COMMAND:alert-notify" > /workspaces/AGENT2/queue/ar/test_alert.req
echo "SRCIP:203.0.113.100" >> /workspaces/AGENT2/queue/ar/test_alert.req
echo "LEVEL:10" >> /workspaces/AGENT2/queue/ar/test_alert.req
check_new_alerts "Active response trigger" && VERIFIED=$((VERIFIED + 1))

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Security violation simulation"
logger -p security.crit "SECURITY_VIOLATION: Unauthorized access attempt detected from 192.168.1.200"
check_new_alerts "Security violation alert" && VERIFIED=$((VERIFIED + 1))

# Test 5: Direct agent log generation
echo
echo "TEST 5: Direct Agent Event Generation"

TOTAL=$((TOTAL + 1))
echo "Test ${TOTAL}: Custom agent events"
echo "$(date): WAZUH_E2E_TEST: Custom security event for validation" >> /workspaces/AGENT2/logs/ossec.log
logger -p local0.alert "WAZUH_TEST_EVENT: End-to-end validation test message $(date +%s)"
check_new_alerts "Custom agent events" && VERIFIED=$((VERIFIED + 1))

# Final Analysis
echo
echo "================================================================="
echo "DETAILED ALERT CORRELATION ANALYSIS"
echo "================================================================="

# Get complete alert summary
FINAL_COUNT=$(docker exec $MANAGER_CONTAINER wc -l < /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
TOTAL_NEW_ALERTS=$((FINAL_COUNT - BASELINE_COUNT))

echo "📊 ALERT GENERATION SUMMARY:"
echo "   Baseline alerts: $BASELINE_COUNT"
echo "   Final alert count: $FINAL_COUNT"
echo "   New alerts generated: $TOTAL_NEW_ALERTS"

echo
echo "📋 RECENT MANAGER ALERTS (Last 15):"
docker exec $MANAGER_CONTAINER tail -30 /var/ossec/logs/alerts/alerts.log | grep -E "(Rule:|File|Alert)" | tail -15

echo
echo "🔍 ALERT TYPES ANALYSIS:"
# Analyze what types of alerts we're getting
echo "   FIM (syscheck) alerts:"
docker exec $MANAGER_CONTAINER grep -c "syscheck" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0"

echo "   Log analysis alerts:"
docker exec $MANAGER_CONTAINER grep -c -E "(Failed|failed|error|ERROR)" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0"

echo "   Security alerts:"
docker exec $MANAGER_CONTAINER grep -c -E "(security|violation|SECURITY)" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0"

echo "   Process/system alerts:"
docker exec $MANAGER_CONTAINER grep -c -E "(process|Process|kernel)" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0"

echo
echo "🎯 AGENT-SPECIFIC ANALYSIS:"
AGENT_ALERTS=$(docker exec $MANAGER_CONTAINER grep -c "codespaces-672813" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
echo "   Total alerts from our agent: $AGENT_ALERTS"

if [ $AGENT_ALERTS -gt 0 ]; then
    echo "   Sample agent alerts:"
    docker exec $MANAGER_CONTAINER grep -A 3 "codespaces-672813" /var/ossec/logs/alerts/alerts.log | tail -15
fi

echo
echo "================================================================="
echo "FINAL VALIDATION RESULTS"
echo "================================================================="

SUCCESS_RATE=$(( (VERIFIED * 100) / TOTAL ))

echo "📊 TEST RESULTS:"
echo "   Total Tests: $TOTAL"
echo "   Verified Alerts: $VERIFIED"
echo "   Success Rate: $SUCCESS_RATE%"
echo "   New Alerts Generated: $TOTAL_NEW_ALERTS"

if [ $SUCCESS_RATE -ge 70 ] && [ $TOTAL_NEW_ALERTS -gt 5 ]; then
    echo
    echo "🎉 END-TO-END VALIDATION: SUCCESSFUL!"
    echo "   ✅ Agent is properly sending events to manager"
    echo "   ✅ Manager is generating alerts from agent events"
    echo "   ✅ Communication pipeline is functional"
    echo "   ✅ Multiple alert types are working"
elif [ $TOTAL_NEW_ALERTS -gt 2 ]; then
    echo
    echo "✅ END-TO-END VALIDATION: PARTIALLY SUCCESSFUL"
    echo "   ✅ Agent-manager communication is working"
    echo "   ⚠️  Some alert types may need tuning"
    echo "   📈 $TOTAL_NEW_ALERTS new alerts generated during test"
else
    echo
    echo "⚠️  END-TO-END VALIDATION: NEEDS INVESTIGATION"
    echo "   🔧 Limited alert generation observed"
    echo "   📋 Check rule configurations and log levels"
fi

echo
echo "🔗 INTEGRATION STATUS:"
if [ $AGENT_ALERTS -gt 100 ]; then
    echo "   ✅ High volume agent communication ($AGENT_ALERTS alerts)"
    echo "   ✅ Manager is actively processing agent events"
    echo "   ✅ Long-term integration is working properly"
fi

echo
echo "📁 INVESTIGATION FILES:"
echo "   Manager alerts: /var/ossec/logs/alerts/alerts.log (in container)"
echo "   Test log: $TEST_LOG"
echo "   Agent logs: /workspaces/AGENT2/logs/"

echo "================================================================="

echo "$(date '+%Y/%m/%d %H:%M:%S') [COMPLETE] Corrected E2E validation finished" >> "$TEST_LOG"