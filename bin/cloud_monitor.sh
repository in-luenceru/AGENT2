#!/bin/bash

# Cloud Integration Monitor
# Simulates and monitors cloud events from AWS, Azure, GCP, and Docker

AGENT_DIR="/workspaces/AGENT2"
LOGS_DIR="$AGENT_DIR/logs"
CLOUD_CONFIG_DIR="$AGENT_DIR/etc/shared/cloud"

# UUID generation function (fallback for systems without uuidgen)
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        # Generate UUID-like string using /dev/urandom
        printf "%08x-%04x-%04x-%04x-%012x" \
            $((0x$(head -c4 /dev/urandom | xxd -p))) \
            $((0x$(head -c2 /dev/urandom | xxd -p))) \
            $((0x$(head -c2 /dev/urandom | xxd -p) | 0x4000 & 0x4FFF)) \
            $((0x$(head -c2 /dev/urandom | xxd -p) | 0x8000 & 0xBFFF)) \
            $((0x$(head -c6 /dev/urandom | xxd -p)))
    fi
}

# Ensure log directory exists
mkdir -p "$LOGS_DIR"

# Function to generate AWS CloudTrail events
generate_aws_cloudtrail_events() {
    local timestamp=$(date -Iseconds)
    local event_types=("AssumeRole" "CreateUser" "DeleteUser" "ConsoleLogin" "CreateBucket" "DeleteBucket" "CreateInstance" "TerminateInstance")
    local sources=("console.aws.amazon.com" "signin.aws.amazon.com" "s3.amazonaws.com" "ec2.amazonaws.com")
    local users=("admin@company.com" "developer@company.com" "service-account" "root")
    
    for i in {1..5}; do
        local event_type=${event_types[$RANDOM % ${#event_types[@]}]}
        local source=${sources[$RANDOM % ${#sources[@]}]}
        local user=${users[$RANDOM % ${#users[@]}]}
        local success=$((RANDOM % 100 < 90)) # 90% success rate
        
        cat << EOF >> "$LOGS_DIR/aws_cloudtrail.log"
{
  "timestamp": "$timestamp",
  "eventVersion": "1.05",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDACKCEVSQ6C2EXAMPLE",
    "arn": "arn:aws:iam::123456789012:user/$user",
    "accountId": "123456789012",
    "userName": "$user"
  },
  "eventTime": "$timestamp",
  "eventSource": "$source",
  "eventName": "$event_type",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "$(printf "%d.%d.%d.%d" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))",
  "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "errorCode": "$([ $success -eq 1 ] && echo "" || echo "AccessDenied")",
  "errorMessage": "$([ $success -eq 1 ] && echo "" || echo "User is not authorized to perform: $event_type")",
  "responseElements": null,
  "requestID": "$(generate_uuid)",
  "eventID": "$(generate_uuid)",
  "eventType": "AwsApiCall",
  "recipientAccountId": "123456789012",
  "serviceEventDetails": null,
  "sharedEventID": null
}
EOF
    done
}

# Function to generate Azure activity logs
generate_azure_activity_logs() {
    local timestamp=$(date -Iseconds)
    local operations=("Microsoft.Authorization/roleAssignments/write" "Microsoft.Compute/virtualMachines/start/action" "Microsoft.Storage/storageAccounts/delete" "Microsoft.Network/networkSecurityGroups/write")
    local levels=("Informational" "Warning" "Error" "Critical")
    local callers=("admin@company.onmicrosoft.com" "service@company.onmicrosoft.com" "developer@company.onmicrosoft.com")
    
    for i in {1..3}; do
        local operation=${operations[$RANDOM % ${#operations[@]}]}
        local level=${levels[$RANDOM % ${#levels[@]}]}
        local caller=${callers[$RANDOM % ${#callers[@]}]}
        
        cat << EOF >> "$LOGS_DIR/azure_activity.log"
{
  "timestamp": "$timestamp",
  "operationId": "$(generate_uuid)",
  "operationName": "$operation",
  "category": "Administrative",
  "resultType": "$([ "$level" = "Error" ] && echo "Failed" || echo "Success")",
  "resultSignature": "$([ "$level" = "Error" ] && echo "Forbidden" || echo "OK")",
  "durationMs": $((RANDOM % 5000 + 100)),
  "callerIpAddress": "$(printf "%d.%d.%d.%d" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))",
  "correlationId": "$(generate_uuid)",
  "identity": {
    "authorization": {
      "scope": "/subscriptions/demo-subscription-id/resourceGroups/demo-rg",
      "action": "$operation",
      "evidence": {
        "role": "Contributor",
        "roleAssignmentScope": "/subscriptions/demo-subscription-id",
        "roleAssignmentId": "$(generate_uuid)",
        "roleDefinitionId": "$(generate_uuid)",
        "principalId": "$(generate_uuid)",
        "principalType": "User"
      }
    },
    "claims": {
      "name": "$caller",
      "upn": "$caller"
    }
  },
  "level": "$level",
  "location": "East US",
  "properties": {
    "requestbody": "",
    "statusCode": "$([ "$level" = "Error" ] && echo "403" || echo "200")"
  }
}
EOF
    done
}

# Function to generate GCP audit logs
generate_gcp_audit_logs() {
    local timestamp=$(date -Iseconds)
    local services=("compute.googleapis.com" "storage.googleapis.com" "iam.googleapis.com" "cloudkms.googleapis.com")
    local methods=("compute.instances.insert" "storage.buckets.create" "iam.serviceAccounts.create" "cloudkms.keyRings.create")
    local principals=("user:admin@company.com" "serviceAccount:service@demo-project.iam.gserviceaccount.com" "user:developer@company.com")
    
    for i in {1..4}; do
        local service=${services[$RANDOM % ${#services[@]}]}
        local method=${methods[$RANDOM % ${#methods[@]}]}
        local principal=${principals[$RANDOM % ${#principals[@]}]}
        
        cat << EOF >> "$LOGS_DIR/gcp_audit.log"
{
  "timestamp": "$timestamp",
  "severity": "INFO",
  "logName": "projects/demo-gcp-project/logs/cloudaudit.googleapis.com%2Factivity",
  "operation": {
    "id": "operation-$(date +%s)",
    "producer": "$service",
    "first": true,
    "last": true
  },
  "protoPayload": {
    "@type": "type.googleapis.com/google.cloud.audit.AuditLog",
    "status": {},
    "authenticationInfo": {
      "principalEmail": "${principal#*:}"
    },
    "requestMetadata": {
      "callerIp": "$(printf "%d.%d.%d.%d" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))",
      "callerSuppliedUserAgent": "gcloud/$(printf "%d.%d.%d" $((RANDOM%10)) $((RANDOM%10)) $((RANDOM%10)))",
      "requestAttributes": {},
      "destinationAttributes": {}
    },
    "serviceName": "$service",
    "methodName": "$method",
    "authorizationInfo": [
      {
        "resource": "projects/demo-gcp-project",
        "permission": "${method%.*}.create",
        "granted": true,
        "resourceAttributes": {}
      }
    ],
    "resourceName": "projects/demo-gcp-project",
    "request": {
      "@type": "type.googleapis.com/google.cloud.compute.v1.InsertInstanceRequest"
    }
  },
  "insertId": "$(generate_uuid)",
  "resource": {
    "type": "gce_instance",
    "labels": {
      "instance_id": "$(printf "%d" $RANDOM)",
      "project_id": "demo-gcp-project",
      "zone": "us-central1-a"
    }
  }
}
EOF
    done
}

# Function to generate Docker events
generate_docker_events() {
    local timestamp=$(date -Iseconds)
    local actions=("create" "start" "stop" "destroy" "pull" "push")
    local images=("nginx:latest" "redis:alpine" "postgres:13" "node:16-alpine" "python:3.9")
    local containers=("web-server" "cache-server" "database" "api-service" "worker")
    
    for i in {1..3}; do
        local action=${actions[$RANDOM % ${#actions[@]}]}
        local image=${images[$RANDOM % ${#images[@]}]}
        local container=${containers[$RANDOM % ${#containers[@]}]}
        
        cat << EOF >> "$LOGS_DIR/docker_events.log"
{
  "timestamp": "$timestamp",
  "status": "$action",
  "id": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 12))",
  "from": "$image",
  "Type": "container",
  "Action": "$action",
  "Actor": {
    "ID": "$(printf "%s" $(head /dev/urandom | tr -dc a-f0-9 | head -c 64))",
    "Attributes": {
      "container": "$container",
      "image": "$image",
      "name": "$container"
    }
  },
  "scope": "local",
  "time": $(date +%s),
  "timeNano": $(date +%s%N)
}
EOF
    done
}

# Function to generate cloud security events
generate_cloud_security_events() {
    local timestamp=$(date -Iseconds)
    local event_types=("SUSPICIOUS_LOGIN" "PRIVILEGE_ESCALATION" "DATA_EXFILTRATION" "MALWARE_DETECTED" "POLICY_VIOLATION")
    local severities=("HIGH" "MEDIUM" "LOW" "CRITICAL")
    local clouds=("AWS" "Azure" "GCP")
    
    # Generate random security events
    if [ $((RANDOM % 100)) -lt 20 ]; then  # 20% chance of security event
        local event_type=${event_types[$RANDOM % ${#event_types[@]}]}
        local severity=${severities[$RANDOM % ${#severities[@]}]}
        local cloud=${clouds[$RANDOM % ${#clouds[@]}]}
        
        # Ensure the file is initialized
        touch "$LOGS_DIR/cloud_security_events.log"
        
        cat << EOF >> "$LOGS_DIR/cloud_security_events.log"
{
  "timestamp": "$timestamp",
  "event_type": "$event_type",
  "severity": "$severity",
  "cloud_provider": "$cloud",
  "source_ip": "$(printf "%d.%d.%d.%d" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))",
  "user_agent": "$([ $((RANDOM % 2)) -eq 0 ] && echo "Suspicious-Scanner/1.0" || echo "Mozilla/5.0 (compatible)")",
  "description": "Detected $event_type activity from suspicious source",
  "affected_resource": "$([ "$cloud" = "AWS" ] && echo "arn:aws:s3:::sensitive-data-bucket" || [ "$cloud" = "Azure" ] && echo "/subscriptions/demo/resourceGroups/prod" || echo "projects/demo-project/instances/web-server")",
  "risk_score": $((RANDOM % 100 + 1)),
  "tags": ["security", "cloud", "$(echo $event_type | tr '[:upper:]' '[:lower:]')"],
  "remediation": "Review access logs and revoke suspicious sessions"
}
EOF
    else
        # Ensure file exists even if no events generated
        touch "$LOGS_DIR/cloud_security_events.log"
    fi
}

# Function to check cloud wodle configurations
validate_cloud_configs() {
    echo "=== Cloud Configuration Validation ==="
    
    # Check wodle configurations
    local aws_wodles=$(grep -c "wodle.*aws" etc/ossec.conf)
    local azure_wodles=$(grep -c "wodle.*azure" etc/ossec.conf)
    local gcp_wodles=$(grep -c "wodle.*gcp" etc/ossec.conf)
    local docker_wodles=$(grep -c "wodle.*docker" etc/ossec.conf)
    
    echo "Configured Cloud Wodles:"
    echo "  AWS: $aws_wodles wodles"
    echo "  Azure: $azure_wodles wodles" 
    echo "  GCP: $gcp_wodles wodles"
    echo "  Docker: $docker_wodles wodles"
    
    # Check credential files
    echo ""
    echo "Credential Files:"
    [ -f "etc/shared/aws_credentials" ] && echo "  ✅ AWS credentials configured" || echo "  ❌ AWS credentials missing"
    [ -f "etc/shared/azure_auth.json" ] && echo "  ✅ Azure credentials configured" || echo "  ❌ Azure credentials missing"
    [ -f "etc/shared/gcp_credentials.json" ] && echo "  ✅ GCP credentials configured" || echo "  ❌ GCP credentials missing"
    
    # Check wodles directory
    echo ""
    echo "Wodles Integration:"
    [ -d "wodles/aws" ] && echo "  ✅ AWS wodles available" || echo "  ❌ AWS wodles missing"
    [ -d "wodles/azure" ] && echo "  ✅ Azure wodles available" || echo "  ❌ Azure wodles missing"
    [ -d "wodles/gcloud" ] && echo "  ✅ GCP wodles available" || echo "  ❌ GCP wodles missing"
    [ -d "wodles/docker-listener" ] && echo "  ✅ Docker wodles available" || echo "  ❌ Docker wodles missing"
}

# Main execution
echo "=== Cloud Integration Monitor Started ==="
echo "Generating cloud events and monitoring integrations..."

# Generate events
generate_aws_cloudtrail_events
generate_azure_activity_logs  
generate_gcp_audit_logs
generate_docker_events
generate_cloud_security_events

# Validate configurations
validate_cloud_configs

# Count generated events
AWS_EVENTS=$(wc -l < "$LOGS_DIR/aws_cloudtrail.log" 2>/dev/null || echo "0")
AZURE_EVENTS=$(wc -l < "$LOGS_DIR/azure_activity.log" 2>/dev/null || echo "0")
GCP_EVENTS=$(wc -l < "$LOGS_DIR/gcp_audit.log" 2>/dev/null || echo "0")
DOCKER_EVENTS=$(wc -l < "$LOGS_DIR/docker_events.log" 2>/dev/null || echo "0")
SECURITY_EVENTS=$(wc -l < "$LOGS_DIR/cloud_security_events.log" 2>/dev/null || echo "0")

echo ""
echo "=== Event Generation Summary ==="
echo "AWS CloudTrail events: $AWS_EVENTS"
echo "Azure Activity events: $AZURE_EVENTS"
echo "GCP Audit events: $GCP_EVENTS"  
echo "Docker events: $DOCKER_EVENTS"
echo "Security events: $SECURITY_EVENTS"
echo ""
echo "Cloud monitoring cycle completed at: $(date)"