# Wazuh Monitoring Agent - Automated Testing Framework

## Overview

This comprehensive automated testing framework validates the functionality of the Wazuh-based Monitoring Agent across all 10 core security features. The framework ensures manager-agent communication, alert generation, and production readiness through rigorous automated testing.

## 📁 Framework Architecture

```
test/
├── utils/
│   └── test_lib.sh                    # Core testing library and utilities
├── core/
│   └── test_startup.sh                # Agent startup and connectivity tests
├── features/
│   ├── fim/test_fim.sh               # File Integrity Monitoring tests
│   ├── sca/test_sca.sh               # Security Configuration Assessment
│   ├── log-analysis/test_log_analysis.sh   # Log Analysis Engine tests
│   ├── rootkit/test_rootkit.sh       # Rootkit Detection tests
│   ├── vuln-scan/test_vuln_scan.sh   # Vulnerability Scanner tests
│   ├── cloud/test_cloud.sh           # Cloud Security Monitoring
│   ├── active-response/test_active_response.sh  # Active Response tests
│   ├── performance/test_performance.sh          # Performance Monitoring
│   └── integration/test_integration.sh         # Integration tests
├── alerts/
│   └── test_alerts.sh                # Alert validation framework
└── run_all_tests.sh                  # Master orchestration script
```

## 🚀 Quick Start

### Running All Tests
```bash
# Execute complete test suite
cd /workspaces/AGENT2
./test/run_all_tests.sh
```

### Running Individual Test Modules
```bash
# Core functionality tests
./test/core/test_startup.sh

# Specific feature tests
./test/features/fim/test_fim.sh
./test/features/sca/test_sca.sh
./test/features/log-analysis/test_log_analysis.sh

# Alert validation
./test/alerts/test_alerts.sh
```

## 🧪 Test Modules Description

### 1. Core Tests (`core/test_startup.sh`)
**Purpose**: Validates basic agent functionality and manager connectivity
- **Installation Verification**: Confirms agent binaries and configuration
- **Service Startup**: Tests daemon initialization and process management
- **Manager Connectivity**: Validates connection to Wazuh manager
- **Agent Enrollment**: Checks agent registration and key exchange

**Key Functions**:
- `test_agent_installation()` - Verify installation integrity
- `test_service_startup()` - Validate service management
- `test_manager_connectivity()` - Test manager communication

### 2. File Integrity Monitoring (`features/fim/test_fim.sh`)
**Purpose**: Validates real-time file system monitoring and tampering detection
- **File Creation Detection**: Monitors new file creation
- **File Modification Alerts**: Detects content changes
- **Security File Tampering**: Simulates attacks on critical system files
- **Directory Monitoring**: Validates recursive directory watching

**Test Scenarios**:
- Create files in monitored directories
- Modify system configuration files
- Simulate malicious file tampering
- Test permission changes and ownership modifications

### 3. Security Configuration Assessment (`features/sca/test_sca.sh`)
**Purpose**: Validates compliance scanning and policy enforcement
- **Policy Validation**: Tests custom SCA policies
- **CIS Benchmark Compliance**: Validates industry standard compliance
- **Configuration Hardening**: Tests security configuration checks
- **Compliance Reporting**: Validates report generation

**Compliance Checks**:
- SSH configuration security
- File permission validation
- Service configuration assessment
- Security policy enforcement

### 4. Log Analysis Engine (`features/log-analysis/test_log_analysis.sh`)
**Purpose**: Validates log parsing, analysis, and threat detection
- **SSH Attack Detection**: Failed login and brute force attempts
- **Privilege Escalation**: Unauthorized sudo/su attempts
- **Web Attack Detection**: SQL injection, XSS, and exploit attempts
- **System Intrusion**: Malicious process and network activity

**Attack Simulations**:
- SSH brute force attacks
- Web application exploits
- Privilege escalation attempts
- Network intrusion patterns

### 5. Rootkit Detection (`features/rootkit/test_rootkit.sh`)
**Purpose**: Validates rootkit and malware detection capabilities
- **System Integrity Checks**: Binary modification detection
- **Hidden Process Detection**: Identifies concealed processes
- **Network Anomaly Detection**: Suspicious network connections
- **File System Anomalies**: Hidden files and directories

### 6. Vulnerability Scanner (`features/vuln-scan/test_vuln_scan.sh`)
**Purpose**: Validates vulnerability assessment and CVE detection
- **CVE Database Updates**: Ensures current vulnerability data
- **Package Vulnerability Scanning**: Identifies vulnerable software
- **Security Patch Assessment**: Validates patch management
- **OVAL Integration**: Tests vulnerability definition processing

### 7. Cloud Security Monitoring (`features/cloud/test_cloud.sh`)
**Purpose**: Validates cloud infrastructure monitoring
- **AWS CloudTrail Integration**: Monitors AWS API activities
- **Azure Activity Monitoring**: Tracks Azure resource changes
- **GCP Audit Log Analysis**: Processes Google Cloud audit events
- **Container Security**: Docker and Kubernetes monitoring

### 8. Active Response (`features/active-response/test_active_response.sh`)
**Purpose**: Validates automated response to security threats
- **IP Blocking**: Automatic firewall rule creation
- **Process Termination**: Malicious process killing
- **File Quarantine**: Isolates suspicious files
- **Custom Scripts**: Tests user-defined response actions

### 9. Performance Monitoring (`features/performance/test_performance.sh`)
**Purpose**: Validates system performance and resource monitoring
- **CPU Monitoring**: High CPU usage detection
- **Memory Analysis**: Memory leak and usage monitoring
- **Disk I/O Monitoring**: Storage performance analysis
- **Network Performance**: Bandwidth and latency monitoring

### 10. Integration Tests (`features/integration/test_integration.sh`)
**Purpose**: Validates end-to-end functionality and feature interaction
- **Multi-Feature Scenarios**: Complex attack chain detection
- **Data Flow Validation**: Ensures proper data processing pipeline
- **Manager-Agent Integration**: Full communication testing
- **Alert Correlation**: Tests cross-feature alert correlation

### 11. Alert Validation (`alerts/test_alerts.sh`)
**Purpose**: Validates alert generation, forwarding, and manager integration
- **Security Alert Generation**: Creates various security alerts
- **Alert Forwarding**: Tests manager communication
- **Alert Correlation**: Validates rule-based correlations
- **Manager Connectivity**: Ensures proper communication channels

## 🔧 Test Framework Features

### Comprehensive Assertion Library
The test framework provides robust assertion functions:
- `assert_true()` / `assert_false()` - Boolean assertions
- `assert_equals()` / `assert_not_equals()` - Value comparisons
- `assert_contains()` / `assert_not_contains()` - String/array checks
- `assert_file_exists()` / `assert_file_not_exists()` - File validation
- `assert_process_running()` / `assert_process_not_running()` - Process checks

### Professional Logging System
- **Structured Logging**: Organized by module and severity
- **Color-Coded Output**: Visual test result indication
- **Detailed Error Reporting**: Comprehensive failure analysis
- **Test Result Tracking**: Pass/fail statistics and reporting

### Environment Management
- **Automatic Setup**: Creates necessary directories and files
- **Clean Isolation**: Tests run in isolated environments
- **Dependency Validation**: Checks required components
- **Cleanup Procedures**: Automated cleanup after testing

### Configuration Management
```bash
# Default configuration (can be overridden)
AGENT_HOME="/workspaces/AGENT2"
MANAGER_IP="172.20.0.2"
MANAGER_PORT="1514"
AGENT_LOGS="$AGENT_HOME/logs"
AGENT_BIN="$AGENT_HOME/bin"
```

## 📊 Test Execution and Reporting

### Master Test Execution
The `run_all_tests.sh` script provides:
- **Sequential Test Execution**: Runs all test modules in order
- **Comprehensive Reporting**: Detailed HTML and text reports
- **Error Handling**: Graceful failure management
- **Environment Validation**: Pre-test environment checks

### Test Results
Results are generated in multiple formats:
- **Console Output**: Real-time test progress and results
- **HTML Reports**: Detailed web-based test reports
- **Text Logs**: Machine-readable test logs
- **JSON Output**: Structured test data for automation

### Report Locations
```
logs/
├── test_framework.log           # Master test log
├── reports/
│   ├── test_results_[timestamp].html    # HTML report
│   ├── test_results_[timestamp].txt     # Text report
│   └── test_results_[timestamp].json    # JSON data
└── [module]/
    ├── [module]_test.log               # Module-specific logs
    └── [module]_data/                  # Test data and artifacts
```

## 🛠️ Advanced Usage

### Custom Test Configuration
Create a custom configuration file:
```bash
# config/test_config.sh
export MANAGER_IP="192.168.1.100"
export MANAGER_PORT="1514"
export TEST_TIMEOUT="60"
export VERBOSE_LOGGING="true"
```

### Running Specific Test Categories
```bash
# Run only core tests
./test/run_all_tests.sh --category core

# Run only feature tests
./test/run_all_tests.sh --category features

# Run specific features
./test/run_all_tests.sh --features "fim,sca,log-analysis"
```

### Debugging Failed Tests
```bash
# Enable verbose logging
export VERBOSE_LOGGING=true

# Run single test with debug output
./test/features/fim/test_fim.sh --debug

# Check detailed logs
tail -f logs/test_framework.log
```

### Integration with CI/CD
```bash
# CI/CD integration example
#!/bin/bash
cd /workspaces/AGENT2

# Run tests with JSON output
./test/run_all_tests.sh --output json > test_results.json

# Parse results
if jq -e '.summary.total_passed == .summary.total_tests' test_results.json; then
    echo "All tests passed"
    exit 0
else
    echo "Some tests failed"
    exit 1
fi
```

## 🔍 Troubleshooting

### Common Issues

#### Agent Not Running
```bash
# Check agent status
./bin/wazuh-control status

# Start agent if needed
./bin/wazuh-control start
```

#### Manager Connectivity Issues
```bash
# Test manager connectivity
telnet 172.20.0.2 1514

# Check agent configuration
cat etc/ossec.conf | grep -A 5 "<client>"
```

#### Missing Dependencies
```bash
# Install required packages
sudo apt-get update
sudo apt-get install netcat-openbsd jq curl

# Check Docker availability
docker --version
```

#### Log File Permissions
```bash
# Fix log directory permissions
sudo chown -R $(whoami):$(whoami) logs/
chmod -R 755 logs/
```

### Test Environment Validation
```bash
# Validate complete test environment
./test/utils/validate_environment.sh

# Check all dependencies
./test/utils/check_dependencies.sh
```

## 📈 Performance Considerations

### Test Execution Time
- **Complete Suite**: ~15-20 minutes
- **Core Tests**: ~2-3 minutes
- **Individual Features**: ~1-2 minutes each
- **Alert Validation**: ~3-5 minutes

### Resource Requirements
- **CPU**: Minimal impact during testing
- **Memory**: ~100-200MB additional usage
- **Disk**: ~50MB for logs and test data
- **Network**: Manager connectivity required for full testing

### Optimization Tips
- Run tests during low-activity periods
- Use test categories for focused validation
- Enable parallel execution for CI/CD environments
- Archive old test logs regularly

## 🔒 Security Considerations

### Test Data Security
- All test data is contained within the test environment
- No production data is used in testing
- Test artifacts are automatically cleaned up
- Simulated attacks are contained and safe

### Manager Communication
- Tests use secure agent-manager protocols
- Authentication keys are validated
- Encrypted communication channels are tested
- No sensitive data is transmitted during tests

## 📝 Contributing

### Adding New Tests
1. Create test script in appropriate feature directory
2. Source the test library: `source "$SCRIPT_DIR/../utils/test_lib.sh"`
3. Implement test functions following naming convention
4. Add comprehensive logging and assertions
5. Update documentation and test registration

### Test Development Guidelines
- Use descriptive test names and functions
- Implement proper error handling
- Include detailed logging for debugging
- Follow the established assertion patterns
- Ensure tests are idempotent and isolated

## 📞 Support

For issues, questions, or contributions:
- Review test logs in `logs/` directory
- Check agent configuration and connectivity
- Validate environment prerequisites
- Consult Wazuh documentation for agent-specific issues

---

**Framework Version**: 1.0.0  
**Compatible with**: Wazuh Agent 4.8.0+  
**Last Updated**: $(date)  
**Author**: Cybersecurity QA Engineering Team