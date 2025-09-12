#!/bin/bash
LIB_PATH="$WAZUH_HOME/src:$WAZUH_HOME/src/syscheckd/build/lib:$WAZUH_HOME/src/shared_modules/sync_protocol/build/lib:$WAZUH_HOME/src/wazuh_modules/sca/build/lib:$WAZUH_HOME/src/wazuh_modules/syscollector/build/lib:$WAZUH_HOME/src/shared_modules/dbsync/build/lib:$WAZUH_HOME/src/data_provider/build/lib:$WAZUH_HOME/src/external/libdb/build_unix/.libs:$LD_LIBRARY_PATH"

for script in bin/monitor-*; do
    echo "Updating $script..."
    sed -i.bak "s|export LD_LIBRARY_PATH=.*|export LD_LIBRARY_PATH=\"$LIB_PATH\"|" "$script"
done
