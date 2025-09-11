#!/bin/bash

# 📋 WAZUH CHEAT SHEET - Quick Reference Commands

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           🛡️  WAZUH CHEAT SHEET 🛡️                            ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🚀 AGENT OPERATIONS                                                         │
└─────────────────────────────────────────────────────────────────────────────┘

Start Agent:          sudo /var/ossec/bin/wazuh-control start
Stop Agent:           sudo /var/ossec/bin/wazuh-control stop
Restart Agent:        sudo /var/ossec/bin/wazuh-control restart
Check Status:         sudo /var/ossec/bin/wazuh-control status
Agent Info:           sudo /var/ossec/bin/wazuh-control info

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🐳 DOCKER MANAGER OPERATIONS                                               │
└─────────────────────────────────────────────────────────────────────────────┘

Start Manager:        docker start wazuh-manager
Stop Manager:         docker stop wazuh-manager
Restart Manager:      docker restart wazuh-manager
Manager Logs:         docker logs wazuh-manager
Follow Logs:          docker logs -f wazuh-manager
Manager Shell:        docker exec -it wazuh-manager bash

Create Manager:       docker run -d --name wazuh-manager \
                        -p 1514:1514 -p 1515:1515 -p 55000:55000 \
                        wazuh/wazuh-manager:4.12.0

┌─────────────────────────────────────────────────────────────────────────────┐
│ 👥 AGENT MANAGEMENT                                                         │
└─────────────────────────────────────────────────────────────────────────────┘

List Agents:          docker exec wazuh-manager bash -c "echo -e 'L\nQ' | /var/ossec/bin/manage_agents"

Add Agent:            docker exec -it wazuh-manager bash -c "echo -e 'A\nNAME\nIP\ny\nQ' | /var/ossec/bin/manage_agents"

Extract Key:          docker exec -it wazuh-manager bash -c "echo -e 'E\nID\nQ' | /var/ossec/bin/manage_agents"

Remove Agent:         docker exec -it wazuh-manager bash -c "echo -e 'R\nID\ny\nQ' | /var/ossec/bin/manage_agents"

Install Key:          echo "ID NAME IP KEY" | sudo tee /var/ossec/etc/client.keys

┌─────────────────────────────────────────────────────────────────────────────┐
│ 📋 LOG ANALYSIS                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Agent Logs:           sudo tail -f /var/ossec/logs/ossec.log
Manager Alerts:       docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.log
JSON Alerts:          docker exec wazuh-manager tail -f /var/ossec/logs/alerts/alerts.json
Search Logs:          sudo grep -i "SEARCH_TERM" /var/ossec/logs/ossec.log
Search Alerts:        docker exec wazuh-manager grep -i "SEARCH_TERM" /var/ossec/logs/alerts/alerts.log
Recent Errors:        sudo grep -i "error\|fail" /var/ossec/logs/ossec.log | tail -10

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🔧 CONFIGURATION                                                            │
└─────────────────────────────────────────────────────────────────────────────┘

Main Config:          /var/ossec/etc/ossec.conf
Client Keys:          /var/ossec/etc/client.keys
Local Rules:          /var/ossec/etc/local_rules.xml
Agent Logs Dir:       /var/ossec/logs/
Manager Config:       docker exec wazuh-manager cat /var/ossec/etc/ossec.conf

Edit Config:          sudo nano /var/ossec/etc/ossec.conf
Backup Config:        sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.backup
Validate Config:      sudo /var/ossec/bin/verify-agent-conf

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🔍 MONITORING & TESTING                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Test Connection:      telnet 127.0.0.1 1514
Check Ports:          netstat -tlnp | grep -E "(1514|1515)"
Process Monitor:      ps aux | grep -E "(wazuh|ossec)" | grep -v grep
Network Status:       sudo netstat -tlnp | head -20
Disk Usage:           df -h /var/ossec/
Test Alert:           logger "TEST: Wazuh security event"

Security Scan Test:   nmap -sT -p 1-10 127.0.0.1
Process Detection:    ps aux | grep nmap | grep -v grep

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🚨 TROUBLESHOOTING                                                          │
└─────────────────────────────────────────────────────────────────────────────┘

Connection Issues:
  1. Check manager:   docker ps | grep wazuh
  2. Test port:      telnet 127.0.0.1 1514
  3. Check config:   grep -A 5 "<server>" /var/ossec/etc/ossec.conf
  4. Verify keys:    cat /var/ossec/etc/client.keys

No Alerts:
  1. Check modules:  sudo /var/ossec/bin/wazuh-control status
  2. Test event:     logger "TEST: Security event"
  3. Check rules:    docker exec wazuh-manager ls /var/ossec/ruleset/rules/
  4. View raw logs:  sudo tail -50 /var/ossec/logs/ossec.log

High CPU:
  1. Check frequency: grep -i frequency /var/ossec/etc/ossec.conf
  2. Reduce scans:   Edit frequency values in ossec.conf
  3. Check processes: top -p $(pgrep -f wazuh)

Disk Full:
  1. Clean logs:     sudo find /var/ossec/logs -name "*.log.*" -mtime +7 -delete
  2. Archive alerts: docker exec wazuh-manager tar -czf /tmp/old-alerts.tar.gz /var/ossec/logs/alerts/
  3. Log rotation:   Configure logrotate for /var/ossec/logs/

┌─────────────────────────────────────────────────────────────────────────────┐
│ 📊 USEFUL ONE-LINERS                                                        │
└─────────────────────────────────────────────────────────────────────────────┘

Alert Count Today:    docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime -1 -exec wc -l {} \; | awk '{sum+=$1} END {print sum}'

Top Alert Rules:      docker exec wazuh-manager grep "Rule:" /var/ossec/logs/alerts/alerts.log | awk '{print $3}' | sort | uniq -c | sort -nr | head -10

Agent Uptime:         ps -o etime -p $(pgrep wazuh-agentd) | tail -1

Connection Test:      timeout 5 bash -c '</dev/tcp/127.0.0.1/1514' && echo "Connected" || echo "Failed"

Config Check:         sudo /var/ossec/bin/wazuh-control configcheck

Recent Failures:      sudo grep -i "fail\|error" /var/ossec/logs/ossec.log | tail -5

Active Connections:   netstat -an | grep :1514

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🔐 SECURITY TESTING                                                         │
└─────────────────────────────────────────────────────────────────────────────┘

Nmap Scan:            nmap -sT -p 1-100 127.0.0.1
SSH Scan:             nmap -sT -p 22 127.0.0.1
Service Scan:         nmap -sV -p 1514,5431,55000 127.0.0.1
UDP Scan:             nmap -sU -p 1514 127.0.0.1

Process Trigger:      nmap -sT -p 1-10 127.0.0.1 &
Custom Alert:         echo "$(date): SECURITY_EVENT - Test alert" | sudo tee -a /var/log/security_test.log
Brute Force Sim:      for i in {1..5}; do ssh nonuser@127.0.0.1; done

┌─────────────────────────────────────────────────────────────────────────────┐
│ 📝 CUSTOM RULES EXAMPLE                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Create Custom Rule File: /var/ossec/etc/local_rules.xml

<group name="local,syslog,">
  <rule id="100001" level="7">
    <if_group>command</if_group>
    <match>nmap|masscan</match>
    <description>Network scanning tool detected</description>
    <group>recon,</group>
  </rule>
</group>

┌─────────────────────────────────────────────────────────────────────────────┐
│ 📞 EMERGENCY PROCEDURES                                                     │
└─────────────────────────────────────────────────────────────────────────────┘

Agent Not Responding:
  sudo pkill -f wazuh
  sudo /var/ossec/bin/wazuh-control start

Manager Down:
  docker restart wazuh-manager
  docker logs wazuh-manager

Complete Reset:
  sudo /var/ossec/bin/wazuh-control stop
  docker stop wazuh-manager
  docker start wazuh-manager
  sudo /var/ossec/bin/wazuh-control start

Backup Everything:
  sudo tar -czf wazuh-backup-$(date +%Y%m%d).tar.gz /var/ossec/etc/
  docker exec wazuh-manager tar -czf /tmp/manager-backup.tar.gz /var/ossec/

┌─────────────────────────────────────────────────────────────────────────────┐
│ 🎯 QUICK HEALTH CHECK                                                       │
└─────────────────────────────────────────────────────────────────────────────┘

#!/bin/bash
echo "=== WAZUH HEALTH CHECK ==="
echo "Agent Status: $(sudo /var/ossec/bin/wazuh-control status | grep -c 'is running')/5 modules running"
echo "Manager Status: $(docker ps | grep wazuh-manager > /dev/null && echo "Running" || echo "Stopped")"
echo "Connectivity: $(timeout 3 bash -c '</dev/tcp/127.0.0.1/1514' 2>/dev/null && echo "OK" || echo "FAILED")"
echo "Recent Alerts: $(docker exec wazuh-manager find /var/ossec/logs/alerts -name "*.log" -mtime -1 -exec wc -l {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}')"
echo "Disk Usage: $(df -h /var/ossec | awk 'NR==2 {print $5}')"

╔═══════════════════════════════════════════════════════════════════════════════╗
║  💡 TIP: Save this as wazuh_cheat_sheet.txt for quick reference              ║
║  📖 Full documentation: docs/COMPLETE_USAGE_DOCUMENTATION.md                ║
║  🚀 Quick operations:   ./wazuh_quick_operations.sh                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝

EOF
