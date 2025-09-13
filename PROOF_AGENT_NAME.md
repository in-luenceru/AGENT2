# Proof: Agent Uses User-Specified Name

Date: 2025-09-13

This document records verifiable evidence that the monitoring agent uses the user-provided name `secure-agent-123` instead of the system hostname.

Collected evidence (commands and outputs):

1) Manager agent list

```
$ docker exec wazuh-manager /var/ossec/bin/agent_control -l
Wazuh agent_control. List of available agents:
   ID: 000, Name: 3a87144aa769 (server), IP: 127.0.0.1, Active/Local
   ID: 003, Name: secure-agent-123, IP: any, Active

List of agentless devices:
```

2) Detailed agent info

```
$ docker exec wazuh-manager /var/ossec/bin/agent_control -i 003
Wazuh agent_control. Agent information:
   Agent ID:   003
   Agent Name: secure-agent-123
   IP address: any
   Status:     Active

   Operating system:    Linux |codespaces-720563 |6.8.0-1030-azure |#35~22.04.1-Ubuntu SMP Mon May 26 18:08:30 UTC 202
5 |x86_64                                                                                                                Client version:      Wazuh v4.12.0
   Configuration hash:  ab73af41699f13fdd81903b5f23d8d00
   Shared file hash:    cb5dc59d195320bb20b6039a519a8c0e
   Last keep alive:     1757780406

   Syscheck last started at:  Sat Sep 13 16:14:49 2025
   Syscheck last ended at:    Sat Sep 13 16:19:34 2025
```

3) Recent Alerts that include the agent name

```
$ docker exec wazuh-manager tail -50 /var/ossec/logs/alerts/alerts.log | grep -E "\\(secure-agent-123\\)" -n -B 2 -A 3
** Alert 1757780416.5335371: - ossec,syscheck,syscheck_entry_modified,syscheck_file,... 2025 Sep 13 16:20:16 (secure-agent-123) any->syscheck
Rule: 550 (level 7) -> 'Integrity checksum changed.'
File '/home/codespace/.vscode-remote/data/User/workspaceStorage/-1d34c91b/vscode.lock' modified
Mode: realtime

** Alert 1757780417.5336298: - ossec,syscheck,syscheck_entry_modified,syscheck_file,... 2025 Sep 13 16:20:17 (secure-agent-123) any->syscheck
Rule: 550 (level 7) -> 'Integrity checksum changed.'
File '/home/codespace/.vscode-remote/data/User/workspaceStorage/-1d34c91b/vscode.lock' modified
Mode: realtime
```

4) Persistent identity file (shows AGENT_NAME)

```
$ sudo cat /workspaces/AGENT2/etc/agent.identity
# Wazuh Agent Identity File
# This file contains the persistent agent identity information
# WARNING: Do not edit manually unless you know what you're doing

# Agent Identity
AGENT_ID=""
AGENT_GROUP=""

# Registration Information  
REGISTRATION_DATE=""
MANAGER_IP=""

# Status
ENROLLMENT_STATUS="not_enrolled"

# Security Checksum (for tampering detection)
AGENT_NAME="secure-agent-123"
LAST_UPDATE="2025-09-13 15:44:50"
CHECKSUM="166c42bd564d49d25149b5b8916b2903406a8840cce31c435122d7feeb12eaf0"
```

5) Authentication keys file (`client.keys`) references the correct agent name

```
$ sudo cat /workspaces/AGENT2/etc/client.keys
003 secure-agent-123 any fda69896f233e441f30e2e51e1004cb2b061b5dfc02f42c88631e019b76ded42
```

---

Reproducible verification steps:

1) Start the agent with the `monitor-control` script:

```bash
sudo ./monitor-control start
```

2) On the manager host check the agent list:

```bash
docker exec wazuh-manager /var/ossec/bin/agent_control -l
```

3) Check a few recent alerts for the agent name:

```bash
docker exec wazuh-manager tail -50 /var/ossec/logs/alerts/alerts.log | grep "(secure-agent-123)" -n -B 2 -A 3
```

4) Inspect the persistent identity file and `client.keys` to confirm the saved agent name and key:

```bash
sudo cat /workspaces/AGENT2/etc/agent.identity
sudo cat /workspaces/AGENT2/etc/client.keys
```

Proof created by the monitoring agent support team at `AGENT2`.
