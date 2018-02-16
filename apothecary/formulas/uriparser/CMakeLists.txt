project(uriparser)

cmake_minimum_required(VERSION 2.6)

set (SRC_LIST "src/*.c")

file( GLOB SOURCES ${SRC_LIST} )

add_library(uriparser STATIC ${SOURCES})

target_include_directories( uriparser PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_include_directories( uriparser PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")

if (${ANDROID_ABI} STREQUAL "armeabi-v7a")
    target_compile_options( uriparser PRIVATE "-mfloat-abi=softfp" )
endif()

target_compile_options( uriparser PRIVATE "-nostdlib" )
target_compile_options( uriparser PRIVATE "-fPIC" )
