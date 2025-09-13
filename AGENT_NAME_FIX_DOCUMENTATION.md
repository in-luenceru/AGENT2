# 🛡️ AGENT NAME CONFIGURATION FIX - DOCUMENTATION

## Root Cause Analysis Report

### **Primary Issues Identified**

1. **Environment Variable Fallback**: The `monitor-control` script defaulted `AGENT_NAME` to `$(hostname -s)` 
2. **Missing Configuration Specification**: The `ossec.conf` file lacked agent name in the `<client>` section
3. **Configuration Generation Gap**: The `create_default_config()` function didn't include agent name
4. **Runtime vs Configuration Mismatch**: Enrollment used correct name but running agent didn't read it

### **The Fix Implementation**

#### 1. **Agent Name Priority System**
```bash
# Priority Order:
# 1. Environment variable AGENT_NAME
# 2. Configuration file <enrollment><agent_name>
# 3. Hostname fallback (last resort)

initialize_agent_name() {
    # Priority 1: Environment variable
    if [[ -n "$AGENT_NAME" ]]; then
        return 0
    fi
    
    # Priority 2: Configuration file
    local config_name
    if config_name=$(get_agent_name_from_config); then
        AGENT_NAME="$config_name"
        return 0
    fi
    
    # Priority 3: Hostname fallback
    AGENT_NAME="$(hostname -s)"
}
```

#### 2. **Configuration File Enhancement**
```xml
<ossec_config>
  <client>
    <server>
      <address>MANAGER_IP</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <enrollment>
      <enabled>yes</enabled>
      <manager_address>MANAGER_IP</manager_address>
      <agent_name>CUSTOM_AGENT_NAME</agent_name>
      <groups>AGENT_GROUPS</groups>
    </enrollment>
  </client>
</ossec_config>
```

#### 3. **Agent Name Configuration Function**
```bash
update_agent_name_config() {
    local agent_name="$1"
    
    # Updates both AGENT_NAME variable and ossec.conf file
    # Handles both new enrollment sections and existing ones
    # Supports xmlstarlet and fallback sed methods
}
```

## Configuration Requirements

### **Setting Agent Name**

#### Method 1: Environment Variable
```bash
export AGENT_NAME="production-security-agent-001"
./monitor-control enroll
```

#### Method 2: Direct Configuration Edit
```xml
<client>
  <enrollment>
    <enabled>yes</enabled>
    <agent_name>production-security-agent-001</agent_name>
  </enrollment>
</client>
```

#### Method 3: During Enrollment
```bash
# Interactive enrollment will prompt for agent name
./monitor-control enroll
# Agent name [codespaces-720563]: production-security-agent-001
```

### **Verification Steps**

#### 1. Check Current Agent Name
```bash
# View current configuration
grep -A 5 "<enrollment>" /etc/ossec.conf

# Check environment
echo $AGENT_NAME

# Verify priority resolution
./monitor-control version
```

#### 2. Test Configuration
```bash
# Set custom name
export AGENT_NAME="custom-agent-name"

# Restart agent
sudo ./monitor-control restart

# Check logs for correct name usage
tail -f logs/ossec.log | grep -i agent
```

#### 3. Manager Verification
```bash
# On manager, check connected agents
/var/ossec/bin/agent_control -l

# Look for your custom agent name in the list
```

## Security Considerations

### **File Permissions**
```bash
# Ensure proper permissions on config files
chmod 640 /etc/ossec.conf
chown root:ossec /etc/ossec.conf

# Client keys should be protected
chmod 640 /etc/client.keys
chown root:ossec /etc/client.keys
```

### **Agent Name Validation**
- Agent names should be unique across your environment
- Use descriptive names that indicate purpose/location
- Avoid special characters that might cause parsing issues
- Consider using standardized naming conventions

### **Configuration Backup**
```bash
# Always backup before changes
cp /etc/ossec.conf /etc/ossec.conf.backup.$(date +%Y%m%d_%H%M%S)

# Verify configuration after changes
./monitor-control test
```

## Troubleshooting

### **Agent Name Not Applied**

1. **Check Priority Order**
   ```bash
   # Unset environment variable if needed
   unset AGENT_NAME
   
   # Check config file
   grep "<agent_name>" /etc/ossec.conf
   
   # Restart agent
   sudo ./monitor-control restart
   ```

2. **Configuration Syntax Issues**
   ```bash
   # Validate XML syntax
   xmllint --noout /etc/ossec.conf
   
   # Check agent configuration test
   ./monitor-control test
   ```

3. **Manager Communication**
   ```bash
   # Test manager connectivity
   ./monitor-control test
   
   # Check agent logs
   tail -f logs/ossec.log
   
   # Verify enrollment
   cat /etc/client.keys
   ```

### **Name Reverts to Hostname**

1. **Missing Configuration**: Add `<enrollment><agent_name>` section
2. **Environment Override**: Check for `AGENT_NAME` environment variable
3. **Daemon Restart Required**: Agent name changes require restart

## Testing Framework

### **Validation Script**
```bash
#!/bin/bash
# Test agent name configuration

# Test 1: Environment variable priority
export AGENT_NAME="test-agent"
result=$(./monitor-control version | grep -c "test-agent")

# Test 2: Configuration file reading
grep -q "<agent_name>test-agent</agent_name>" /etc/ossec.conf

# Test 3: Manager communication
./monitor-control test | grep -q "Agent Name: test-agent"
```

## Implementation Summary

✅ **Fixed Issues:**
- Agent name priority system implemented
- Configuration generation includes agent name
- Enrollment updates configuration properly
- Hostname fallback preserved for backward compatibility

✅ **Security Enhancements:**
- Proper configuration file validation
- Environment variable protection
- File permission enforcement

✅ **Operational Improvements:**
- Clear error messages for troubleshooting
- Multiple configuration methods supported
- Comprehensive testing and validation

The agent name will now consistently reflect the configured value in all contexts:
- Manager communications
- Log entries  
- Alert messages
- Status reports
- Audit trails