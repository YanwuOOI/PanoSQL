# CMakeLists.txt for PanoDB Native SQLite Module
# PanoDB Project

cmake_minimum_required(VERSION 3.18.1)

project("panodb_sqlite")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenHarmony NAPI
find_library(napi_lib napi)
if(NOT napi_lib)
    message(WARNING "NAPI library not found, using stub")
endif()

# Find log library for hilog
find_library(log_lib log)
if(NOT log_lib)
    message(WARNING "log library not found")
endif()

# Find SQLite3 - OpenHarmony provides sqlite3
# Try different approaches to find SQLite3
find_package(OpenHarmony COMPONENTS sqlite3 QUIET)
if(OpenHarmony_sqlite3_FOUND)
    message(STATUS "Found OpenHarmony sqlite3")
    set(SQLITE3_LIBRARY OpenHarmony::sqlite3)
else()
    # Fallback: try to find system sqlite3
    find_library(SQLITE3_LIBRARY sqlite3)
    if(NOT SQLITE3_LIBRARY)
        message(WARNING "SQLite3 not found, building with bundled sqlite3")
        # Enable SQLite3 header search
        add_definitions(-DSQLITE_HAS_CODEC)
    endif()
endif()

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Add source files
set(SOURCE_FILES
    sqlite_manager.cpp
    napi_sqlite_manager.cpp
)

# Create shared library
add_library(panodb_sqlite SHARED
    ${SOURCE_FILES}
)

# Link libraries
if(napi_lib)
    target_link_libraries(panodb_sqlite PUBLIC ${napi_lib})
endif()

if(log_lib)
    target_link_libraries(panodb_sqlite PUBLIC ${log_lib})
endif()

if(SQLITE3_LIBRARY)
    target_link_libraries(panodb_sqlite PUBLIC ${SQLITE3_LIBRARY})
else()
    # Link system sqlite3 if available
    target_link_libraries(panodb_sqlite PUBLIC sqlite3)
endif()

# Set output directory - put .so in rawfile directory for ArkTS access
set_target_properties(panodb_sqlite PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../resources/rawfile
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../resources/rawfile
)

# Install to rawfile directory
install(TARGETS panodb_sqlite
    LIBRARY DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../resources/rawfile
)
