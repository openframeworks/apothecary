# Android Toolchain CMake Configuration
cmake_minimum_required(VERSION 3.10)

# Add additional flags or settings if needed
set(CMAKE_ANDROID_STL_TYPE "c++_shared") # Adjust STL type if needed

if(NOT DEFINED C_STANDARD)
    set(C_STANDARD 17) # Default to C17
endif()
if(NOT DEFINED CPP_STANDARD)
    set(CPP_STANDARD 17) # Default to C++17
endif()
set(CMAKE_C_STANDARD ${C_STANDARD})
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD ${CPP_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# User-defined inputs for ABI and NDK path
if(NOT DEFINED ANDROID_ABI)
    message(FATAL_ERROR "ANDROID_ABI must be specified (e.g., armeabi-v7a, arm64-v8a, x86, x86_64)")
endif()

if(NOT DEFINED NDK_ROOT)
    message(FATAL_ERROR "NDK_ROOT must be specified as the path to the Android NDK")
endif()

# Detect Host Platform
if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(HOST_PLATFORM "darwin-x86_64")
elseif(${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    set(HOST_PLATFORM "windows-x86_64")
else()
    set(HOST_PLATFORM "linux-x86_64")
endif()

message(STATUS "Detected Host Platform: ${HOST_PLATFORM}")

# NDK Configuration
set(TOOLCHAIN_TYPE "llvm")
set(TOOLCHAIN "${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}")
set(SYSROOT "${TOOLCHAIN}/sysroot")

# ABI-specific configuration
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(MACHINE "armv7")
    set(ANDROID_PREFIX "arm-linux-androideabi")
    set(CMAKE_ANDROID_ARM_MODE ON)
    set(CMAKE_ANDROID_ARM_NEON ON)
    set(CMAKE_SYSTEM_PROCESSOR "arm")
    set(CMAKE_C_FLAGS "-mfpu=neon -mfloat-abi=hard")
    set(CMAKE_CXX_FLAGS "-mfpu=neon -mfloat-abi=hard")
elseif(ANDROID_ABI STREQUAL "arm64-v8a")
    set(MACHINE "arm64")
    set(ANDROID_PREFIX "aarch64-linux-android")
    set(CMAKE_SYSTEM_PROCESSOR "aarch64")
    set(CMAKE_ANDROID_ARM_MODE ON)
    set(CMAKE_ANDROID_ARM_NEON ON)
elseif(ANDROID_ABI STREQUAL "x86")
    set(MACHINE "i686")
    set(ANDROID_PREFIX "i686-linux-android")
    set(CMAKE_SYSTEM_PROCESSOR "x86")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(MACHINE "x86_64")
    set(ANDROID_PREFIX "x86_64-linux-android")
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
else()
    message(FATAL_ERROR "Unsupported ANDROID_ABI: ${ANDROID_ABI}")
endif()

message(STATUS "Configuring for ABI: ${ANDROID_ABI}")
message(STATUS "Machine: ${MACHINE}")
message(STATUS "Android Prefix: ${ANDROID_PREFIX}")

# Set compilers
set(CMAKE_C_COMPILER "${TOOLCHAIN}/bin/${ANDROID_PREFIX}${CMAKE_ANDROID_API}-clang")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN}/bin/${ANDROID_PREFIX}${CMAKE_ANDROID_API}-clang++")
set(CMAKE_LINKER "${TOOLCHAIN}/bin/${ANDROID_PREFIX}${CMAKE_ANDROID_API}-ld")

# Paths
set(CMAKE_SYSROOT ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Include and library paths
set(CMAKE_INCLUDE_PATH "${SYSROOT}/usr/include")
set(CMAKE_LIBRARY_PATH "${SYSROOT}/usr/lib/${ANDROID_PREFIX}/${CMAKE_ANDROID_API}")

# Compiler Binary
set(BIN_PREFIX "${TOOLCHAIN_ROOT}/bin/")

find_program(CMAKE_C_COMPILER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-gcc PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_CXX_COMPILER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-g++ PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_LINKER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ld PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_AR ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ar PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_NM ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-nm PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_RANLIB ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ranlib PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_STRIP ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-strip PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJCOPY ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-objcopy PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJDUMP ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-objdump PATHS "${TOOLCHAIN_ROOT}/bin/")

# Toolchain Debug Output
message(STATUS "NDK Root: ${NDK_ROOT}")
message(STATUS "Sysroot: ${SYSROOT}")
message(STATUS "Toolchain Path: ${TOOLCHAIN}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "Linker: ${CMAKE_LINKER}")

# Finalize toolchain settings
set(CMAKE_SYSTEM_NAME "Android")
set(CMAKE_SYSTEM_VERSION ${CMAKE_ANDROID_API})
set(CMAKE_ANDROID_NDK ${NDK_ROOT})

if(NOT EXISTS ${CMAKE_C_COMPILER})
    message(FATAL_ERROR "C Compiler not found: ${CMAKE_C_COMPILER}")
endif()
if(NOT EXISTS ${CMAKE_CXX_COMPILER})
    message(FATAL_ERROR "C++ Compiler not found: ${CMAKE_CXX_COMPILER}")
endif()
