# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/../../external/flatbuffers"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src/flatc_host_tool-build"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/tmp"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src/flatc_host_tool-stamp"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src"
  "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src/flatc_host_tool-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src/flatc_host_tool-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/home/anandhu/Desktop/wazuh/src/shared_modules/sync_protocol/build/flatc_host_tool-prefix/src/flatc_host_tool-stamp${cfgdir}") # cfgdir has leading slash
endif()
