#!/bin/bash

# 🎯 COMPREHENSIVE WAZUH ATTACK SIMULATION & DETECTION TEST
# This script systematically tests various attack vectors to validate Wazuh detection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Icons
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
TARGET="🎯"
SHIELD="🛡️"

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${SHIELD} ${PURPLE}WAZUH AGENT ATTACK SIMULATION & DETECTION TEST${NC} ${SHIELD} ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

wait_for_detection() {
    local test_name="$1"
    local wait_time="${2:-30}"
    
    echo -e "${INFO} Waiting ${wait_time} seconds for detection processing..."
    for i in $(seq $wait_time -1 1); do
        printf "\r${CYAN}⏳ Processing detection: ${i}s remaining${NC}"
        sleep 1
    done
    echo
}

check_recent_alerts() {
    local description="$1"
    echo -e "${INFO} Checking for alerts: $description"
    
    # Check manager alerts
    local alert_count=$(docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime 0 -exec tail -50 {} \; 2>/dev/null | wc -l)
    
    if [[ $alert_count -gt 0 ]]; then
        echo -e "${SUCCESS} Found $alert_count recent alert lines"
        docker exec wazuh-manager tail -10 /var/ossec/logs/alerts/alerts.log 2>/dev/null | grep -E "($(date +'%b %d')|$(date +'%Y %b %d'))" || echo "No matching alerts for today"
    else
        echo -e "${WARNING} No recent alerts found"
    fi
    
    # Check agent logs for events
    echo -e "${INFO} Checking agent logs..."
    sudo tail -10 /var/ossec/logs/ossec.log | grep -E "(ERROR|WARNING|INFO)" || echo "No recent errors/warnings"
}

test_1_ssh_brute_force() {
    echo -e "${TARGET} ${YELLOW}TEST 1: SSH Brute Force Attack Simulation${NC}"
    echo "=========================================="
    
    echo -e "${INFO} Simulating SSH brute force attack..."
    echo "This test attempts multiple SSH logins to trigger authentication failure alerts"
    
    # Check if SSH is running
    if ! systemctl is-active --quiet ssh; then
        echo -e "${WARNING} SSH service not running. Starting temporary SSH server..."
        sudo systemctl start ssh 2>/dev/null || echo "Could not start SSH service"
    fi
    
    # Generate multiple SSH failures
    echo -e "${INFO} Generating authentication failures..."
    for i in {1..6}; do
        echo -e "${CYAN}Attempt $i: Trying invalid SSH login${NC}"
        sshpass -p "wrongpassword" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no nonexistentuser@127.0.0.1 "echo test" 2>/dev/null || true
        sleep 2
    done
    
    wait_for_detection "SSH Brute Force" 45
    check_recent_alerts "SSH authentication failures"
    echo
}

test_2_sudo_privilege_escalation() {
    echo -e "${TARGET} ${YELLOW}TEST 2: Sudo Privilege Escalation Detection${NC}"
    echo "============================================="
    
    echo -e "${INFO} Testing sudo usage detection (this should generate alerts)..."
    
    # Generate sudo events (these are logged to journald which agent monitors)
    echo -e "${CYAN}Generating sudo events...${NC}"
    sudo -l >/dev/null 2>&1 || true
    sudo whoami >/dev/null 2>&1 || true
    sudo id >/dev/null 2>&1 || true
    
    # Check for suspicious sudo patterns
    echo -e "${CYAN}Testing potential privilege escalation patterns...${NC}"
    sudo echo "SECURITY_TEST: $(date)" >> /tmp/security_test.log 2>/dev/null || true
    
    wait_for_detection "Sudo/Privilege Events" 30
    check_recent_alerts "sudo privilege escalation"
    echo
}

test_3_file_integrity_monitoring() {
    echo -e "${TARGET} ${YELLOW}TEST 3: File Integrity Monitoring (FIM)${NC}"
    echo "========================================"
    
    echo -e "${INFO} Testing file integrity monitoring..."
    echo "Modifying files in monitored directories to trigger FIM alerts"
    
    # Create test file in monitored directory
    TEST_FILE="/etc/wazuh_fim_test_$(date +%s).conf"
    echo -e "${CYAN}Creating test file: $TEST_FILE${NC}"
    sudo touch "$TEST_FILE"
    sudo echo "WAZUH_FIM_TEST=$(date)" | sudo tee "$TEST_FILE" >/dev/null
    
    sleep 5
    
    # Modify the file
    echo -e "${CYAN}Modifying test file to trigger FIM alert...${NC}"
    sudo echo "MODIFIED: $(date)" | sudo tee -a "$TEST_FILE" >/dev/null
    
    sleep 5
    
    # Delete the file
    echo -e "${CYAN}Deleting test file...${NC}"
    sudo rm -f "$TEST_FILE"
    
    wait_for_detection "File Integrity Monitoring" 60
    check_recent_alerts "file modification"
    echo
}

test_4_port_scan_detection() {
    echo -e "${TARGET} ${YELLOW}TEST 4: Enhanced Port Scan Detection${NC}"
    echo "===================================="
    
    echo -e "${INFO} Testing port scan detection with multiple techniques..."
    
    # Method 1: Rapid connection attempts to trigger rule 40601
    echo -e "${CYAN}Method 1: Rapid TCP connect scans (12+ attempts in 90s)${NC}"
    for port in {20..35}; do
        timeout 1 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null || true
        sleep 1
    done
    
    sleep 10
    
    # Method 2: Nmap with connection logging
    echo -e "${CYAN}Method 2: Nmap scan with verbose logging${NC}"
    nmap -v -sT -p 1-50 127.0.0.1 2>&1 | logger -t "SECURITY_SCAN" || true
    
    # Method 3: Manual port probing to generate netstat changes
    echo -e "${CYAN}Method 3: Opening listening ports (will be detected by netstat command)${NC}"
    nc -l -p 8888 &
    NC_PID=$!
    sleep 5
    kill $NC_PID 2>/dev/null || true
    
    wait_for_detection "Port Scanning" 45
    check_recent_alerts "port scan or network reconnaissance"
    echo
}

test_5_process_injection_simulation() {
    echo -e "${TARGET} ${YELLOW}TEST 5: Suspicious Process Activity${NC}"
    echo "===================================="
    
    echo -e "${INFO} Testing process monitoring and suspicious activity detection..."
    
    # Create suspicious process patterns
    echo -e "${CYAN}Starting suspicious processes that may trigger alerts...${NC}"
    
    # Long-running nmap process (detected by syscollector)
    nmap -T1 -p 1-10 127.0.0.1 &
    NMAP_PID=$!
    
    # Python reverse shell simulation (but harmless)
    python3 -c "
import socket
import time
print('Simulating suspicious network activity...')
for i in range(3):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect(('127.0.0.1', 4444))
        s.close()
    except:
        pass
    time.sleep(2)
" &
    PYTHON_PID=$!
    
    sleep 30
    
    # Clean up
    kill $NMAP_PID $PYTHON_PID 2>/dev/null || true
    
    wait_for_detection "Suspicious Processes" 40
    check_recent_alerts "suspicious process activity"
    echo
}

test_6_log_injection_attack() {
    echo -e "${TARGET} ${YELLOW}TEST 6: Log Injection & Custom Rule Testing${NC}"
    echo "============================================"
    
    echo -e "${INFO} Testing custom log injection and pattern detection..."
    
    # Inject attack signatures that should match attack rules
    echo -e "${CYAN}Injecting attack signatures into logs...${NC}"
    
    # Buffer overflow pattern (rule 40104)
    logger "SECURITY_TEST: Buffer overflow attempt detected: ?????????????????????"
    
    # Custom attack pattern
    logger "SECURITY_TEST: Possible intrusion detected - nmap scan from 127.0.0.1"
    
    # System user login simulation (rule 40101)
    logger "SECURITY_TEST: apache user login detected from 127.0.0.1"
    
    # Generate more structured attack logs
    logger -p authpriv.warning "SECURITY_TEST: Multiple failed login attempts detected"
    logger -p kern.warning "SECURITY_TEST: Possible DoS attack - excessive connections"
    
    wait_for_detection "Log Injection Attacks" 35
    check_recent_alerts "injected attack patterns"
    echo
}

test_7_system_command_monitoring() {
    echo -e "${TARGET} ${YELLOW}TEST 7: System Command Monitoring${NC}"
    echo "=================================="
    
    echo -e "${INFO} Testing system command execution monitoring..."
    
    # Commands that might trigger security alerts
    echo -e "${CYAN}Executing potentially suspicious commands...${NC}"
    
    # Network reconnaissance commands
    netstat -tlnp | head -5 >/dev/null 2>&1 || true
    ps aux | grep -E "(ssh|daemon)" | head -3 >/dev/null 2>&1 || true
    
    # System enumeration
    whoami >/dev/null 2>&1 || true
    id >/dev/null 2>&1 || true
    uname -a >/dev/null 2>&1 || true
    
    # File system probing
    find /etc -name "*.conf" -type f 2>/dev/null | head -5 >/dev/null || true
    
    wait_for_detection "System Commands" 25
    check_recent_alerts "system command execution"
    echo
}

comprehensive_alert_check() {
    echo -e "${SHIELD} ${PURPLE}COMPREHENSIVE ALERT ANALYSIS${NC}"
    echo "==============================="
    
    echo -e "${INFO} Analyzing all recent alerts and activity..."
    
    # Check manager alerts with timestamps
    echo -e "${CYAN}Manager Alert Summary:${NC}"
    docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime 0 -exec wc -l {} \; 2>/dev/null | awk '{sum+=$1} END {print "Total alert lines today: " sum}'
    
    # Recent alerts with context
    echo -e "${CYAN}Recent Manager Alerts (last 20 lines):${NC}"
    docker exec wazuh-manager tail -20 /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "No alerts available"
    
    echo
    echo -e "${CYAN}Agent Log Summary:${NC}"
    sudo tail -20 /var/ossec/logs/ossec.log | grep -E "($(date +'%Y/%m/%d')|$(date +'%b %d'))" || echo "No recent agent events"
    
    echo
    echo -e "${CYAN}System Journal Events (security-related):${NC}"
    journalctl --since "10 minutes ago" --no-pager | grep -iE "(security|sudo|ssh|fail|error|attack)" | tail -10 || echo "No security events in journal"
}

generate_final_report() {
    local report_file="/tmp/wazuh_attack_simulation_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo -e "${INFO} Generating comprehensive test report..."
    
    {
        echo "WAZUH AGENT ATTACK SIMULATION REPORT"
        echo "Generated: $(date)"
        echo "======================================"
        echo
        
        echo "1. AGENT STATUS"
        echo "---------------"
        sudo /var/ossec/bin/wazuh-control status
        echo
        
        echo "2. MANAGER STATUS"
        echo "-----------------"
        docker ps | grep wazuh || echo "Manager not running"
        echo
        
        echo "3. ALERT SUMMARY"
        echo "----------------"
        docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime 0 -exec wc -l {} \; 2>/dev/null | awk '{sum+=$1} END {print "Total alerts today: " sum}'
        echo
        
        echo "4. RECENT ALERTS"
        echo "----------------"
        docker exec wazuh-manager tail -30 /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "No alerts"
        echo
        
        echo "5. AGENT EVENTS"
        echo "---------------"
        sudo tail -30 /var/ossec/logs/ossec.log
        echo
        
        echo "6. RECOMMENDATIONS"
        echo "------------------"
        echo "- If no alerts were generated, consider:"
        echo "  * Adding auth.log monitoring"
        echo "  * Creating custom rules for network scans"
        echo "  * Enabling more verbose logging"
        echo "  * Adding firewall log monitoring"
        echo "- Tests that typically generate alerts:"
        echo "  * SSH failed logins"
        echo "  * Sudo commands (via journald)"
        echo "  * File modifications in /etc"
        echo "  * Multiple connection attempts"
        
    } > "$report_file"
    
    echo -e "${SUCCESS} Report saved to: $report_file"
    echo -e "${INFO} View with: less $report_file"
}

show_menu() {
    echo -e "${CYAN}Attack Simulation Test Menu:${NC}"
    echo "1. SSH Brute Force Attack"
    echo "2. Sudo Privilege Escalation"
    echo "3. File Integrity Monitoring"
    echo "4. Port Scan Detection"
    echo "5. Suspicious Process Activity"
    echo "6. Log Injection Attacks"
    echo "7. System Command Monitoring"
    echo "8. Run All Tests Sequentially"
    echo "9. Comprehensive Alert Analysis"
    echo "10. Generate Final Report"
    echo "0. Exit"
    echo
}

main() {
    print_header
    
    if [[ $# -eq 1 ]] && [[ $1 == "auto" ]]; then
        echo -e "${INFO} Running all tests automatically..."
        test_1_ssh_brute_force
        test_2_sudo_privilege_escalation
        test_3_file_integrity_monitoring
        test_4_port_scan_detection
        test_5_process_injection_simulation
        test_6_log_injection_attack
        test_7_system_command_monitoring
        comprehensive_alert_check
        generate_final_report
        return
    fi
    
    while true; do
        show_menu
        read -p "Choose a test (0-10): " choice
        echo
        
        case $choice in
            1) test_1_ssh_brute_force ;;
            2) test_2_sudo_privilege_escalation ;;
            3) test_3_file_integrity_monitoring ;;
            4) test_4_port_scan_detection ;;
            5) test_5_process_injection_simulation ;;
            6) test_6_log_injection_attack ;;
            7) test_7_system_command_monitoring ;;
            8) 
                echo -e "${INFO} Running all tests..."
                test_1_ssh_brute_force
                test_2_sudo_privilege_escalation
                test_3_file_integrity_monitoring
                test_4_port_scan_detection
                test_5_process_injection_simulation
                test_6_log_injection_attack
                test_7_system_command_monitoring
                ;;
            9) comprehensive_alert_check ;;
            10) generate_final_report ;;
            0) echo -e "${INFO} Exiting..."; exit 0 ;;
            *) echo -e "${ERROR} Invalid choice. Please try again." ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    command -v nmap >/dev/null || missing_deps+=("nmap")
    command -v nc >/dev/null || missing_deps+=("netcat")
    command -v sshpass >/dev/null || missing_deps+=("sshpass")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${WARNING} Missing dependencies: ${missing_deps[*]}"
        echo -e "${INFO} Install with: sudo apt install ${missing_deps[*]}"
        read -p "Continue anyway? (y/n): " continue_choice
        [[ $continue_choice =~ ^[Yy]$ ]] || exit 1
    fi
}

# Run dependency check
check_dependencies

# Start main program
main "$@"
