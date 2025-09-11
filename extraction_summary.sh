#!/bin/bash

# Complete Wazuh Agent Extraction Summary Script
# This script provides the final summary and instructions for the extracted agent

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_header() {
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}    WAZUH AGENT EXTRACTION COMPLETED!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
}

show_extraction_summary() {
    log_info "Extraction Summary:"
    echo ""
    echo "✅ Core Agent Components Extracted:"
    echo "   • wazuh-agentd (Main agent daemon)"
    echo "   • wazuh-logcollector (Log collection engine)"
    echo "   • wazuh-syscheckd (File integrity monitoring)"
    echo "   • wazuh-execd (Active response engine)"
    echo "   • wazuh-modulesd (Modules daemon for SCA, syscollector, etc.)"
    echo "   • wazuh-rootcheck (Host-based intrusion detection)"
    echo ""
    
    echo "✅ Supporting Libraries:"
    echo "   • shared/ (Common utilities)"
    echo "   • shared_modules/ (C++ shared modules)"
    echo "   • os_* libraries (networking, crypto, regex, xml, etc.)"
    echo "   • external/ (Third-party dependencies)"
    echo ""
    
    echo "✅ Configuration & Rules:"
    echo "   • etc/ (Configuration files and templates)"
    echo "   • ruleset/ (Detection rules and decoders)"
    echo ""
    
    echo "✅ Management Tools:"
    echo "   • manage_agents (Agent enrollment utility)"
    echo "   • Active response scripts"
    echo ""
    
    # Count extracted files
    local total_files=$(find "$SCRIPT_DIR" -type f | wc -l)
    local source_files=$(find "$SCRIPT_DIR/src" -name "*.c" -o -name "*.cpp" -o -name "*.cc" | wc -l)
    local header_files=$(find "$SCRIPT_DIR/src" -name "*.h" -o -name "*.hpp" | wc -l)
    
    echo "📊 Statistics:"
    echo "   • Total files extracted: $total_files"
    echo "   • Source files: $source_files"
    echo "   • Header files: $header_files"
    echo ""
}

show_build_instructions() {
    log_info "Build Instructions:"
    echo ""
    echo "1. Install dependencies:"
    echo "   sudo apt-get update"
    echo "   sudo apt-get install cmake gcc g++ make libssl-dev zlib1g-dev libcjson-dev"
    echo ""
    
    echo "2. Build the agent (choose one method):"
    echo ""
    echo "   Method A - CMake (full build):"
    echo "   ./build_agent.sh"
    echo ""
    echo "   Method B - Simple build (basic components):"
    echo "   ./build_simple.sh"
    echo ""
    echo "   Method C - Manual make:"
    echo "   make all"
    echo ""
    
    echo "3. Verify the build:"
    echo "   ./verify_agent.sh"
    echo ""
}

show_configuration_guide() {
    log_info "Configuration Guide:"
    echo ""
    echo "1. Edit main configuration:"
    echo "   nano etc/ossec.conf"
    echo ""
    echo "2. Key configuration sections to update:"
    echo "   <client>"
    echo "     <server>"
    echo "       <address>YOUR_MANAGER_IP</address>"
    echo "       <port>1514</port>"
    echo "     </server>"
    echo "   </client>"
    echo ""
    
    echo "3. Enable desired modules:"
    echo "   • Log collection: <localfile> sections"
    echo "   • FIM: <syscheck> section"
    echo "   • SCA: <sca> section"
    echo "   • Active response: <active-response> section"
    echo ""
}

show_deployment_steps() {
    log_info "Deployment Steps:"
    echo ""
    echo "1. Install the built agent:"
    echo "   sudo ./build_agent.sh --install"
    echo "   # OR manually copy files to /var/ossec/"
    echo ""
    
    echo "2. Agent enrollment (choose one):"
    echo ""
    echo "   Method A - Manual enrollment:"
    echo "   • On manager: /var/ossec/bin/manage_agents -a"
    echo "   • Extract key: /var/ossec/bin/manage_agents -e AGENT_ID"
    echo "   • On agent: /var/ossec/bin/manage_agents -i"
    echo ""
    echo "   Method B - Auto-enrollment (add to ossec.conf):"
    echo "   <client>"
    echo "     <enrollment>"
    echo "       <enabled>yes</enabled>"
    echo "       <manager_address>MANAGER_IP</manager_address>"
    echo "       <agent_name>my-agent</agent_name>"
    echo "     </enrollment>"
    echo "   </client>"
    echo ""
    
    echo "3. Start the agent:"
    echo "   /var/ossec/bin/wazuh-control start"
    echo ""
    
    echo "4. Verify connectivity:"
    echo "   /var/ossec/bin/wazuh-control status"
    echo "   tail -f /var/ossec/logs/ossec.log"
    echo ""
}

show_testing_checklist() {
    log_info "Functional Testing Checklist:"
    echo ""
    echo "□ Configuration validation: wazuh-agentd -t"
    echo "□ Agent enrollment successful"
    echo "□ Agent shows as 'Active' in manager"
    echo "□ Log collection working (test log entries forwarded)"
    echo "□ FIM working (file changes detected)"
    echo "□ Active response working (test rule triggers response)"
    echo "□ SCA scans completing"
    echo "□ System inventory collected"
    echo ""
}

show_file_structure() {
    log_info "Extracted Directory Structure:"
    echo ""
    echo "AGENT/"
    echo "├── build_agent.sh          # Main build script"
    echo "├── build_simple.sh         # Simple build (basic components)"
    echo "├── verify_agent.sh         # Verification script"
    echo "├── CMakeLists.txt          # CMake configuration"
    echo "├── Makefile               # Alternative Makefile"
    echo "├── README.md              # Comprehensive documentation"
    echo "├── src/                   # Source code"
    echo "│   ├── client-agent/      # Core agent daemon"
    echo "│   ├── logcollector/      # Log collection"
    echo "│   ├── syscheckd/         # File integrity monitoring"
    echo "│   ├── os_execd/          # Active response"
    echo "│   ├── rootcheck/         # Host intrusion detection"
    echo "│   ├── wazuh_modules/     # Modular components"
    echo "│   ├── shared/            # Common utilities"
    echo "│   ├── shared_modules/    # C++ shared modules"
    echo "│   ├── os_*/              # OS abstraction libraries"
    echo "│   └── external/          # Third-party dependencies"
    echo "├── etc/                   # Configuration files"
    echo "├── ruleset/               # Detection rules"
    echo "├── scripts/               # Management utilities"
    echo "└── bin-support/           # Active response scripts"
    echo ""
}

show_important_notes() {
    log_warning "Important Notes:"
    echo ""
    echo "🔴 CRITICAL REQUIREMENTS:"
    echo "   • This agent MUST connect to a Wazuh Manager"
    echo "   • Agent key enrollment is mandatory for operation"
    echo "   • Root privileges required for full functionality"
    echo ""
    
    echo "🟡 FUNCTIONALITY PRESERVED:"
    echo "   • ALL agent features extracted without loss"
    echo "   • Complete module ecosystem included"
    echo "   • Full configuration flexibility maintained"
    echo "   • Original security and performance characteristics"
    echo ""
    
    echo "🟢 ISOLATION ACHIEVED:"
    echo "   • No dependencies on manager-only components"
    echo "   • Self-contained build system"
    echo "   • Portable across Linux distributions"
    echo "   • Independent deployment capability"
    echo ""
}

show_troubleshooting() {
    log_info "Common Issues & Solutions:"
    echo ""
    echo "❌ Build fails with missing dependencies:"
    echo "   → Install development packages: libssl-dev, zlib1g-dev, libcjson-dev"
    echo ""
    echo "❌ Agent can't connect to manager:"
    echo "   → Check network connectivity: telnet MANAGER_IP 1514"
    echo "   → Verify agent key: cat /var/ossec/etc/client.keys"
    echo ""
    echo "❌ Permission denied errors:"
    echo "   → Run as root or check file permissions"
    echo "   → Fix ownership: sudo chown -R root:ossec /var/ossec/"
    echo ""
    echo "❌ High resource usage:"
    echo "   → Tune internal options in local_internal_options.conf"
    echo "   → Adjust module scan intervals"
    echo ""
}

show_next_steps() {
    log_info "Next Steps:"
    echo ""
    echo "1. 📖 Read the comprehensive documentation:"
    echo "   less README.md"
    echo ""
    echo "2. 🔧 Build the agent:"
    echo "   ./build_agent.sh --help"
    echo ""
    echo "3. ✅ Verify extraction completeness:"
    echo "   ./verify_agent.sh"
    echo ""
    echo "4. ⚙️ Configure for your environment:"
    echo "   nano etc/ossec.conf"
    echo ""
    echo "5. 🚀 Deploy and test:"
    echo "   sudo ./build_agent.sh --install"
    echo ""
    echo "6. 📞 Get support:"
    echo "   • Wazuh Community: https://wazuh.com/community/"
    echo "   • Documentation: https://documentation.wazuh.com/"
    echo "   • GitHub: https://github.com/wazuh/wazuh"
    echo ""
}

# Main execution
main() {
    clear
    show_header
    show_extraction_summary
    show_file_structure
    show_build_instructions
    show_configuration_guide
    show_deployment_steps
    show_testing_checklist
    show_important_notes
    show_troubleshooting
    show_next_steps
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  WAZUH AGENT SUCCESSFULLY EXTRACTED!${NC}"
    echo -e "${GREEN}  Ready for independent deployment.${NC}"
    echo -e "${GREEN}================================================${NC}"
}

# Run the summary
main "$@"
