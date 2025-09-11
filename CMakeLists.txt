cmake_minimum_required(VERSION 3.12.4)

project(WazuhAgent)

enable_testing()

if(NOT CMAKE_BUILD_TYPE)
  if(CMAKE_SYMBOLS_IN_RELEASE MATCHES "ON")
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
  else()
    set(CMAKE_BUILD_TYPE Release)
  endif()
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

get_filename_component(SRC_FOLDER     ${CMAKE_SOURCE_DIR}/src/ ABSOLUTE)

# Set agent-specific install prefix
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "/var/ossec" CACHE PATH "Wazuh Agent install path" FORCE)
endif()

################################
# External dependencies
################################
function(check_and_download_dep libname url)
    if(NOT EXISTS ${SRC_FOLDER}/external/${libname})
        message("==============================================")

        # Download library from S3 bucket
        message("Downloading ${libname}...")
        file(DOWNLOAD ${url}/${libname}.tar.gz ${SRC_FOLDER}/external/${libname}.tar.gz
                TIMEOUT 60  # seconds
                STATUS DOWNLOAD_STATUS)
        list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
        list(GET DOWNLOAD_STATUS 1 STATUS_MESSAGE)
        if(NOT STATUS_CODE EQUAL 0)
            message(FATAL_ERROR "Error downloading ${libname}: ${STATUS_MESSAGE} (${STATUS_CODE}).")
        endif(NOT STATUS_CODE EQUAL 0)

        # Extract library
        message("Extracting ${libname}.tar.gz")
        execute_process(COMMAND ${CMAKE_COMMAND} -E tar xfz "${SRC_FOLDER}/external/${libname}.tar.gz" WORKING_DIRECTORY ${SRC_FOLDER}/external RESULT_VARIABLE STATUS_VALUE)
        if(NOT STATUS_VALUE EQUAL 0)
            message(FATAL_ERROR "Error extracting ${libname}: ${STATUS_VALUE}.")
        endif(NOT STATUS_VALUE EQUAL 0)

        # Cleanup tar file
        message("Cleaning ${libname}.tar.gz")
        file(REMOVE ${SRC_FOLDER}/external/${libname}.tar.gz)
    endif()
endfunction(check_and_download_dep)

# Download and prepare external dependencies (agent subset)
set(EXTERNAL_URL_PREFIX "https://packages.wazuh.com/deps/4.12")

# Core dependencies for agent
check_and_download_dep("openssl" "${EXTERNAL_URL_PREFIX}")
check_and_download_dep("zlib" "${EXTERNAL_URL_PREFIX}")
check_and_download_dep("cJSON" "${EXTERNAL_URL_PREFIX}")
check_and_download_dep("libarchive" "${EXTERNAL_URL_PREFIX}")

# Optional dependencies that might be needed by modules
if(EXISTS "${SRC_FOLDER}/wazuh_modules")
    check_and_download_dep("rocksdb" "${EXTERNAL_URL_PREFIX}")
    check_and_download_dep("lzma" "${EXTERNAL_URL_PREFIX}")
    check_and_download_dep("flatbuffers" "${EXTERNAL_URL_PREFIX}")
    check_and_download_dep("simdjson" "${EXTERNAL_URL_PREFIX}")
    check_and_download_dep("cpp-httplib" "${EXTERNAL_URL_PREFIX}")
    check_and_download_dep("nlohmann" "${EXTERNAL_URL_PREFIX}")
endif()

# Set up library directories
link_directories(${SRC_FOLDER})
link_directories(${SRC_FOLDER}/external/openssl/)
link_directories(${SRC_FOLDER}/external/zlib/)
link_directories(${SRC_FOLDER}/external/zlib/contrib/minizip/)

if(EXISTS "${SRC_FOLDER}/external/rocksdb")
    link_directories(${SRC_FOLDER}/external/rocksdb/build/)
endif()
if(EXISTS "${SRC_FOLDER}/external/lzma")
    link_directories(${SRC_FOLDER}/external/lzma/build/)
endif()
if(EXISTS "${SRC_FOLDER}/external/flatbuffers")
    link_directories(${SRC_FOLDER}/external/flatbuffers/build/)
endif()
if(EXISTS "${SRC_FOLDER}/external/simdjson")
    link_directories(${SRC_FOLDER}/external/simdjson/build/)
endif()

# Include directories for agent components
include_directories(${SRC_FOLDER}/shared_modules/common)
include_directories(${SRC_FOLDER}/shared_modules/utils)
include_directories(${SRC_FOLDER}/shared_modules/router/include)
include_directories(${SRC_FOLDER}/shared_modules/content_manager/include)
include_directories(${SRC_FOLDER}/shared_modules/file_helper/file_io/include)
include_directories(${SRC_FOLDER}/shared_modules/file_helper/filesystem/include)
include_directories(${SRC_FOLDER}/shared_modules/indexer_connector/include)
include_directories(${SRC_FOLDER}/shared_modules/http-request/include)
include_directories(${SRC_FOLDER}/shared_modules/keystore/include)
include_directories(${SRC_FOLDER}/headers)
include_directories(${SRC_FOLDER}/external/cJSON)
include_directories(${SRC_FOLDER}/external/openssl/include)
include_directories(${SRC_FOLDER}/external/zlib/)
include_directories(${SRC_FOLDER}/external/zlib/contrib/)
include_directories(${SRC_FOLDER}/external/libarchive/libarchive/)

# Optional includes for modules
if(EXISTS "${SRC_FOLDER}/external/nlohmann")
    include_directories(${SRC_FOLDER}/external/nlohmann)
endif()
if(EXISTS "${SRC_FOLDER}/external/cpp-httplib")
    include_directories(${SRC_FOLDER}/external/cpp-httplib)
endif()
if(EXISTS "${SRC_FOLDER}/external/rocksdb")
    include_directories(${SRC_FOLDER}/external/rocksdb/include)
endif()
if(EXISTS "${SRC_FOLDER}/external/lzma")
    include_directories(${SRC_FOLDER}/external/lzma/src/liblzma/api)
endif()
if(EXISTS "${SRC_FOLDER}/external/simdjson")
    include_directories(${SRC_FOLDER}/external/simdjson/include/)
endif()

# Build shared modules and utilities first (dependency order)
if(EXISTS "${SRC_FOLDER}/shared_modules/utils")
    add_subdirectory(src/shared_modules/utils)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/router")
    add_subdirectory(src/shared_modules/router)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/content_manager")
    add_subdirectory(src/shared_modules/content_manager)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/file_helper")
    add_subdirectory(src/shared_modules/file_helper)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/http-request")
    set(CURL_DEP wazuhext)
    add_subdirectory(src/shared_modules/http-request)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/indexer_connector")
    add_subdirectory(src/shared_modules/indexer_connector)
endif()
if(EXISTS "${SRC_FOLDER}/shared_modules/keystore")
    add_subdirectory(src/shared_modules/keystore)
endif()

# Build agent-specific components
if(EXISTS "${SRC_FOLDER}/wazuh_modules/inventory_sync")
    add_subdirectory(src/wazuh_modules/inventory_sync)
endif()

# Build core agent daemons and libraries
# Note: We'll need to create individual CMakeLists.txt files for each daemon
# For now, we'll set up the structure

message("==============================================")
message("Wazuh Agent Build Configuration")
message("==============================================")
message("Build type: ${CMAKE_BUILD_TYPE}")
message("Install prefix: ${CMAKE_INSTALL_PREFIX}")
message("Source folder: ${SRC_FOLDER}")
message("==============================================")

# Create targets for the main agent executables
# These will need individual CMakeLists.txt files in their respective directories

# TODO: Add individual daemon targets:
# - wazuh-agentd (from src/client-agent)
# - wazuh-logcollector (from src/logcollector)
# - wazuh-syscheckd (from src/syscheckd)
# - wazuh-modulesd (from src/wazuh_modules)
# - wazuh-execd (from src/os_execd)

# For now, we'll create a basic agent library
add_library(wazuh_agent_core STATIC
    src/shared/debug_op.c
    src/shared/file_op.c
    src/shared/help.c
    src/shared/mem_op.c
    src/shared/privsep_op.c
    src/shared/string_op.c
    src/shared/time_op.c
    src/shared/validate_op.c
)

# Link against required system libraries
target_link_libraries(wazuh_agent_core
    pthread
    m
    z
    ssl
    crypto
)

# Install configurations
install(DIRECTORY etc/ DESTINATION etc)
install(DIRECTORY ruleset/ DESTINATION etc/rules)
install(DIRECTORY scripts/ DESTINATION bin
        FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
