# Builds libnettools.so: the native core for TCP probing.
# The ArkTS layer owns UI, mDNS discovery and persistence; all latency-
# sensitive network probing funnels through this module.
cmake_minimum_required(VERSION 3.5.0)
project(nettools)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(nettools SHARED napi_init.cpp)

target_link_libraries(nettools PUBLIC libace_napi.z.so)
