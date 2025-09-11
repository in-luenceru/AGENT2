#!/bin/bash

# 📚 WAZUH DOCUMENTATION GUIDE
# This script explains how to use all the documentation and tools provided

clear

cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🛡️  WAZUH AGENT - DOCUMENTATION GUIDE  🛡️                   ║
╚════════════════════════════════════════════════════════════════════════════════╝

Welcome to your complete Wazuh Agent documentation suite! This guide explains
how to use all the documentation and tools we've created for you.

┌────────────────────────────────────────────────────────────────────────────┐
│ 📋 WHAT'S INCLUDED IN YOUR DOCUMENTATION SUITE                            │
└────────────────────────────────────────────────────────────────────────────┘

1. 📖 COMPLETE_USAGE_DOCUMENTATION.md    - Full comprehensive manual
2. 🚀 wazuh_quick_operations.sh          - Interactive operations menu
3. 📋 wazuh_cheat_sheet.sh               - Quick reference commands
4. 📚 documentation_guide.sh             - This file - explains everything
5. 🔧 Various testing and validation scripts

┌────────────────────────────────────────────────────────────────────────────┐
│ 📖 1. COMPLETE USAGE DOCUMENTATION                                        │
└────────────────────────────────────────────────────────────────────────────┘

FILE: COMPLETE_USAGE_DOCUMENTATION.md

This is your MAIN REFERENCE DOCUMENT with everything you need:

WHAT'S INSIDE:
✅ Complete system architecture overview
✅ Step-by-step installation guide
✅ Detailed configuration examples
✅ All operation commands explained
✅ Monitoring and alerting setup
✅ Network security detection guide
✅ Comprehensive troubleshooting procedures
✅ Production deployment checklist
✅ Maintenance and update procedures

HOW TO USE:
# View the documentation
less /home/anandhu/AGENT/COMPLETE_USAGE_DOCUMENTATION.md

# Or open in your preferred editor
nano /home/anandhu/AGENT/COMPLETE_USAGE_DOCUMENTATION.md
code /home/anandhu/AGENT/COMPLETE_USAGE_DOCUMENTATION.md

# Search for specific topics
grep -i "troubleshoot" /home/anandhu/AGENT/COMPLETE_USAGE_DOCUMENTATION.md

WHEN TO USE:
📌 First time setup and configuration
📌 Detailed understanding of any component
📌 Troubleshooting complex issues
📌 Production deployment planning
📌 Reference for all available options

┌────────────────────────────────────────────────────────────────────────────┐
│ 🚀 2. QUICK OPERATIONS SCRIPT                                             │
└────────────────────────────────────────────────────────────────────────────┘

FILE: wazuh_quick_operations.sh

This is your INTERACTIVE MENU for daily operations:

FEATURES:
✅ User-friendly menu interface
✅ Start/Stop/Restart agent with one click
✅ Real-time status checking
✅ Live alert monitoring
✅ Log viewing and searching
✅ Network detection testing
✅ System report generation
✅ Automated troubleshooting
✅ Documentation access
✅ Log cleanup utilities

HOW TO USE:
# Run the interactive menu
./wazuh_quick_operations.sh

# Or make it available system-wide
sudo cp wazuh_quick_operations.sh /usr/local/bin/wazuh-ops
sudo chmod +x /usr/local/bin/wazuh-ops
wazuh-ops  # Run from anywhere

less /home/anandhu/AGENT/docs/COMPLETE_USAGE_DOCUMENTATION.md
1. 🚀 Start/Stop/Restart Agent
2. ℹ️  Check Agent Status  
nano /home/anandhu/AGENT/docs/COMPLETE_USAGE_DOCUMENTATION.md
4. 📋 View Recent Logs
5. 🔍 Test Network Detection
6. 📊 Generate System Report
7. 🔧 Troubleshoot Issues
8. 📖 View Documentation
9. 🧹 Clean Old Logs
0. 🚪 Exit

WHEN TO USE:
📌 Daily operations and monitoring
📌 Quick status checks
📌 Routine maintenance tasks
📌 Real-time problem diagnosis
📌 System health monitoring

┌────────────────────────────────────────────────────────────────────────────┐
│ 📋 3. CHEAT SHEET                                                          │
└────────────────────────────────────────────────────────────────────────────┘

FILE: wazuh_cheat_sheet.sh

This is your QUICK REFERENCE for all commands:

CONTAINS:
✅ All essential commands organized by category
✅ Agent operations (start, stop, status)
✅ Docker manager operations
✅ Agent management commands
✅ Log analysis commands
✅ Configuration file locations
✅ Troubleshooting procedures
✅ Security testing commands
✅ Custom rule examples
✅ Emergency procedures
✅ Health check script

HOW TO USE:
# Display the cheat sheet
./wazuh_cheat_sheet.sh

# View specific sections
./wazuh_cheat_sheet.sh | grep -A 10 "AGENT OPERATIONS"

# Save to file for offline reference
./wazuh_cheat_sheet.sh > my_wazuh_cheatsheet.txt

# Print for physical reference
./wazuh_cheat_sheet.sh | lpr

CATEGORIES INCLUDED:
🚀 Agent Operations
🐳 Docker Manager Operations  
👥 Agent Management
📋 Log Analysis
🔧 Configuration
🔍 Monitoring & Testing
🚨 Troubleshooting
📊 Useful One-liners
🔐 Security Testing
📝 Custom Rules Examples
📞 Emergency Procedures
🎯 Quick Health Check

WHEN TO USE:
📌 Quick command lookup
📌 Emergency situations
📌 Learning Wazuh commands
📌 Scripting and automation
📌 Training new team members

┌────────────────────────────────────────────────────────────────────────────┐
│ 🎯 HOW TO USE THIS DOCUMENTATION EFFECTIVELY                              │
└────────────────────────────────────────────────────────────────────────────┘

FOR BEGINNERS:
1. 📖 Start with COMPLETE_USAGE_DOCUMENTATION.md - Overview section
2. 🚀 Use wazuh_quick_operations.sh for hands-on learning
3. 📋 Keep wazuh_cheat_sheet.sh handy for quick reference

FOR DAILY OPERATIONS:
1. 🚀 Use wazuh_quick_operations.sh for routine tasks
2. 📋 Reference wazuh_cheat_sheet.sh for specific commands
3. 📖 Consult full documentation for complex procedures

FOR TROUBLESHOOTING:
1. 🚀 Run troubleshoot option in wazuh_quick_operations.sh
2. 📋 Check emergency procedures in wazuh_cheat_sheet.sh
3. 📖 Follow detailed troubleshooting guide in full documentation

FOR PRODUCTION DEPLOYMENT:
1. 📖 Follow production deployment section in full documentation
2. 🚀 Use system report generation for baseline metrics
3. 📋 Set up monitoring using cheat sheet commands

┌────────────────────────────────────────────────────────────────────────────┐
│ 🔗 DOCUMENTATION STRUCTURE                                                │
└────────────────────────────────────────────────────────────────────────────┘

/home/anandhu/AGENT/
├── COMPLETE_USAGE_DOCUMENTATION.md     ← 📖 MAIN MANUAL
├── wazuh_quick_operations.sh           ← 🚀 INTERACTIVE MENU
├── wazuh_cheat_sheet.sh                ← 📋 QUICK REFERENCE
├── documentation_guide.sh              ← 📚 THIS GUIDE
├── final_validation_report.sh          ← ✅ SYSTEM VALIDATION
├── comprehensive_network_detection_test.sh ← 🔍 NETWORK TESTING
└── various other scripts and configs...

┌────────────────────────────────────────────────────────────────────────────┐
│ 🏃 GETTING STARTED - YOUR FIRST 5 MINUTES                               │
└────────────────────────────────────────────────────────────────────────────┘

1. CHECK SYSTEM STATUS (30 seconds):
   ./wazuh_quick_operations.sh
   Choose option 2 (Check Agent Status)

2. VIEW RECENT ACTIVITY (1 minute):
   Choose option 4 (View Recent Logs)
   Select option 2 (Manager alerts - last 20 lines)

3. TEST THE SYSTEM (2 minutes):
   Choose option 5 (Test Network Detection)
   Watch the automated tests run

4. GENERATE A REPORT (1 minute):
   Choose option 6 (Generate System Report)
   Review the comprehensive system status

5. KEEP REFERENCES HANDY (30 seconds):
   Open another terminal: ./wazuh_cheat_sheet.sh
   Bookmark: COMPLETE_USAGE_DOCUMENTATION.md

┌────────────────────────────────────────────────────────────────────────────┐
│ 🎓 LEARNING PATH RECOMMENDATIONS                                          │
└────────────────────────────────────────────────────────────────────────────┘

WEEK 1 - BASICS:
□ Read Overview and Architecture sections in full documentation
□ Practice with quick operations script daily
□ Familiarize yourself with cheat sheet commands

WEEK 2 - OPERATIONS:
□ Learn log analysis and monitoring techniques
□ Practice troubleshooting procedures
□ Set up custom monitoring rules

WEEK 3 - ADVANCED:
□ Implement network security detection
□ Create custom rules and alerts
□ Practice production deployment procedures

WEEK 4 - MASTERY:
□ Automate routine tasks
□ Optimize performance settings
□ Develop backup and recovery procedures

┌────────────────────────────────────────────────────────────────────────────┐
│ 🆘 QUICK HELP                                                             │
└────────────────────────────────────────────────────────────────────────────┘

NEED IMMEDIATE HELP?
1. 🚨 Emergency: ./wazuh_quick_operations.sh → Option 7 (Troubleshoot)
2. 📋 Quick command: ./wazuh_cheat_sheet.sh | grep -A 5 "YOUR_ISSUE"
3. 📖 Detailed help: Search COMPLETE_USAGE_DOCUMENTATION.md

SYSTEM NOT WORKING?
1. Check status: sudo /var/ossec/bin/wazuh-control status
2. Check manager: docker ps | grep wazuh
3. Test connection: telnet 127.0.0.1 1514

WANT TO CONTRIBUTE?
- Found an issue? Add it to the documentation
- Created a useful script? Share it with the team
- Discovered a better method? Update the procedures

┌────────────────────────────────────────────────────────────────────────────┐
│ 🎉 CONGRATULATIONS!                                                       │
└────────────────────────────────────────────────────────────────────────────┘

You now have a COMPLETE, PROFESSIONAL-GRADE Wazuh documentation suite!

✅ Comprehensive manual with everything you need
✅ Interactive tools for daily operations  
✅ Quick reference for all commands
✅ Troubleshooting guides and procedures
✅ Security testing and validation tools
✅ Production deployment guidelines

Your Wazuh agent is fully operational and you have all the tools needed
to manage, monitor, and maintain it effectively.

🚀 Ready to start? Run: ./wazuh_quick_operations.sh
📖 Need details? Read: COMPLETE_USAGE_DOCUMENTATION.md
📋 Need commands? Check: ./wazuh_cheat_sheet.sh

Happy monitoring! 🛡️

EOF

echo
read -p "Press Enter to continue or Ctrl+C to exit..."
    less "/home/anandhu/AGENT/docs/COMPLETE_USAGE_DOCUMENTATION.md"
# Show available files
echo
echo "Available documentation files in your directory:"
ls -la /home/anandhu/AGENT/*.md /home/anandhu/AGENT/*operations*.sh /home/anandhu/AGENT/*cheat*.sh /home/anandhu/AGENT/*guide*.sh 2>/dev/null

echo
echo "What would you like to do next?"
echo "1. Open the complete documentation"
echo "2. Run the quick operations menu"  
echo "3. View the cheat sheet"
echo "4. Exit"

read -p "Choose (1-4): " choice

case $choice in
    1)
        less /home/anandhu/AGENT/COMPLETE_USAGE_DOCUMENTATION.md
        ;;
    2)
        ./wazuh_quick_operations.sh
        ;;
    3)
        ./wazuh_cheat_sheet.sh | less
        ;;
    4)
        echo "Goodbye! Your documentation is ready for use."
        ;;
    *)
        echo "Invalid option. Documentation files are ready for use."
        ;;
esac
