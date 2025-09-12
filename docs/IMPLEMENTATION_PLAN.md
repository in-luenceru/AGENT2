# Complete Implementation Plan: Upgrading Extracted Agent to Full Wazuh Capabilities

## Overview
This document provides a comprehensive, step-by-step implementation plan to transform the extracted agent from a mock implementation into a fully functional Wazuh agent with all security monitoring capabilities.

## Implementation Phases

### Phase 1: Critical Infrastructure Restoration (Days 1-2)

#### 1.1 Replace Mock Binaries with Real Implementations
**Priority: CRITICAL**
**Time Estimate: 4-6 hours**

**Current State**: Shell script mocks in `/workspaces/AGENT2/bin/`
**Target State**: Compiled C binaries with full functionality

**Steps:**
```bash
# 1. Clean existing mock binaries
cd /workspaces/AGENT2
rm -f bin/wazuh-*

# 2. Build real binaries from source
cd /workspaces/AGENT2
./build_agent.sh --clean --debug

# 3. Verify binary compilation
ls -la bin/
file bin/wazuh-agentd  # Should show ELF executable

# 4. Test binary functionality
bin/wazuh-agentd -t  # Test configuration parsing
```

**Dependencies:**
- Working CMake build system
- All required libraries (OpenSSL, zlib)
- Proper source code compilation

**Validation:**
- All 5 core binaries compile without errors
- Binaries can parse configuration files
- No segmentation faults on startup

#### 1.2 Import Complete SCA Ruleset
**Priority: CRITICAL**
**Time Estimate: 2-3 hours**

**Current State**: 2 SCA policy files
**Target State**: 74 complete SCA policy files

**Steps:**
```bash
# 1. Backup current ruleset
cp -r /workspaces/AGENT2/ruleset /workspaces/AGENT2/backup/ruleset.backup

# 2. Copy complete ruleset from full Wazuh
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/ruleset/* /workspaces/AGENT2/ruleset/

# 3. Verify ruleset integrity
find /workspaces/AGENT2/ruleset/sca -name "*.yml" | wc -l  # Should be 74

# 4. Test SCA configuration
bin/wazuh-modulesd -t  # Test SCA module configuration
```

**Validation:**
- All 74 SCA policy files present
- No YAML syntax errors
- SCA module loads policies without errors

#### 1.3 Fix Build System and Dependencies
**Priority: CRITICAL**
**Time Estimate: 3-4 hours**

**Steps:**
```bash
# 1. Compare and update CMakeLists.txt
diff /workspaces/AGENT2/CMakeLists.txt /workspaces/AGENT2/WAZUH_FULL/wazuh/src/CMakeLists.txt

# 2. Update library paths and dependencies
./update_lib_paths.sh

# 3. Install missing development dependencies
sudo apt-get update
sudo apt-get install -y \
  cmake gcc g++ make \
  libssl-dev zlib1g-dev \
  libcurl4-openssl-dev \
  libyaml-dev libpcre2-dev

# 4. Clean rebuild with all dependencies
./build_agent.sh --clean --install
```

### Phase 2: Core Security Features (Days 3-5)

#### 2.1 Restore Complete Log Analysis Engine
**Priority: HIGH**
**Time Estimate: 8-10 hours**

**Current State**: Basic log collection configured
**Target State**: Multi-format log parsing with real-time analysis

**Implementation Steps:**

1. **Copy Missing Log Analysis Components**
```bash
# Copy log format parsers
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/src/logcollector/* /workspaces/AGENT2/src/logcollector/

# Update logcollector configuration
cp /workspaces/AGENT2/WAZUH_FULL/wazuh/etc/internal_options.conf /workspaces/AGENT2/etc/
```

2. **Configure Advanced Log Monitoring**
```xml
<!-- Add to ossec.conf -->
<localfile>
  <log_format>json</log_format>
  <location>/var/log/json_events.log</location>
</localfile>

<localfile>
  <log_format>multi-line</log_format>
  <location>/var/log/application.log</location>
  <target>agent</target>
</localfile>

<!-- Windows Event Log monitoring (if needed) -->
<localfile>
  <log_format>eventlog</log_format>
  <location>Application</location>
</localfile>
```

3. **Implement Real-time Log Processing**
```bash
# Configure real-time monitoring
echo "logcollector.remote_commands=1" >> /workspaces/AGENT2/etc/local_internal_options.conf
echo "logcollector.loop_timeout=1" >> /workspaces/AGENT2/etc/local_internal_options.conf
```

**Validation:**
- Multi-format logs properly parsed (syslog, JSON, XML)
- Real-time log forwarding to manager
- No memory leaks during log processing

#### 2.2 Enhanced File Integrity Monitoring
**Priority: HIGH**
**Time Estimate: 4-6 hours**

**Implementation Steps:**

1. **Configure Advanced FIM Settings**
```xml
<!-- Enhanced FIM configuration -->
<syscheck>
  <disabled>no</disabled>
  <frequency>300</frequency>  <!-- 5 minutes -->
  <scan_on_start>yes</scan_on_start>
  <alert_new_files>yes</alert_new_files>
  
  <!-- Real-time monitoring -->
  <directories realtime="yes" report_changes="yes" check_all="yes">/etc</directories>
  <directories realtime="yes" report_changes="yes">/home</directories>
  <directories realtime="yes" check_all="yes">/usr/bin,/usr/sbin</directories>
  
  <!-- Detailed change reporting -->
  <directories check_all="yes" report_changes="yes">/var/www</directories>
  <directories check_all="yes" report_changes="yes">/opt</directories>
  
  <!-- Performance optimization -->
  <max_eps>200</max_eps>
  <process_priority>10</process_priority>
</syscheck>
```

2. **Enable FIM Database Synchronization**
```xml
<synchronization>
  <enabled>yes</enabled>
  <interval>5m</interval>
  <max_eps>10</max_eps>
</synchronization>
```

**Validation:**
- Real-time file change detection
- Detailed diff reporting for text files
- Proper exclusion of temporary files

#### 2.3 Rootkit Detection Implementation
**Priority: HIGH**
**Time Estimate: 6-8 hours**

**Implementation Steps:**

1. **Copy Complete Rootcheck Module**
```bash
# Copy rootcheck implementation
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/src/rootcheck/* /workspaces/AGENT2/src/rootcheck/

# Copy rootcheck databases
mkdir -p /workspaces/AGENT2/etc/shared
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/etc/shared/* /workspaces/AGENT2/etc/shared/
```

2. **Configure Rootcheck Settings**
```xml
<rootcheck>
  <disabled>no</disabled>
  <frequency>7200</frequency>  <!-- 2 hours -->
  
  <!-- Enable all rootcheck features -->
  <check_files>yes</check_files>
  <check_trojans>yes</check_trojans>
  <check_dev>yes</check_dev>
  <check_sys>yes</check_sys>
  <check_pids>yes</check_pids>
  <check_ports>yes</check_ports>
  <check_if>yes</check_if>
  
  <!-- System audit -->
  <check_unixaudit>yes</check_unixaudit>
  <system_audit>/workspaces/AGENT2/etc/shared/system_audit_rcl.txt</system_audit>
  <system_audit>/workspaces/AGENT2/etc/shared/cis_debian_linux_rcl.txt</system_audit>
  
  <!-- Rootkit databases -->
  <rootkit_files>/workspaces/AGENT2/etc/shared/rootkit_files.txt</rootkit_files>
  <rootkit_trojans>/workspaces/AGENT2/etc/shared/rootkit_trojans.txt</rootkit_trojans>
  
  <skip_nfs>yes</skip_nfs>
</rootcheck>
```

**Validation:**
- Rootkit signature detection
- System audit policy compliance
- Trojan detection capabilities

### Phase 3: Advanced Monitoring Capabilities (Days 6-8)

#### 3.1 Vulnerability Assessment Integration
**Priority: MEDIUM**
**Time Estimate: 10-12 hours**

**Implementation Steps:**

1. **Enable Vulnerability Scanner Module**
```xml
<wodle name="vulnerability-scanner">
  <disabled>no</disabled>
  <interval>5m</interval>
  <ignore_time>6h</ignore_time>
  <run_on_start>yes</run_on_start>
  
  <!-- Providers configuration -->
  <provider name="canonical">
    <enabled>yes</enabled>
    <os>trusty,xenial,bionic,focal</os>
    <update_interval>1h</update_interval>
  </provider>
  
  <provider name="debian">
    <enabled>yes</enabled>
    <os>7,8,9,10,11</os>
    <update_interval>1h</update_interval>
  </provider>
  
  <provider name="redhat">
    <enabled>yes</enabled>
    <os>5,6,7,8</os>
    <update_interval>1h</update_interval>
  </provider>
</wodle>
```

2. **Configure CVE Feed Updates**
```bash
# Create vulnerability databases directory
mkdir -p /workspaces/AGENT2/var/wodles/vulnerability-scanner

# Configure automatic updates
echo "vulnerability_scanner.enabled=1" >> /workspaces/AGENT2/etc/local_internal_options.conf
```

**Validation:**
- CVE database downloads and updates
- Package vulnerability scanning
- Vulnerability reporting to manager

#### 3.2 System Inventory and Asset Management
**Priority: MEDIUM**
**Time Estimate: 6-8 hours**

**Implementation Steps:**

1. **Configure System Collector**
```xml
<wodle name="syscollector">
  <disabled>no</disabled>
  <interval>1h</interval>
  <scan_on_start>yes</scan_on_start>
  
  <!-- Inventory components -->
  <hardware>yes</hardware>
  <os>yes</os>
  <network>yes</network>
  <packages>yes</packages>
  <ports all="no">yes</ports>
  <processes>yes</processes>
  
  <!-- Performance settings -->
  <synchronization>
    <enabled>yes</enabled>
    <interval>5m</interval>
    <max_eps>10</max_eps>
  </synchronization>
</wodle>
```

**Validation:**
- Hardware inventory collection
- Software package tracking
- Network configuration monitoring
- Process monitoring

### Phase 4: Cloud Integration and Extended Features (Days 9-12)

#### 4.1 Cloud Security Monitoring (Wodles)
**Priority: MEDIUM**
**Time Estimate: 12-15 hours**

**Implementation Steps:**

1. **Copy Cloud Integration Modules**
```bash
# Copy wodles directory
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/wodles /workspaces/AGENT2/

# Install Python dependencies
pip3 install boto3 azure-storage-blob google-cloud-logging requests
```

2. **Configure AWS Integration**
```xml
<wodle name="aws-s3">
  <disabled>no</disabled>
  <interval>10m</interval>
  <run_on_start>yes</run_on_start>
  <skip_on_error>yes</skip_on_error>
  
  <bucket type="cloudtrail">
    <name>my-cloudtrail-bucket</name>
    <access_key>AKIAIOSFODNN7EXAMPLE</access_key>
    <secret_key>wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY</secret_key>
    <path>cloudtrail</path>
  </bucket>
</wodle>
```

3. **Configure Azure Integration**
```xml
<wodle name="azure-logs">
  <disabled>no</disabled>
  <interval>10m</interval>
  <run_on_start>yes</run_on_start>
  
  <log_analytics>
    <auth_path>/workspaces/AGENT2/etc/azure_credentials</auth_path>
    <tenantdomain>your-tenant.onmicrosoft.com</tenantdomain>
    <request>
      <query>SecurityEvent | where EventID == 4625</query>
      <workspace>your-workspace-id</workspace>
      <time_offset>1d</time_offset>
    </request>
  </log_analytics>
</wodle>
```

**Validation:**
- AWS CloudTrail log ingestion
- Azure Activity Log monitoring
- Google Cloud Security Command Center integration

#### 4.2 Enhanced Active Response
**Priority: MEDIUM**
**Time Estimate: 8-10 hours**

**Implementation Steps:**

1. **Copy Active Response Scripts**
```bash
# Copy complete active response directory
cp -r /workspaces/AGENT2/WAZUH_FULL/wazuh/active-response/* /workspaces/AGENT2/active-response/

# Make scripts executable
chmod +x /workspaces/AGENT2/active-response/bin/*
```

2. **Configure Active Response Rules**
```xml
<!-- Firewall blocking -->
<command>
  <name>firewall-drop</name>
  <executable>firewall-drop</executable>
  <timeout_allowed>yes</timeout_allowed>
</command>

<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>5712</rules_id>
  <timeout>300</timeout>
</active-response>

<!-- Account disabling -->
<command>
  <name>disable-account</name>
  <executable>disable-account</executable>
  <timeout_allowed>yes</timeout_allowed>
</command>

<active-response>
  <command>disable-account</command>
  <location>local</location>
  <rules_id>5503,5504</rules_id>
  <timeout>600</timeout>
</active-response>
```

**Validation:**
- Firewall rules creation/removal
- Account disabling/enabling
- Custom response script execution

### Phase 5: Performance Optimization and Final Integration (Days 13-14)

#### 5.1 Performance Tuning
**Time Estimate: 4-6 hours**

**Implementation Steps:**

1. **Optimize Internal Settings**
```bash
# Create optimized internal options
cat >> /workspaces/AGENT2/etc/local_internal_options.conf << EOF
# Performance optimization
agent.recv_timeout=60
logcollector.loop_timeout=1
syscheck.sleep=1
rootcheck.sleep=1

# Memory optimization
agent.buffer_size=16384
logcollector.queue_size=8192

# Network optimization
agent.notify_time=30
agent.max_retries=3
EOF
```

2. **Database Optimization**
```bash
# Configure database settings
echo "wazuh_database.sync_interval=5" >> /workspaces/AGENT2/etc/local_internal_options.conf
echo "wazuh_database.max_eps=1000" >> /workspaces/AGENT2/etc/local_internal_options.conf
```

#### 5.2 Final Integration Testing
**Time Estimate: 6-8 hours**

**Testing Checklist:**

1. **Functional Testing**
```bash
# Test all daemon startup
/workspaces/AGENT2/bin/wazuh-control start

# Verify all processes running
ps aux | grep wazuh

# Test configuration
/workspaces/AGENT2/bin/wazuh-agentd -t
/workspaces/AGENT2/bin/wazuh-modulesd -t
```

2. **Security Feature Testing**
```bash
# Test FIM
echo "test" > /etc/test_fim
sleep 10
grep "test_fim" /workspaces/AGENT2/logs/ossec.log

# Test log monitoring
logger "Test security event for Wazuh"
sleep 5
grep "Test security event" /workspaces/AGENT2/logs/ossec.log

# Test rootcheck
/workspaces/AGENT2/bin/wazuh-modulesd -f rootcheck
```

## Implementation Script Templates

### Master Build Script
```bash
#!/bin/bash
# Complete Wazuh Agent Restoration Script

set -e

echo "Starting Wazuh Agent complete restoration..."

# Phase 1: Infrastructure
echo "Phase 1: Restoring core infrastructure..."
./scripts/01_replace_binaries.sh
./scripts/02_import_ruleset.sh
./scripts/03_fix_dependencies.sh

# Phase 2: Core Features
echo "Phase 2: Implementing core security features..."
./scripts/04_log_analysis.sh
./scripts/05_enhanced_fim.sh
./scripts/06_rootkit_detection.sh

# Phase 3: Advanced Features
echo "Phase 3: Adding advanced monitoring..."
./scripts/07_vulnerability_scanner.sh
./scripts/08_system_inventory.sh

# Phase 4: Cloud Integration
echo "Phase 4: Cloud integration setup..."
./scripts/09_cloud_integration.sh
./scripts/10_active_response.sh

# Phase 5: Optimization
echo "Phase 5: Performance optimization..."
./scripts/11_performance_tuning.sh
./scripts/12_final_testing.sh

echo "Wazuh Agent restoration complete!"
echo "Run './validate_complete_functionality.sh' to verify all features."
```

### Validation Script
```bash
#!/bin/bash
# Complete Functionality Validation

echo "=== Wazuh Agent Complete Functionality Validation ==="

# Check binaries
echo "Checking binaries..."
for binary in wazuh-agentd wazuh-logcollector wazuh-syscheckd wazuh-modulesd wazuh-execd; do
    if [[ -x "/workspaces/AGENT2/bin/$binary" ]]; then
        echo "✅ $binary: Present and executable"
        file "/workspaces/AGENT2/bin/$binary" | grep -q "ELF" && echo "   ✅ Compiled binary" || echo "   ❌ Not compiled"
    else
        echo "❌ $binary: Missing or not executable"
    fi
done

# Check ruleset
echo "Checking ruleset..."
sca_count=$(find /workspaces/AGENT2/ruleset/sca -name "*.yml" | wc -l)
if [[ $sca_count -eq 74 ]]; then
    echo "✅ SCA Policies: Complete ($sca_count policies)"
else
    echo "❌ SCA Policies: Incomplete ($sca_count/74 policies)"
fi

# Check wodles
echo "Checking cloud integrations..."
if [[ -d "/workspaces/AGENT2/wodles" ]]; then
    echo "✅ Wodles: Present"
    for wodle in aws azure gcloud docker-listener; do
        [[ -d "/workspaces/AGENT2/wodles/$wodle" ]] && echo "   ✅ $wodle integration" || echo "   ❌ $wodle missing"
    done
else
    echo "❌ Wodles: Missing"
fi

# Test configuration
echo "Testing configuration..."
if /workspaces/AGENT2/bin/wazuh-agentd -t >/dev/null 2>&1; then
    echo "✅ Configuration: Valid"
else
    echo "❌ Configuration: Invalid"
fi

# Test module functionality
echo "Testing modules..."
/workspaces/AGENT2/bin/wazuh-modulesd -t >/dev/null 2>&1 && echo "✅ Modules: Functional" || echo "❌ Modules: Non-functional"

echo "=== Validation Complete ==="
```

## Risk Mitigation

### Backup Strategy
```bash
# Create complete backup before implementation
tar -czf /workspaces/AGENT2/backup/agent-backup-$(date +%Y%m%d).tar.gz \
  /workspaces/AGENT2/bin \
  /workspaces/AGENT2/etc \
  /workspaces/AGENT2/ruleset \
  /workspaces/AGENT2/src
```

### Rollback Plan
```bash
# Quick rollback if needed
cp /workspaces/AGENT2/backup/agent-backup-*.tar.gz /tmp/
cd /workspaces/AGENT2
tar -xzf /tmp/agent-backup-*.tar.gz --strip-components=2
```

## Success Metrics

### Functional Completeness
- [ ] All 5 core daemons compiled and functional
- [ ] All 74 SCA policies present and active
- [ ] Cloud integrations (AWS, Azure, GCP) working
- [ ] Vulnerability scanning operational
- [ ] Active response functional

### Performance Benchmarks
- [ ] CPU usage < 5% during normal operation
- [ ] Memory usage < 256MB per agent
- [ ] Log processing > 1000 EPS
- [ ] FIM scanning < 30 seconds for standard directories

### Security Validation
- [ ] All security features detect test threats
- [ ] No false positives in baseline environment
- [ ] Proper encryption of manager communication
- [ ] Active response triggers correctly

---

**Next Phase**: Begin Phase 1 implementation with critical infrastructure restoration. Each phase should be completed and validated before proceeding to the next phase.