# Comprehensive Testing and Validation Strategy

## Overview
This document outlines a complete testing strategy to validate that the extracted agent achieves full functional equivalence with the original Wazuh agent. Testing is organized into phases that align with the implementation roadmap.

## Testing Philosophy

### Test-Driven Validation
- **Before Implementation**: Define expected behaviors and test criteria
- **During Implementation**: Continuous validation of each component
- **After Implementation**: Comprehensive integration and stress testing
- **Ongoing**: Automated regression testing

### Testing Pyramid
1. **Unit Tests**: Individual component functionality
2. **Integration Tests**: Component interaction validation
3. **System Tests**: End-to-end security monitoring scenarios
4. **Performance Tests**: Load and stress testing
5. **Security Tests**: Threat simulation and detection validation

## Phase 1: Core Infrastructure Testing

### 1.1 Binary Compilation Validation

**Test Script**: `test_binary_compilation.sh`
```bash
#!/bin/bash
# Test binary compilation and basic functionality

set -e

echo "=== Binary Compilation Testing ==="

# Test 1: Verify binaries exist and are executable
binaries=("wazuh-agentd" "wazuh-logcollector" "wazuh-syscheckd" "wazuh-modulesd" "wazuh-execd")

for binary in "${binaries[@]}"; do
    binary_path="/workspaces/AGENT2/bin/$binary"
    
    echo "Testing $binary..."
    
    # Check existence
    if [[ ! -f "$binary_path" ]]; then
        echo "❌ FAIL: $binary not found"
        exit 1
    fi
    
    # Check executable
    if [[ ! -x "$binary_path" ]]; then
        echo "❌ FAIL: $binary not executable"
        exit 1
    fi
    
    # Check it's a compiled binary (not script)
    if ! file "$binary_path" | grep -q "ELF"; then
        echo "❌ FAIL: $binary is not a compiled binary"
        exit 1
    fi
    
    # Test help/version flags
    if ! "$binary_path" -h >/dev/null 2>&1 && ! "$binary_path" -V >/dev/null 2>&1; then
        echo "⚠️  WARNING: $binary doesn't respond to -h or -V flags"
    fi
    
    echo "✅ PASS: $binary"
done

echo "=== Binary compilation tests completed successfully ==="
```

**Test Script**: `test_configuration_parsing.sh`
```bash
#!/bin/bash
# Test configuration file parsing

echo "=== Configuration Parsing Testing ==="

# Test 1: Valid configuration
echo "Testing valid configuration parsing..."
if /workspaces/AGENT2/bin/wazuh-agentd -t >/dev/null 2>&1; then
    echo "✅ PASS: Valid configuration parsed successfully"
else
    echo "❌ FAIL: Configuration parsing failed"
    exit 1
fi

# Test 2: Invalid configuration detection
echo "Testing invalid configuration detection..."
cp /workspaces/AGENT2/etc/ossec.conf /workspaces/AGENT2/etc/ossec.conf.backup
echo "<invalid_xml>" >> /workspaces/AGENT2/etc/ossec.conf

if /workspaces/AGENT2/bin/wazuh-agentd -t >/dev/null 2>&1; then
    echo "❌ FAIL: Invalid configuration not detected"
    mv /workspaces/AGENT2/etc/ossec.conf.backup /workspaces/AGENT2/etc/ossec.conf
    exit 1
else
    echo "✅ PASS: Invalid configuration properly detected"
fi

# Restore valid configuration
mv /workspaces/AGENT2/etc/ossec.conf.backup /workspaces/AGENT2/etc/ossec.conf

echo "=== Configuration parsing tests completed ==="
```

### 1.2 SCA Ruleset Validation

**Test Script**: `test_sca_ruleset.sh`
```bash
#!/bin/bash
# Test SCA ruleset completeness and validity

echo "=== SCA Ruleset Testing ==="

# Test 1: Count SCA policies
sca_count=$(find /workspaces/AGENT2/ruleset/sca -name "*.yml" | wc -l)
expected_count=74

echo "Found $sca_count SCA policies (expected: $expected_count)"

if [[ $sca_count -eq $expected_count ]]; then
    echo "✅ PASS: SCA policy count correct"
else
    echo "❌ FAIL: SCA policy count incorrect ($sca_count/$expected_count)"
    exit 1
fi

# Test 2: YAML syntax validation
echo "Validating YAML syntax..."
yaml_errors=0

for yaml_file in $(find /workspaces/AGENT2/ruleset/sca -name "*.yml"); do
    if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" >/dev/null 2>&1; then
        echo "❌ YAML syntax error in: $yaml_file"
        yaml_errors=$((yaml_errors + 1))
    fi
done

if [[ $yaml_errors -eq 0 ]]; then
    echo "✅ PASS: All YAML files have valid syntax"
else
    echo "❌ FAIL: $yaml_errors YAML files have syntax errors"
    exit 1
fi

# Test 3: SCA module can load policies
echo "Testing SCA module policy loading..."
if /workspaces/AGENT2/bin/wazuh-modulesd -t >/dev/null 2>&1; then
    echo "✅ PASS: SCA module loads policies successfully"
else
    echo "❌ FAIL: SCA module cannot load policies"
    exit 1
fi

echo "=== SCA ruleset tests completed ==="
```

## Phase 2: Core Security Feature Testing

### 2.1 File Integrity Monitoring Tests

**Test Script**: `test_fim_functionality.sh`
```bash
#!/bin/bash
# Comprehensive FIM testing

echo "=== File Integrity Monitoring Testing ==="

# Setup test environment
test_dir="/tmp/wazuh_fim_test"
mkdir -p "$test_dir"
echo "Initial content" > "$test_dir/test_file.txt"

# Add test directory to FIM configuration
backup_config() {
    cp /workspaces/AGENT2/etc/ossec.conf /workspaces/AGENT2/etc/ossec.conf.test_backup
}

restore_config() {
    mv /workspaces/AGENT2/etc/ossec.conf.test_backup /workspaces/AGENT2/etc/ossec.conf
}

backup_config

# Add test directory to configuration
sed -i "/<\/syscheck>/i\\    <directories realtime=\"yes\" report_changes=\"yes\">$test_dir</directories>" /workspaces/AGENT2/etc/ossec.conf

# Start FIM daemon
echo "Starting FIM daemon..."
/workspaces/AGENT2/bin/wazuh-syscheckd -f &
fim_pid=$!
sleep 10

# Test 1: File creation detection
echo "Testing file creation detection..."
echo "New file content" > "$test_dir/new_file.txt"
sleep 5

if grep -q "new_file.txt" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: File creation detected"
else
    echo "❌ FAIL: File creation not detected"
fi

# Test 2: File modification detection
echo "Testing file modification detection..."
echo "Modified content" >> "$test_dir/test_file.txt"
sleep 5

if grep -q "test_file.txt" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: File modification detected"
else
    echo "❌ FAIL: File modification not detected"
fi

# Test 3: File deletion detection
echo "Testing file deletion detection..."
rm "$test_dir/test_file.txt"
sleep 5

if grep -q "deleted.*test_file.txt" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: File deletion detected"
else
    echo "❌ FAIL: File deletion not detected"
fi

# Cleanup
kill $fim_pid >/dev/null 2>&1
rm -rf "$test_dir"
restore_config

echo "=== FIM testing completed ==="
```

### 2.2 Log Analysis Engine Tests

**Test Script**: `test_log_analysis.sh`
```bash
#!/bin/bash
# Test log collection and analysis

echo "=== Log Analysis Testing ==="

# Test 1: Syslog format parsing
echo "Testing syslog format parsing..."
test_log="/tmp/test_syslog.log"
echo "$(date '+%b %d %H:%M:%S') testhost test[$$]: Test syslog message for Wazuh" > "$test_log"

# Add test log to configuration temporarily
backup_config() {
    cp /workspaces/AGENT2/etc/ossec.conf /workspaces/AGENT2/etc/ossec.conf.log_backup
}

restore_config() {
    mv /workspaces/AGENT2/etc/ossec.conf.log_backup /workspaces/AGENT2/etc/ossec.conf
}

backup_config

# Add test log file
sed -i "/<\/ossec_config>/i\\  <localfile>\\n    <log_format>syslog</log_format>\\n    <location>$test_log</location>\\n  </localfile>" /workspaces/AGENT2/etc/ossec.conf

# Start logcollector
/workspaces/AGENT2/bin/wazuh-logcollector -f &
logcollector_pid=$!
sleep 5

# Add more test entries
echo "$(date '+%b %d %H:%M:%S') testhost sshd[1234]: Failed password for invalid user test from 192.168.1.100" >> "$test_log"
echo "$(date '+%b %d %H:%M:%S') testhost kernel: Test kernel message" >> "$test_log"

sleep 10

# Check if logs were processed
if grep -q "Test syslog message" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Syslog parsing working"
else
    echo "❌ FAIL: Syslog parsing not working"
fi

# Test 2: JSON format parsing
echo "Testing JSON format parsing..."
json_log="/tmp/test_json.log"
echo '{"timestamp":"'$(date -Iseconds)'","level":"ERROR","message":"Test JSON log entry","source":"test_app"}' > "$json_log"

# Test 3: Command output parsing
echo "Testing command output parsing..."
# This should already be configured in ossec.conf

# Cleanup
kill $logcollector_pid >/dev/null 2>&1
rm -f "$test_log" "$json_log"
restore_config

echo "=== Log analysis testing completed ==="
```

### 2.3 Rootkit Detection Tests

**Test Script**: `test_rootkit_detection.sh`
```bash
#!/bin/bash
# Test rootkit detection capabilities

echo "=== Rootkit Detection Testing ==="

# Test 1: Basic rootcheck functionality
echo "Testing basic rootcheck functionality..."
if /workspaces/AGENT2/bin/wazuh-modulesd -f rootcheck >/dev/null 2>&1; then
    echo "✅ PASS: Rootcheck module starts successfully"
else
    echo "❌ FAIL: Rootcheck module failed to start"
    exit 1
fi

# Test 2: System audit checks
echo "Testing system audit checks..."
# Create a test scenario for policy violation
test_file="/tmp/world_writable_test"
touch "$test_file"
chmod 777 "$test_file"

# Run rootcheck scan
timeout 60 /workspaces/AGENT2/bin/wazuh-modulesd -f rootcheck
sleep 5

# Check if policy violation was detected
if grep -q "world_writable.*$test_file" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: System audit policy violation detected"
else
    echo "⚠️  WARNING: System audit may not be fully functional"
fi

# Cleanup
rm -f "$test_file"

# Test 3: Rootkit signature detection
echo "Testing rootkit signature detection..."
# Create a suspicious file name
suspicious_file="/tmp/rk_test_suspicious"
touch "$suspicious_file"

# Check if rootcheck database exists
if [[ -f "/workspaces/AGENT2/etc/shared/rootkit_files.txt" ]]; then
    echo "✅ PASS: Rootkit database present"
else
    echo "❌ FAIL: Rootkit database missing"
fi

rm -f "$suspicious_file"

echo "=== Rootkit detection testing completed ==="
```

## Phase 3: Advanced Feature Testing

### 3.1 Vulnerability Scanner Tests

**Test Script**: `test_vulnerability_scanner.sh`
```bash
#!/bin/bash
# Test vulnerability scanning functionality

echo "=== Vulnerability Scanner Testing ==="

# Test 1: Module configuration
echo "Testing vulnerability scanner configuration..."
if grep -q "vulnerability-scanner" /workspaces/AGENT2/etc/ossec.conf; then
    echo "✅ PASS: Vulnerability scanner configured"
else
    echo "❌ FAIL: Vulnerability scanner not configured"
    exit 1
fi

# Test 2: Package inventory collection
echo "Testing package inventory collection..."
/workspaces/AGENT2/bin/wazuh-modulesd -f vulnerability_scanner &
vuln_pid=$!
sleep 30

# Check if package data was collected
if grep -q "package.*inventory" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Package inventory collected"
else
    echo "⚠️  WARNING: Package inventory collection may not be working"
fi

# Test 3: CVE database presence
echo "Testing CVE database..."
if [[ -d "/workspaces/AGENT2/var/wodles/vulnerability-scanner" ]]; then
    echo "✅ PASS: Vulnerability scanner database directory exists"
else
    echo "❌ FAIL: Vulnerability scanner database directory missing"
fi

kill $vuln_pid >/dev/null 2>&1

echo "=== Vulnerability scanner testing completed ==="
```

### 3.2 System Inventory Tests

**Test Script**: `test_system_inventory.sh`
```bash
#!/bin/bash
# Test system inventory collection

echo "=== System Inventory Testing ==="

# Test 1: Syscollector module
echo "Testing syscollector module..."
/workspaces/AGENT2/bin/wazuh-modulesd -f syscollector &
syscollector_pid=$!
sleep 20

# Test 2: Hardware inventory
echo "Testing hardware inventory collection..."
if grep -q "hardware.*inventory" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Hardware inventory collected"
else
    echo "⚠️  WARNING: Hardware inventory may not be working"
fi

# Test 3: Network inventory
echo "Testing network inventory collection..."
if grep -q "network.*inventory" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Network inventory collected"
else
    echo "⚠️  WARNING: Network inventory may not be working"
fi

# Test 4: Process inventory
echo "Testing process inventory collection..."
if grep -q "process.*inventory" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Process inventory collected"
else
    echo "⚠️  WARNING: Process inventory may not be working"
fi

kill $syscollector_pid >/dev/null 2>&1

echo "=== System inventory testing completed ==="
```

## Phase 4: Cloud Integration Testing

### 4.1 Wodles Testing

**Test Script**: `test_wodles.sh`
```bash
#!/bin/bash
# Test cloud integration wodles

echo "=== Wodles Testing ==="

# Test 1: Wodles directory structure
echo "Testing wodles directory structure..."
wodles_dir="/workspaces/AGENT2/wodles"

if [[ -d "$wodles_dir" ]]; then
    echo "✅ PASS: Wodles directory exists"
else
    echo "❌ FAIL: Wodles directory missing"
    exit 1
fi

# Test individual wodles
for wodle in aws azure gcloud docker-listener; do
    if [[ -d "$wodles_dir/$wodle" ]]; then
        echo "✅ PASS: $wodle wodle present"
    else
        echo "❌ FAIL: $wodle wodle missing"
    fi
done

# Test 2: Python dependencies
echo "Testing Python dependencies..."
python_deps=("boto3" "azure-storage-blob" "google-cloud-logging" "requests")

for dep in "${python_deps[@]}"; do
    if python3 -c "import $dep" >/dev/null 2>&1; then
        echo "✅ PASS: $dep available"
    else
        echo "⚠️  WARNING: $dep not available (needed for cloud integrations)"
    fi
done

# Test 3: Wodle configuration parsing
echo "Testing wodle configuration parsing..."
if grep -q "wodle.*aws\|wodle.*azure\|wodle.*gcloud" /workspaces/AGENT2/etc/ossec.conf; then
    echo "✅ PASS: Cloud wodles configured"
else
    echo "⚠️  INFO: No cloud wodles currently configured (this is normal for basic setup)"
fi

echo "=== Wodles testing completed ==="
```

### 4.2 Active Response Testing

**Test Script**: `test_active_response.sh`
```bash
#!/bin/bash
# Test active response functionality

echo "=== Active Response Testing ==="

# Test 1: Active response scripts presence
echo "Testing active response scripts..."
ar_dir="/workspaces/AGENT2/active-response/bin"

scripts=("disable-account" "firewall-drop" "host-deny" "restart-wazuh" "route-null")

for script in "${scripts[@]}"; do
    script_path="$ar_dir/$script"
    if [[ -x "$script_path" ]]; then
        echo "✅ PASS: $script script present and executable"
    else
        echo "❌ FAIL: $script script missing or not executable"
    fi
done

# Test 2: Active response configuration
echo "Testing active response configuration..."
if grep -q "active-response" /workspaces/AGENT2/etc/ossec.conf; then
    echo "✅ PASS: Active response configured"
else
    echo "❌ FAIL: Active response not configured"
fi

# Test 3: Execd daemon functionality
echo "Testing execd daemon..."
if /workspaces/AGENT2/bin/wazuh-execd -t >/dev/null 2>&1; then
    echo "✅ PASS: Execd daemon functional"
else
    echo "❌ FAIL: Execd daemon not functional"
fi

echo "=== Active response testing completed ==="
```

## Phase 5: Integration and Performance Testing

### 5.1 End-to-End Integration Tests

**Test Script**: `test_full_integration.sh`
```bash
#!/bin/bash
# Comprehensive end-to-end testing

echo "=== Full Integration Testing ==="

# Test 1: All daemons startup
echo "Testing complete system startup..."
/workspaces/AGENT2/bin/wazuh-control start
sleep 10

# Check all processes
processes=("wazuh-agentd" "wazuh-logcollector" "wazuh-syscheckd" "wazuh-modulesd" "wazuh-execd")
all_running=true

for process in "${processes[@]}"; do
    if pgrep -f "$process" >/dev/null; then
        echo "✅ $process: Running"
    else
        echo "❌ $process: Not running"
        all_running=false
    fi
done

if $all_running; then
    echo "✅ PASS: All daemons running"
else
    echo "❌ FAIL: Some daemons not running"
fi

# Test 2: Manager communication
echo "Testing manager communication..."
# Create test event
echo "$(date) test-host wazuh-integration-test: Integration test event" >> /var/log/syslog
sleep 5

if grep -q "wazuh-integration-test" /workspaces/AGENT2/logs/ossec.log; then
    echo "✅ PASS: Event processing working"
else
    echo "⚠️  WARNING: Event processing may not be working"
fi

# Test 3: Multi-feature scenario
echo "Testing multi-feature scenario..."
# Create FIM event
echo "test content" > /tmp/integration_test_file
# Wait for FIM to detect
sleep 5
# Modify file
echo "modified content" >> /tmp/integration_test_file
sleep 5
# Remove file
rm /tmp/integration_test_file
sleep 5

# Check if all events were captured
fim_events=$(grep -c "integration_test_file" /workspaces/AGENT2/logs/ossec.log)
if [[ $fim_events -ge 2 ]]; then
    echo "✅ PASS: Multi-feature integration working ($fim_events FIM events)"
else
    echo "⚠️  WARNING: Multi-feature integration may have issues ($fim_events FIM events)"
fi

# Cleanup
/workspaces/AGENT2/bin/wazuh-control stop

echo "=== Full integration testing completed ==="
```

### 5.2 Performance Testing

**Test Script**: `test_performance.sh`
```bash
#!/bin/bash
# Performance and resource usage testing

echo "=== Performance Testing ==="

# Start all daemons
/workspaces/AGENT2/bin/wazuh-control start
sleep 10

# Test 1: Memory usage
echo "Testing memory usage..."
total_memory=0
for process in wazuh-agentd wazuh-logcollector wazuh-syscheckd wazuh-modulesd wazuh-execd; do
    if pgrep -f "$process" >/dev/null; then
        memory=$(ps -o rss= -p $(pgrep -f "$process") | awk '{sum+=$1} END {print sum}')
        memory_mb=$((memory / 1024))
        echo "  $process: ${memory_mb}MB"
        total_memory=$((total_memory + memory_mb))
    fi
done

echo "Total memory usage: ${total_memory}MB"
if [[ $total_memory -lt 256 ]]; then
    echo "✅ PASS: Memory usage within acceptable limits"
else
    echo "⚠️  WARNING: High memory usage ($total_memory MB)"
fi

# Test 2: CPU usage monitoring
echo "Testing CPU usage..."
echo "Monitoring CPU usage for 30 seconds..."
cpu_samples=()
for i in {1..6}; do
    cpu_usage=$(top -bn1 | grep "wazuh" | awk '{sum+=$9} END {print sum+0}')
    cpu_samples+=($cpu_usage)
    sleep 5
done

avg_cpu=$(echo "${cpu_samples[@]}" | awk '{sum=0; for(i=1;i<=NF;i++) sum+=$i; print sum/NF}')
echo "Average CPU usage: ${avg_cpu}%"

if (( $(echo "$avg_cpu < 10" | bc -l) )); then
    echo "✅ PASS: CPU usage within acceptable limits"
else
    echo "⚠️  WARNING: High CPU usage (${avg_cpu}%)"
fi

# Test 3: Log processing performance
echo "Testing log processing performance..."
start_time=$(date +%s)
# Generate 1000 test log entries
for i in {1..1000}; do
    echo "$(date '+%b %d %H:%M:%S') testhost test[$i]: Performance test log entry $i" >> /tmp/perf_test.log
done

# Wait for processing
sleep 10
end_time=$(date +%s)
processing_time=$((end_time - start_time))

processed_events=$(grep -c "Performance test log entry" /workspaces/AGENT2/logs/ossec.log || echo 0)
eps=$((processed_events / processing_time))

echo "Processed $processed_events events in $processing_time seconds (${eps} EPS)"

if [[ $eps -gt 50 ]]; then
    echo "✅ PASS: Log processing performance acceptable"
else
    echo "⚠️  WARNING: Low log processing performance (${eps} EPS)"
fi

# Cleanup
rm -f /tmp/perf_test.log
/workspaces/AGENT2/bin/wazuh-control stop

echo "=== Performance testing completed ==="
```

## Security Testing and Threat Simulation

### 6.1 Threat Detection Tests

**Test Script**: `test_threat_detection.sh`
```bash
#!/bin/bash
# Simulate various security threats and test detection

echo "=== Threat Detection Testing ==="

# Start agent
/workspaces/AGENT2/bin/wazuh-control start
sleep 15

# Test 1: Brute force attack simulation
echo "Testing brute force detection..."
for i in {1..10}; do
    echo "$(date '+%b %d %H:%M:%S') testhost sshd[$$]: Failed password for invalid user test$i from 192.168.1.100 port 22 ssh2" >> /var/log/auth.log
done
sleep 10

brute_force_events=$(grep -c "Failed password.*test.*192.168.1.100" /workspaces/AGENT2/logs/ossec.log || echo 0)
if [[ $brute_force_events -gt 5 ]]; then
    echo "✅ PASS: Brute force attack detected ($brute_force_events events)"
else
    echo "⚠️  WARNING: Brute force detection may not be working ($brute_force_events events)"
fi

# Test 2: File modification attack
echo "Testing unauthorized file modification detection..."
echo "malicious content" > /etc/test_config_file
sleep 5

fim_alerts=$(grep -c "test_config_file" /workspaces/AGENT2/logs/ossec.log || echo 0)
if [[ $fim_alerts -gt 0 ]]; then
    echo "✅ PASS: File modification detected ($fim_alerts alerts)"
else
    echo "⚠️  WARNING: File modification detection may not be working"
fi

# Test 3: Privilege escalation simulation
echo "Testing privilege escalation detection..."
echo "$(date '+%b %d %H:%M:%S') testhost sudo: testuser : TTY=pts/0 ; PWD=/home/testuser ; USER=root ; COMMAND=/bin/bash" >> /var/log/auth.log
sleep 5

privesc_events=$(grep -c "USER=root.*COMMAND=/bin/bash" /workspaces/AGENT2/logs/ossec.log || echo 0)
if [[ $privesc_events -gt 0 ]]; then
    echo "✅ PASS: Privilege escalation detected ($privesc_events events)"
else
    echo "⚠️  WARNING: Privilege escalation detection may not be working"
fi

# Test 4: Network scanning simulation
echo "Testing network scanning detection..."
for port in {80,22,443,21,25}; do
    echo "$(date '+%b %d %H:%M:%S') testhost kernel: [UFW BLOCK] IN=eth0 OUT= SRC=192.168.1.200 DST=192.168.1.10 PROTO=TCP DPT=$port" >> /var/log/syslog
done
sleep 10

scan_events=$(grep -c "UFW BLOCK.*192.168.1.200" /workspaces/AGENT2/logs/ossec.log || echo 0)
if [[ $scan_events -gt 3 ]]; then
    echo "✅ PASS: Network scanning detected ($scan_events events)"
else
    echo "⚠️  WARNING: Network scanning detection may not be working ($scan_events events)"
fi

# Cleanup
rm -f /etc/test_config_file
/workspaces/AGENT2/bin/wazuh-control stop

echo "=== Threat detection testing completed ==="
```

## Automated Test Suite

### Master Test Runner

**Test Script**: `run_all_tests.sh`
```bash
#!/bin/bash
# Master test runner for complete validation

set -e

echo "=========================================="
echo "     Wazuh Agent Complete Test Suite"
echo "=========================================="

# Test results tracking
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo ""
    echo "Running: $test_name"
    echo "----------------------------------------"
    
    total_tests=$((total_tests + 1))
    
    if bash "$test_script"; then
        echo "✅ $test_name: PASSED"
        passed_tests=$((passed_tests + 1))
    else
        echo "❌ $test_name: FAILED"
        failed_tests=$((failed_tests + 1))
    fi
}

# Create test results directory
mkdir -p /workspaces/AGENT2/test_results
cd /workspaces/AGENT2

# Phase 1 Tests
echo "=== PHASE 1: INFRASTRUCTURE TESTS ==="
run_test "Binary Compilation" "test_binary_compilation.sh"
run_test "Configuration Parsing" "test_configuration_parsing.sh"
run_test "SCA Ruleset" "test_sca_ruleset.sh"

# Phase 2 Tests
echo ""
echo "=== PHASE 2: CORE SECURITY FEATURES ==="
run_test "File Integrity Monitoring" "test_fim_functionality.sh"
run_test "Log Analysis" "test_log_analysis.sh"
run_test "Rootkit Detection" "test_rootkit_detection.sh"

# Phase 3 Tests
echo ""
echo "=== PHASE 3: ADVANCED FEATURES ==="
run_test "Vulnerability Scanner" "test_vulnerability_scanner.sh"
run_test "System Inventory" "test_system_inventory.sh"

# Phase 4 Tests
echo ""
echo "=== PHASE 4: CLOUD INTEGRATION ==="
run_test "Wodles" "test_wodles.sh"
run_test "Active Response" "test_active_response.sh"

# Phase 5 Tests
echo ""
echo "=== PHASE 5: INTEGRATION & PERFORMANCE ==="
run_test "Full Integration" "test_full_integration.sh"
run_test "Performance" "test_performance.sh"
run_test "Threat Detection" "test_threat_detection.sh"

# Generate final report
echo ""
echo "=========================================="
echo "           TEST RESULTS SUMMARY"
echo "=========================================="
echo "Total Tests:  $total_tests"
echo "Passed:       $passed_tests"
echo "Failed:       $failed_tests"
echo "Success Rate: $(( (passed_tests * 100) / total_tests ))%"
echo ""

if [[ $failed_tests -eq 0 ]]; then
    echo "🎉 ALL TESTS PASSED - Agent is fully functional!"
    exit 0
else
    echo "⚠️  Some tests failed. Review logs and fix issues before deployment."
    exit 1
fi
```

## Continuous Testing Strategy

### Automated Daily Testing
```bash
#!/bin/bash
# Cron job for daily automated testing
# Add to crontab: 0 2 * * * /workspaces/AGENT2/scripts/daily_tests.sh

cd /workspaces/AGENT2
./run_all_tests.sh > test_results/daily_$(date +%Y%m%d).log 2>&1

# Send results summary
if [[ $? -eq 0 ]]; then
    echo "Daily tests PASSED" | mail -s "Wazuh Agent Tests - PASS" admin@company.com
else
    echo "Daily tests FAILED - Check logs" | mail -s "Wazuh Agent Tests - FAIL" admin@company.com
fi
```

### Performance Monitoring
```bash
#!/bin/bash
# Continuous performance monitoring
while true; do
    memory_usage=$(ps -o rss= -p $(pgrep -f wazuh) | awk '{sum+=$1} END {print sum/1024}')
    cpu_usage=$(top -bn1 | grep wazuh | awk '{sum+=$9} END {print sum}')
    
    echo "$(date): Memory=${memory_usage}MB CPU=${cpu_usage}%" >> /workspaces/AGENT2/logs/performance.log
    
    # Alert if thresholds exceeded
    if (( $(echo "$memory_usage > 512" | bc -l) )); then
        echo "HIGH MEMORY USAGE: ${memory_usage}MB" | logger -t wazuh-monitor
    fi
    
    if (( $(echo "$cpu_usage > 20" | bc -l) )); then
        echo "HIGH CPU USAGE: ${cpu_usage}%" | logger -t wazuh-monitor
    fi
    
    sleep 300  # Check every 5 minutes
done
```

---

**Next Steps**: Implement the testing scripts alongside the feature implementation phases. Each phase should include running the corresponding test suite to validate functionality before proceeding to the next phase.