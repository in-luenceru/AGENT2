#!/bin/bash

# Fixed End-to-End Alert Validation Test
# Tests agent triggers and verifies corresponding manager alerts

echo "================================================================="
echo "FIXED END-TO-END ALERT VALIDATION TEST"
echo "================================================================="
echo "Testing agent triggers with proper manager alert access..."
echo "Date: $(date)"
echo

# Function to get alerts from manager container
get_manager_alerts() {
    docker exec wazuh-manager cat /var/ossec/logs/alerts/alerts.log 2>/dev/null | wc -l
}

# Function to get recent alerts from manager
get_recent_alerts() {
    local count=${1:-10}
    docker exec wazuh-manager tail -n $count /var/ossec/logs/alerts/alerts.log 2>/dev/null
}

# Function to check for specific alert pattern
check_alert_pattern() {
    local pattern="$1"
    local description="$2"
    
    echo "   Waiting 15s for alert: $description"
    sleep 15
    
    # Get recent alerts and search for pattern
    local recent_alerts=$(docker exec wazuh-manager tail -n 50 /var/ossec/logs/alerts/alerts.log 2>/dev/null)
    
    if echo "$recent_alerts" | grep -q "$pattern"; then
        echo "   ✅ Alert found for: $description"
        return 0
    else
        echo "   ❌ No matching alert for: $description"
        return 1
    fi
}

echo "Getting baseline alert count..."
baseline_alerts=$(get_manager_alerts)
echo "Baseline alerts: $baseline_alerts"
echo

echo "Starting trigger tests with proper Docker access..."
echo

verified_alerts=0
total_tests=0

echo "TEST 1: File Integrity Monitoring"
echo "Creating and modifying files that are monitored..."

# Test 1a: File creation
echo "Test 1a: Creating file in monitored location"
mkdir -p /tmp/test_fim
echo "test content $(date)" > /tmp/test_fim/test_file.txt
total_tests=$((total_tests + 1))
if check_alert_pattern "test_file\.txt.*modified\|test_file\.txt.*added\|syscheck" "File creation in /tmp"; then
    verified_alerts=$((verified_alerts + 1))
fi

# Test 1b: File modification
echo "Test 1b: Modifying existing file"
echo "modified content $(date)" >> /tmp/test_fim/test_file.txt
total_tests=$((total_tests + 1))
if check_alert_pattern "test_file\.txt.*modified\|checksum changed" "File modification"; then
    verified_alerts=$((verified_alerts + 1))
fi

# Test 1c: File deletion
echo "Test 1c: Deleting monitored file"
rm -f /tmp/test_fim/test_file.txt
total_tests=$((total_tests + 1))
if check_alert_pattern "test_file\.txt.*deleted\|removed" "File deletion"; then
    verified_alerts=$((verified_alerts + 1))
fi

echo
echo "TEST 2: Log Analysis"

# Test 2a: SSH simulation
echo "Test 2a: SSH authentication simulation"
echo "$(date) sshd[12345]: Failed password for invalid user test from 192.168.1.100 port 22 ssh2" >> /var/log/auth.log 2>/dev/null || echo "$(date) sshd[12345]: Failed password for invalid user test from 192.168.1.100 port 22 ssh2" > /tmp/auth_test.log
total_tests=$((total_tests + 1))
if check_alert_pattern "Failed password\|SSH.*authentication\|sshd" "SSH authentication failures"; then
    verified_alerts=$((verified_alerts + 1))
fi

# Test 2b: System error simulation
echo "Test 2b: System error simulation"
logger "CRITICAL: System error detected - test message $(date)"
total_tests=$((total_tests + 1))
if check_alert_pattern "CRITICAL\|System error\|error detected" "System error messages"; then
    verified_alerts=$((verified_alerts + 1))
fi

echo
echo "TEST 3: Security Configuration Assessment"

# Test 3a: SCA trigger
echo "Test 3a: SCA configuration check"
# Trigger SCA scan
/workspaces/AGENT2/bin/wazuh-modulesd -t &
sleep 3
pkill -f wazuh-modulesd
total_tests=$((total_tests + 1))
if check_alert_pattern "SCA\|Security Configuration\|policy" "SCA configuration check"; then
    verified_alerts=$((verified_alerts + 1))
fi

echo
echo "TEST 4: Process Monitoring"

# Test 4a: Suspicious process
echo "Test 4a: Running suspicious process"
nohup sleep 300 &
suspicious_pid=$!
total_tests=$((total_tests + 1))
if check_alert_pattern "process.*started\|new process\|sleep" "Process monitoring"; then
    verified_alerts=$((verified_alerts + 1))
fi
kill $suspicious_pid 2>/dev/null

echo
echo "TEST 5: Direct Agent Communication"

# Test 5a: Agent restart to trigger agent events
echo "Test 5a: Agent restart events"
systemctl restart wazuh-agent 2>/dev/null || /workspaces/AGENT2/start-agent.sh restart
sleep 10
total_tests=$((total_tests + 1))
if check_alert_pattern "agent.*started\|ossec.*started\|wazuh.*started" "Agent restart events"; then
    verified_alerts=$((verified_alerts + 1))
fi

echo
echo "================================================================="
echo "COMPREHENSIVE ALERT ANALYSIS"
echo "================================================================="

# Get final alert count
final_alerts=$(get_manager_alerts)
new_alerts=$((final_alerts - baseline_alerts))

echo "📊 ALERT GENERATION SUMMARY:"
echo "   Baseline alerts: $baseline_alerts"
echo "   Final alert count: $final_alerts"
echo "   New alerts generated: $new_alerts"
echo

echo "📋 RECENT MANAGER ALERTS (Last 20):"
get_recent_alerts 20
echo

echo "🔍 AGENT-SPECIFIC ANALYSIS:"
agent_alerts=$(docker exec wazuh-manager grep -c "codespaces-672813" /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "0")
echo "   Total alerts from our agent: $agent_alerts"
echo

echo "   Sample recent agent alerts:"
docker exec wazuh-manager grep "codespaces-672813" /var/ossec/logs/alerts/alerts.log 2>/dev/null | tail -5 | while read line; do
    echo "   -> $line"
done
echo

echo "================================================================="
echo "FINAL VALIDATION RESULTS"
echo "================================================================="

success_rate=$((verified_alerts * 100 / total_tests))

echo "📊 TEST RESULTS:"
echo "   Total Tests: $total_tests"
echo "   Verified Alerts: $verified_alerts"
echo "   Success Rate: $success_rate%"
echo "   New Alerts Generated: $new_alerts"
echo

if [ $success_rate -ge 70 ]; then
    echo "✅ END-TO-END VALIDATION: PASSED"
    echo "   🎯 High success rate indicates proper agent-manager integration"
elif [ $success_rate -ge 40 ]; then
    echo "⚠️  END-TO-END VALIDATION: PARTIAL SUCCESS"
    echo "   🔧 Some triggers working, check specific rule configurations"
else
    echo "❌ END-TO-END VALIDATION: NEEDS ATTENTION"
    echo "   🔧 Limited trigger-to-alert correlation observed"
fi

echo
echo "🔗 INTEGRATION STATUS:"
if [ $agent_alerts -gt 100 ]; then
    echo "   ✅ High volume agent communication ($agent_alerts total alerts)"
    echo "   ✅ Manager is actively processing agent events"
    echo "   ✅ Long-term integration is working properly"
else
    echo "   ⚠️  Low agent communication volume"
    echo "   🔧 Check agent connectivity and configuration"
fi

echo
echo "📁 LOG FILES FOR INVESTIGATION:"
echo "   Manager alerts: docker exec wazuh-manager cat /var/ossec/logs/alerts/alerts.log"
echo "   Agent logs: /workspaces/AGENT2/logs/"
echo "   Test log: /workspaces/AGENT2/logs/fixed_e2e_validation.log"
echo "================================================================="

# Save results to log file
mkdir -p /workspaces/AGENT2/logs
{
    echo "Fixed E2E Validation Results - $(date)"
    echo "Tests: $total_tests, Verified: $verified_alerts, Success Rate: $success_rate%"
    echo "Baseline: $baseline_alerts, Final: $final_alerts, New: $new_alerts"
    echo "Agent alerts: $agent_alerts"
} > /workspaces/AGENT2/logs/fixed_e2e_validation.log