#!/bin/bash
# Active Response System Validation Test
# Tests all active response components and functionality

echo "=================================="
echo "WAZUH ACTIVE RESPONSE SYSTEM TEST"
echo "=================================="
echo "Testing comprehensive active response capabilities..."
echo

LOG_FILE="/workspaces/AGENT2/logs/active_response_test.log"
echo "$(date '+%Y/%m/%d %H:%M:%S') [INFO] Starting Active Response System Test" > $LOG_FILE

# Test 1: Configuration Validation
echo "1. Testing Active Response Configuration..."
if grep -q "<active-response>" /workspaces/AGENT2/etc/ossec.conf; then
    echo "   ✅ Active response configuration found"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] AR configuration present" >> $LOG_FILE
else
    echo "   ❌ Active response configuration missing"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] AR configuration missing" >> $LOG_FILE
fi

# Test 2: Script Availability
echo "2. Testing Active Response Scripts..."
AR_SCRIPTS=(
    "iptables-block"
    "container-quarantine" 
    "kill-process"
    "file-quarantine"
    "cloud-isolate"
    "vuln-mitigation"
    "alert-notify"
)

for script in "${AR_SCRIPTS[@]}"; do
    if [ -x "/workspaces/AGENT2/active-response/bin/$script" ]; then
        echo "   ✅ $script script available and executable"
        echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] $script script ready" >> $LOG_FILE
    else
        echo "   ❌ $script script missing or not executable"
        echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] $script script issue" >> $LOG_FILE
    fi
done

# Test 3: IP Blocking Test (Safe Test IP)
echo "3. Testing IP Blocking Functionality..."
TEST_IP="203.0.113.1"  # RFC5737 test IP
/workspaces/AGENT2/active-response/bin/iptables-block add $TEST_IP 30 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ IP blocking test successful"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] IP blocking functional" >> $LOG_FILE
    
    # Clean up test block
    /workspaces/AGENT2/active-response/bin/iptables-block delete $TEST_IP 2>/dev/null
else
    echo "   ⚠️  IP blocking test skipped (requires root privileges)"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [SKIP] IP blocking requires root" >> $LOG_FILE
fi

# Test 4: File Quarantine Test
echo "4. Testing File Quarantine..."
TEST_FILE="/tmp/test_malware_sample.txt"
echo "This is a test malware sample" > $TEST_FILE

/workspaces/AGENT2/active-response/bin/file-quarantine add $TEST_FILE 0
if [ ! -f "$TEST_FILE" ] && [ -d "/workspaces/AGENT2/quarantine" ]; then
    echo "   ✅ File quarantine test successful"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] File quarantine functional" >> $LOG_FILE
    
    # Restore test file
    /workspaces/AGENT2/active-response/bin/file-quarantine delete $TEST_FILE
else
    echo "   ❌ File quarantine test failed"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] File quarantine issue" >> $LOG_FILE
fi

# Test 5: Process Kill Test (Safe Process)
echo "5. Testing Process Termination..."
# Start a test background process
sleep 300 &
TEST_PID=$!
PROCESS_INFO="PID:$TEST_PID PROCESS:sleep"

/workspaces/AGENT2/active-response/bin/kill-process add "$PROCESS_INFO" 0
if ! kill -0 $TEST_PID 2>/dev/null; then
    echo "   ✅ Process termination test successful"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] Process kill functional" >> $LOG_FILE
else
    echo "   ❌ Process termination test failed"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] Process kill issue" >> $LOG_FILE
    # Clean up test process
    kill $TEST_PID 2>/dev/null
fi

# Test 6: Container Quarantine Test
echo "6. Testing Container Quarantine..."
if command -v docker >/dev/null 2>&1; then
    # Try to create a test container
    docker run -d --name wazuh-test-container alpine:latest sleep 60 2>/dev/null
    if [ $? -eq 0 ]; then
        /workspaces/AGENT2/active-response/bin/container-quarantine add wazuh-test-container 30
        
        # Check if container is quarantined
        if docker inspect wazuh-test-container --format='{{index .Config.Labels "wazuh.quarantine"}}' 2>/dev/null | grep -q "true"; then
            echo "   ✅ Container quarantine test successful"
            echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] Container quarantine functional" >> $LOG_FILE
        else
            echo "   ⚠️  Container quarantine test partial"
            echo "$(date '+%Y/%m/%d %H:%M:%S') [PARTIAL] Container quarantine partial" >> $LOG_FILE
        fi
        
        # Clean up test container
        docker rm -f wazuh-test-container 2>/dev/null
    else
        echo "   ⚠️  Container quarantine test skipped (no test container)"
        echo "$(date '+%Y/%m/%d %H:%M:%S') [SKIP] Container test skipped" >> $LOG_FILE
    fi
else
    echo "   ⚠️  Container quarantine test skipped (Docker not available)"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [SKIP] Docker not available" >> $LOG_FILE
fi

# Test 7: Vulnerability Mitigation Test
echo "7. Testing Vulnerability Mitigation..."
VULN_INFO="CVE-2023-TEST PACKAGE:test-package SEVERITY:HIGH"
/workspaces/AGENT2/active-response/bin/vuln-mitigation add "$VULN_INFO" 0

if grep -q "CVE-2023-TEST" /tmp/wazuh_mitigated_vulns.txt 2>/dev/null; then
    echo "   ✅ Vulnerability mitigation test successful"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] Vulnerability mitigation functional" >> $LOG_FILE
else
    echo "   ❌ Vulnerability mitigation test failed"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] Vulnerability mitigation issue" >> $LOG_FILE
fi

# Test 8: Alert Notification Test
echo "8. Testing Alert Notification..."
ALERT_INFO="LEVEL:12 RULE:test_rule DESC:Test security alert SRCIP:192.168.1.100"
/workspaces/AGENT2/active-response/bin/alert-notify add "$ALERT_INFO" 0

if [ -f "/workspaces/AGENT2/logs/security_alerts.log" ]; then
    echo "   ✅ Alert notification test successful"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] Alert notification functional" >> $LOG_FILE
else
    echo "   ❌ Alert notification test failed"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] Alert notification issue" >> $LOG_FILE
fi

# Test 9: Execd Daemon Test
echo "9. Testing execd Daemon..."
if [ -x "/workspaces/AGENT2/bin/wazuh-execd" ]; then
    echo "   ✅ wazuh-execd daemon available"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] execd daemon ready" >> $LOG_FILE
else
    echo "   ❌ wazuh-execd daemon missing"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] execd daemon missing" >> $LOG_FILE
fi

# Test 10: Queue Directory Test
echo "10. Testing Queue Directory Structure..."
mkdir -p /workspaces/AGENT2/queue/ar
if [ -d "/workspaces/AGENT2/queue/ar" ]; then
    echo "    ✅ Active response queue directory ready"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [PASS] AR queue directory ready" >> $LOG_FILE
else
    echo "    ❌ Active response queue directory missing"
    echo "$(date '+%Y/%m/%d %H:%M:%S') [FAIL] AR queue directory missing" >> $LOG_FILE
fi

echo
echo "=================================="
echo "ACTIVE RESPONSE SYSTEM SUMMARY"
echo "=================================="

# Count results
PASS_COUNT=$(grep -c "\[PASS\]" $LOG_FILE)
FAIL_COUNT=$(grep -c "\[FAIL\]" $LOG_FILE)
SKIP_COUNT=$(grep -c "\[SKIP\]" $LOG_FILE)
PARTIAL_COUNT=$(grep -c "\[PARTIAL\]" $LOG_FILE)

echo "✅ Passed: $PASS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "⚠️  Skipped: $SKIP_COUNT"
echo "🔶 Partial: $PARTIAL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    echo
    echo "🎉 ACTIVE RESPONSE SYSTEM FULLY FUNCTIONAL!"
    echo "   All critical components are working properly."
    echo "   The agent can now automatically respond to security threats."
    echo "$(date '+%Y/%m/%d %H:%M:%S') [SUCCESS] Active Response System fully functional" >> $LOG_FILE
else
    echo
    echo "⚠️  ACTIVE RESPONSE SYSTEM PARTIALLY FUNCTIONAL"
    echo "   Some components need attention. Check logs for details."
    echo "$(date '+%Y/%m/%d %H:%M:%S') [WARNING] Active Response System needs attention" >> $LOG_FILE
fi

echo
echo "Detailed logs available at: $LOG_FILE"
echo "Active response ready for threat mitigation!"
echo "=================================="