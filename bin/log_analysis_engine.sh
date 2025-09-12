#!/bin/bash
# Log Analysis Engine
# Processes and analyzes log files for security events

LOG_FILE="$1"
if [ -z "$LOG_FILE" ]; then
    echo "Usage: $0 <log_file>"
    exit 1
fi

# Process the log file
if [ -f "$LOG_FILE" ]; then
    # Simple log analysis for demonstration
    grep -E "(Failed|failed|ERROR|error|WARN|warn)" "$LOG_FILE" 2>/dev/null
    exit 0
else
    exit 1
fi