# Wazuh Agent - Standalone Extraction

This directory contains a complete, self-contained extraction of the Wazuh Agent from the official Wazuh cybersecurity platform. The agent can be built and deployed independently without requiring the full Wazuh ecosystem.

## Overview

The Wazuh Agent provides:
- **Log Collection**: Real-time log file monitoring and forwarding
- **File Integrity Monitoring (FIM)**: Detection of file system changes
- **Security Configuration Assessment (SCA)**: Security policy compliance checking
- **Active Response**: Automated threat response capabilities
- **System Inventory**: Asset and configuration collection
- **Vulnerability Assessment**: Security vulnerability detection
- **Rootcheck**: Host-based anomaly and rootkit detection

## Directory Structure

```
AGENT/
├── build_agent.sh          # Main build script
├── CMakeLists.txt          # CMake build configuration
├── etc/                    # Configuration files
│   ├── ossec.conf          # Main agent configuration
│   ├── agent.conf          # Agent-specific settings
│   ├── internal_options.conf # Internal tuning parameters
│   └── templates/          # Configuration templates
├── ruleset/                # Detection rules and decoders
├── src/                    # Source code
│   ├── client-agent/       # Core agent daemon
│   ├── logcollector/       # Log collection engine
│   ├── syscheckd/          # File integrity monitoring
│   ├── os_execd/           # Active response execution
│   ├── rootcheck/          # Host-based intrusion detection
│   ├── wazuh_modules/      # Modular components
│   ├── shared/             # Common utilities and libraries
│   ├── shared_modules/     # Shared C++ modules
│   └── ...                 # Supporting libraries
├── scripts/                # Management scripts
└── bin-support/           # Active response scripts
```

## Requirements

### System Requirements
- **Operating System**: Linux (Ubuntu 18.04+, RHEL 7+, or equivalent)
- **Architecture**: x86_64 or ARM64
- **Memory**: 512MB RAM minimum, 1GB recommended
- **Disk Space**: 200MB for installation
- **Network**: Outbound access to Wazuh Manager (TCP/1514, UDP/1514)

### Build Dependencies
- **CMake**: 3.12.4 or later
- **GCC**: 7.0+ or Clang 8.0+
- **Development packages**:
  ```bash
  # Ubuntu/Debian
  sudo apt-get install cmake gcc g++ make libssl-dev zlib1g-dev libc6-dev
  
  # RHEL/CentOS/Fedora
  sudo yum install cmake gcc gcc-c++ make openssl-devel zlib-devel glibc-devel
  ```

### Runtime Dependencies
- **OpenSSL**: For encryption and authentication
- **Zlib**: For data compression
- **System libraries**: pthread, libm

## Building the Agent

### Quick Build
```bash
# Make build script executable
chmod +x build_agent.sh

# Build with default settings
./build_agent.sh

# Build with debug symbols
./build_agent.sh --debug

# Clean build
./build_agent.sh --clean

# Build and install
./build_agent.sh --install
```

### Advanced Build Options
```bash
# Custom installation prefix
INSTALL_PREFIX=/opt/wazuh-agent ./build_agent.sh --install

# Additional CMake arguments
CMAKE_ARGS="-DCMAKE_C_COMPILER=clang" ./build_agent.sh

# Build specific configuration
./build_agent.sh --debug --clean --install
```

### Manual Build Process
```bash
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/var/ossec ..
cmake --build . --parallel $(nproc)
sudo cmake --install .
```

## Configuration

### Basic Agent Configuration

1. **Edit the main configuration file**:
   ```bash
   sudo nano /var/ossec/etc/ossec.conf
   ```

2. **Configure manager connection**:
   ```xml
   <ossec_config>
     <client>
       <server>
         <address>YOUR_MANAGER_IP</address>
         <port>1514</port>
         <protocol>tcp</protocol>
       </server>
       <notify_time>10</notify_time>
       <time-reconnect>60</time-reconnect>
     </client>
   </ossec_config>
   ```

3. **Enable desired modules**:
   ```xml
   <ossec_config>
     <!-- Log collection -->
     <localfile>
       <log_format>syslog</log_format>
       <location>/var/log/syslog</location>
     </localfile>

     <!-- File integrity monitoring -->
     <syscheck>
       <directories check_all="yes">/etc,/usr/bin,/usr/sbin</directories>
       <directories check_all="yes" realtime="yes">/home</directories>
     </syscheck>

     <!-- Rootcheck -->
     <rootcheck>
       <disabled>no</disabled>
       <check_unixaudit>yes</check_unixaudit>
       <check_files>yes</check_files>
       <check_trojans>yes</check_trojans>
       <check_dev>yes</check_dev>
     </rootcheck>

     <!-- SCA -->
     <sca>
       <enabled>yes</enabled>
       <scan_on_start>yes</scan_on_start>
       <interval>12h</interval>
       <skip_nfs>yes</skip_nfs>
     </sca>
   </ossec_config>
   ```

### Agent Enrollment

1. **On the Wazuh Manager**, add the agent:
   ```bash
   /var/ossec/bin/manage_agents -a
   ```

2. **Extract the agent key** from the manager:
   ```bash
   /var/ossec/bin/manage_agents -e AGENT_ID
   ```

3. **On the agent**, import the key:
   ```bash
   /var/ossec/bin/manage_agents -i
   # Paste the key when prompted
   ```

4. **Alternative: Auto-enrollment** (if enabled on manager):
   ```xml
   <client>
     <enrollment>
       <enabled>yes</enabled>
       <manager_address>MANAGER_IP</manager_address>
       <port>1515</port>
       <agent_name>my-agent</agent_name>
       <groups>default,web-servers</groups>
     </enrollment>
   </client>
   ```

## Running the Agent

### Start/Stop/Status
```bash
# Start all agent processes
/var/ossec/bin/wazuh-control start

# Stop all agent processes
/var/ossec/bin/wazuh-control stop

# Restart agent
/var/ossec/bin/wazuh-control restart

# Check status
/var/ossec/bin/wazuh-control status

# Check individual daemon status
ps aux | grep wazuh
```

### Manual Daemon Control
```bash
# Individual daemons
/var/ossec/bin/wazuh-agentd         # Core agent daemon
/var/ossec/bin/wazuh-logcollector   # Log collection
/var/ossec/bin/wazuh-syscheckd      # File integrity monitoring
/var/ossec/bin/wazuh-modulesd       # Modules daemon
/var/ossec/bin/wazuh-execd          # Active response

# Test configuration
/var/ossec/bin/wazuh-agentd -t
```

### Systemd Service (Optional)
Create a systemd service file:
```bash
sudo tee /etc/systemd/system/wazuh-agent.service > /dev/null <<EOF
[Unit]
Description=Wazuh Agent
After=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=/var/ossec/bin/wazuh-control start
ExecStop=/var/ossec/bin/wazuh-control stop
ExecReload=/var/ossec/bin/wazuh-control restart
PIDFile=/var/ossec/var/run/wazuh-agentd.pid

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
```

## Testing and Validation

### Functional Test Checklist

#### ✅ Build Verification
- [ ] All binaries compile without errors
- [ ] No missing dependencies during build
- [ ] All daemon executables are created

#### ✅ Configuration Test
- [ ] Agent parses configuration without errors: `wazuh-agentd -t`
- [ ] All required directories are created
- [ ] Permissions are set correctly

#### ✅ Network Connectivity
- [ ] Agent can connect to manager
- [ ] Enrollment completes successfully
- [ ] Agent appears as "Active" in manager

#### ✅ Log Collection
- [ ] Create test log file and add to configuration
- [ ] Append test entries to monitored log
- [ ] Verify events appear in manager

#### ✅ File Integrity Monitoring
- [ ] Add test directory to FIM configuration
- [ ] Create, modify, and delete test files
- [ ] Verify FIM events in manager

#### ✅ Active Response
- [ ] Configure test active response rule
- [ ] Trigger rule condition
- [ ] Verify response script execution

#### ✅ System Modules
- [ ] Verify SCA scans complete
- [ ] Check system inventory collection
- [ ] Test vulnerability scanning (if enabled)

### Test Scripts

#### Basic Connectivity Test
```bash
#!/bin/bash
echo "Testing Wazuh Agent functionality..."

# Test configuration
echo "1. Testing configuration..."
/var/ossec/bin/wazuh-agentd -t && echo "✅ Configuration valid" || echo "❌ Configuration invalid"

# Test log generation
echo "2. Testing log collection..."
echo "Test log entry $(date)" >> /tmp/test.log
sleep 5
grep "Test log entry" /var/ossec/logs/ossec.log && echo "✅ Log collection working" || echo "❌ Log collection failed"

# Test FIM
echo "3. Testing FIM..."
echo "test" > /tmp/fim_test
sleep 10
grep "fim_test" /var/ossec/logs/ossec.log && echo "✅ FIM working" || echo "❌ FIM failed"

echo "Test completed."
```

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Check dependencies
   ./build_agent.sh --help
   
   # Clean and rebuild
   ./build_agent.sh --clean --debug
   ```

2. **Connection Issues**
   ```bash
   # Check network connectivity
   telnet MANAGER_IP 1514
   
   # Verify agent key
   cat /var/ossec/etc/client.keys
   
   # Check logs
   tail -f /var/ossec/logs/ossec.log
   ```

3. **Permission Issues**
   ```bash
   # Fix ownership
   sudo chown -R root:ossec /var/ossec/
   
   # Fix permissions
   sudo chmod 755 /var/ossec/bin/*
   ```

4. **High Resource Usage**
   ```bash
   # Adjust internal options
   nano /var/ossec/etc/local_internal_options.conf
   
   # Example optimizations:
   # logcollector.loop_timeout=1
   # syscheck.sleep=1
   # agent.recv_timeout=60
   ```

### Log Locations
- **Agent logs**: `/var/ossec/logs/ossec.log`
- **Active response logs**: `/var/ossec/logs/active-responses.log`
- **FIM database**: `/var/ossec/queue/fim/db/`
- **Agent state**: `/var/ossec/var/run/wazuh-agentd.state`

## Advanced Features

### Cloud Integration
The extracted agent supports cloud-specific modules:
- **AWS**: CloudTrail, VPC Flow Logs, GuardDuty
- **Azure**: Activity Logs, NSG Flow Logs, Security Center
- **GCP**: Cloud Logging, Security Command Center

### Custom Active Response
Create custom response scripts in `/var/ossec/active-response/bin/`:
```bash
#!/bin/bash
# Custom active response script
echo "$(date) - Custom response triggered with: $@" >> /tmp/custom_response.log
```

### Performance Tuning
Adjust internal options in `/var/ossec/etc/local_internal_options.conf`:
```ini
# Reduce CPU usage
agent.recv_timeout=60
logcollector.loop_timeout=2
syscheck.sleep=2

# Reduce memory usage
agent.buffer_size=1024
logcollector.queue_size=512
```

## Support and Documentation

- **Official Documentation**: [Wazuh Documentation](https://documentation.wazuh.com/)
- **Community Forum**: [Wazuh Community](https://wazuh.com/community/)
- **GitHub Issues**: [Wazuh Repository](https://github.com/wazuh/wazuh)

## License

This extracted agent maintains the same license as the original Wazuh project. See the `LICENSE` file for details.

---

**Note**: This is an extracted, standalone version of the Wazuh Agent. For production deployments, consider using the official Wazuh packages which include additional packaging, service management, and update mechanisms.
