#!/bin/bash

# 🚀 WAZUH QUICK START SCRIPT
# This script provides quick commands for common Wazuh operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Icons
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
SHIELD="🛡️"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${PURPLE}${SHIELD} WAZUH AGENT QUICK OPERATIONS ${SHIELD}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
}

print_menu() {
    echo -e "${CYAN}Available Operations:${NC}"
    echo -e "${GREEN}1.${NC} ${ROCKET} Start/Stop/Restart Agent"
    echo -e "${GREEN}2.${NC} ${INFO} Check Agent Status"
    echo -e "${GREEN}3.${NC} ${SHIELD} Monitor Real-time Alerts"
    echo -e "${GREEN}4.${NC} 📋 View Recent Logs"
    echo -e "${GREEN}5.${NC} 🔍 Test Network Detection"
    echo -e "${GREEN}6.${NC} 📊 Generate System Report"
    echo -e "${GREEN}7.${NC} 🔧 Troubleshoot Issues"
    echo -e "${GREEN}8.${NC} 📖 View Documentation"
    echo -e "${GREEN}9.${NC} 🧹 Clean Old Logs"
    echo -e "${GREEN}0.${NC} 🚪 Exit"
    echo
}

start_stop_agent() {
    echo -e "${CYAN}Agent Control:${NC}"
    echo "1. Start Agent"
    echo "2. Stop Agent"
    echo "3. Restart Agent"
    echo "4. Back to main menu"
    read -p "Choose option: " choice
    
    case $choice in
        1)
            echo -e "${INFO} Starting Wazuh agent..."
            if sudo /var/ossec/bin/wazuh-control start; then
                echo -e "${SUCCESS} Agent started successfully"
            else
                echo -e "${ERROR} Failed to start agent"
            fi
            ;;
        2)
            echo -e "${INFO} Stopping Wazuh agent..."
            if sudo /var/ossec/bin/wazuh-control stop; then
                echo -e "${SUCCESS} Agent stopped successfully"
            else
                echo -e "${ERROR} Failed to stop agent"
            fi
            ;;
        3)
            echo -e "${INFO} Restarting Wazuh agent..."
            if sudo /var/ossec/bin/wazuh-control restart; then
                echo -e "${SUCCESS} Agent restarted successfully"
            else
                echo -e "${ERROR} Failed to restart agent"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${ERROR} Invalid option"
            ;;
    esac
}

check_status() {
    echo -e "${INFO} Checking Wazuh Agent Status..."
    echo -e "${BLUE}=====================================${NC}"
    
    # Agent status
    echo -e "${CYAN}Agent Modules Status:${NC}"
    sudo /var/ossec/bin/wazuh-control status
    
    echo
    
    # Manager status
    echo -e "${CYAN}Manager Status:${NC}"
    if docker ps | grep wazuh-manager > /dev/null; then
        echo -e "${SUCCESS} Manager container is running"
    else
        echo -e "${ERROR} Manager container is not running"
    fi
    
    echo
    
    # Network connectivity
    echo -e "${CYAN}Network Connectivity:${NC}"
    if timeout 5 telnet 127.0.0.1 1514 < /dev/null 2>/dev/null; then
        echo -e "${SUCCESS} Can connect to manager on port 1514"
    else
        echo -e "${ERROR} Cannot connect to manager on port 1514"
    fi
    
    echo
    
    # Disk usage
    echo -e "${CYAN}Disk Usage:${NC}"
    df -h /var/ossec/ 2>/dev/null || echo "Wazuh directory not found"
    
    echo
    
    # Recent activity
    echo -e "${CYAN}Recent Activity:${NC}"
    ALERT_COUNT=$(docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime -1 -exec wc -l {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
    echo "Alerts in last 24h: $ALERT_COUNT"
}

monitor_alerts() {
    echo -e "${INFO} Starting real-time alert monitoring..."
    echo -e "${WARNING} Press Ctrl+C to stop monitoring"
    echo -e "${BLUE}=====================================${NC}"
    
    # Start monitoring in background
    docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log &
    DOCKER_PID=$!
    
    # Monitor agent logs too
    sudo tail -f /var/ossec/logs/ossec.log &
    TAIL_PID=$!
    
    # Wait for user interrupt
    trap "kill $DOCKER_PID $TAIL_PID 2>/dev/null; echo -e '\n${INFO} Monitoring stopped.'; exit 0" INT
    wait
}

view_logs() {
    echo -e "${CYAN}Log Viewer:${NC}"
    echo "1. Agent logs (last 50 lines)"
    echo "2. Manager alerts (last 20 lines)"
    echo "3. Follow agent logs"
    echo "4. Follow manager alerts"
    echo "5. Search logs"
    echo "6. Back to main menu"
    read -p "Choose option: " choice
    
    case $choice in
        1)
            echo -e "${INFO} Agent logs (last 50 lines):"
            sudo tail -n 50 /var/ossec/logs/ossec.log
            ;;
        2)
            echo -e "${INFO} Manager alerts (last 20 lines):"
            docker exec wazuh-manager tail -n 20 /var/ossec/logs/alerts/alerts.log
            ;;
        3)
            echo -e "${INFO} Following agent logs (Ctrl+C to stop):"
            sudo tail -f /var/ossec/logs/ossec.log
            ;;
        4)
            echo -e "${INFO} Following manager alerts (Ctrl+C to stop):"
            docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log
            ;;
        5)
            read -p "Enter search term: " search_term
            echo -e "${INFO} Searching for: $search_term"
            echo "Agent logs:"
            sudo grep -i "$search_term" /var/ossec/logs/ossec.log | tail -10
            echo "Manager alerts:"
            docker exec wazuh-manager grep -i "$search_term" /var/ossec/logs/alerts/alerts.log | tail -10
            ;;
        6)
            return
            ;;
        *)
            echo -e "${ERROR} Invalid option"
            ;;
    esac
}

test_detection() {
    echo -e "${INFO} Testing Network Detection Capabilities..."
    echo -e "${BLUE}=====================================${NC}"
    
    # Test process monitoring
    echo -e "${CYAN}Test 1: Process Detection${NC}"
    echo "Starting Nmap scan (will be detected by process monitoring)..."
    nmap -sT -p 1-10 127.0.0.1 > /tmp/nmap_test.log 2>&1 &
    NMAP_PID=$!
    
    # Wait for process monitoring cycle
    echo "Waiting 35 seconds for process monitoring cycle..."
    sleep 35
    
    # Kill nmap if still running
    kill $NMAP_PID 2>/dev/null || true
    
    echo -e "${CYAN}Test 2: System Activity${NC}"
    echo "Generating system activity (will trigger alerts)..."
    sudo echo "Security test - $(date)" > /tmp/security_test_$(date +%s).log
    
    echo -e "${CYAN}Test 3: Custom Security Event${NC}"
    echo "Creating custom security event..."
    logger -p local0.warning "WAZUH_TEST: Security event generated at $(date)"
    
    echo
    echo -e "${INFO} Waiting 30 seconds for alert processing..."
    sleep 30
    
    echo -e "${CYAN}Recent alerts (may contain test results):${NC}"
    docker exec wazuh-manager tail -15 /var/ossec/logs/alerts/alerts.log | grep -E "($(date +'%b %d')|nmap|security|WAZUH_TEST)" || echo "No matching alerts found"
}

generate_report() {
    REPORT_FILE="/tmp/wazuh_report_$(date +%Y%m%d_%H%M%S).txt"
    
    echo -e "${INFO} Generating system report..."
    
    {
        echo "WAZUH SYSTEM REPORT"
        echo "Generated: $(date)"
        echo "==============================================="
        echo
        
        echo "1. SYSTEM INFORMATION"
        echo "---------------------"
        uname -a
        uptime
        echo
        
        echo "2. AGENT STATUS"
        echo "---------------"
        sudo /var/ossec/bin/wazuh-control status
        echo
        
        echo "3. MANAGER STATUS"
        echo "-----------------"
        docker ps | grep wazuh || echo "No manager container found"
        echo
        
        echo "4. NETWORK CONNECTIVITY"
        echo "----------------------"
        netstat -tlnp | grep -E "(1514|1515)" || echo "Wazuh ports not found"
        echo
        
        echo "5. DISK USAGE"
        echo "-------------"
        df -h /var/ossec/ 2>/dev/null || echo "Wazuh directory not found"
        echo
        
        echo "6. RECENT ALERTS (Last 10)"
        echo "--------------------------"
        docker exec wazuh-manager tail -n 10 /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "Could not retrieve alerts"
        echo
        
        echo "7. AGENT LOGS (Last 10 lines)"
        echo "------------------------------"
        sudo tail -n 10 /var/ossec/logs/ossec.log 2>/dev/null || echo "Could not retrieve agent logs"
        echo
        
        echo "8. CONFIGURATION SUMMARY"
        echo "------------------------"
        sudo grep -A 5 "<server>" /var/ossec/etc/ossec.conf 2>/dev/null || echo "Could not read configuration"
        
    } > "$REPORT_FILE"
    
    echo -e "${SUCCESS} Report generated: $REPORT_FILE"
    echo -e "${INFO} Would you like to view it? (y/n)"
    read -p "> " view_choice
    
    if [[ $view_choice =~ ^[Yy]$ ]]; then
        less "$REPORT_FILE"
    fi
}

troubleshoot() {
    echo -e "${INFO} Running troubleshooting diagnostics..."
    echo -e "${BLUE}=====================================${NC}"
    
    # Check 1: Agent processes
    echo -e "${CYAN}1. Checking Agent Processes:${NC}"
    if pgrep -f wazuh-agentd > /dev/null; then
        echo -e "${SUCCESS} wazuh-agentd is running"
    else
        echo -e "${ERROR} wazuh-agentd is not running"
    fi
    
    # Check 2: Manager container
    echo -e "${CYAN}2. Checking Manager Container:${NC}"
    if docker ps | grep wazuh-manager > /dev/null; then
        echo -e "${SUCCESS} Manager container is running"
    else
        echo -e "${ERROR} Manager container is not running"
        echo -e "${INFO} Try: docker start wazuh-manager"
    fi
    
    # Check 3: Network connectivity
    echo -e "${CYAN}3. Checking Network Connectivity:${NC}"
    if timeout 5 bash -c "</dev/tcp/127.0.0.1/1514" 2>/dev/null; then
        echo -e "${SUCCESS} Port 1514 is reachable"
    else
        echo -e "${ERROR} Cannot connect to port 1514"
        echo -e "${INFO} Check if manager is running and ports are open"
    fi
    
    # Check 4: Configuration
    echo -e "${CYAN}4. Checking Configuration:${NC}"
    if sudo grep -q "127.0.0.1" /var/ossec/etc/ossec.conf; then
        echo -e "${SUCCESS} Manager IP configured correctly"
    else
        echo -e "${ERROR} Manager IP might not be configured"
    fi
    
    # Check 5: Client keys
    echo -e "${CYAN}5. Checking Client Keys:${NC}"
    if [[ -f /var/ossec/etc/client.keys ]] && [[ -s /var/ossec/etc/client.keys ]]; then
        echo -e "${SUCCESS} Client keys file exists and is not empty"
    else
        echo -e "${ERROR} Client keys file is missing or empty"
    fi
    
    # Check 6: Logs
    echo -e "${CYAN}6. Checking Recent Errors:${NC}"
    ERROR_COUNT=$(sudo grep -i "error\|fail" /var/ossec/logs/ossec.log | tail -5 | wc -l)
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${SUCCESS} No recent errors in agent logs"
    else
        echo -e "${WARNING} Found $ERROR_COUNT recent errors:"
        sudo grep -i "error\|fail" /var/ossec/logs/ossec.log | tail -3
    fi
    
    echo
    echo -e "${INFO} Common troubleshooting steps:"
    echo "1. Restart agent: sudo /var/ossec/bin/wazuh-control restart"
    echo "2. Restart manager: docker restart wazuh-manager"
    echo "3. Check full logs: sudo tail -50 /var/ossec/logs/ossec.log"
    echo "4. Verify keys match on both agent and manager"
}

view_documentation() {
    echo -e "${INFO} Opening documentation..."
    
    DOC_PATH="/home/anandhu/AGENT/docs/COMPLETE_USAGE_DOCUMENTATION.md"
    if [[ -f "$DOC_PATH" ]]; then
        less "$DOC_PATH"
    else
    echo -e "${ERROR} Documentation file not found"
    echo -e "${INFO} Documentation should be at: $DOC_PATH"
    fi
}

clean_logs() {
    echo -e "${WARNING} This will clean old log files. Continue? (y/n)"
    read -p "> " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${INFO} Cleaning old logs..."
        
        # Clean agent logs older than 7 days
        sudo find /var/ossec/logs -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
        
        # Clean temporary files
        sudo find /tmp -name "wazuh_*" -mtime +1 -delete 2>/dev/null || true
        sudo find /tmp -name "nmap_*" -mtime +1 -delete 2>/dev/null || true
        
        echo -e "${SUCCESS} Log cleanup completed"
    else
        echo -e "${INFO} Log cleanup cancelled"
    fi
}

# Main menu loop
main() {
    while true; do
        clear
        print_header
        print_menu
        
        read -p "Choose an option (0-9): " choice
        echo
        
        case $choice in
            1)
                start_stop_agent
                ;;
            2)
                check_status
                ;;
            3)
                monitor_alerts
                ;;
            4)
                view_logs
                ;;
            5)
                test_detection
                ;;
            6)
                generate_report
                ;;
            7)
                troubleshoot
                ;;
            8)
                view_documentation
                ;;
            9)
                clean_logs
                ;;
            0)
                echo -e "${INFO} Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${ERROR} Invalid option. Please choose 0-9."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Check if running as root for some operations
if [[ $EUID -eq 0 ]]; then
    echo -e "${WARNING} Running as root. Some operations may behave differently."
fi

# Start main program
main
