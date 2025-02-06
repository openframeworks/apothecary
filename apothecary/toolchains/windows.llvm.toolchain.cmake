
# Target System
set(CMAKE_SYSTEM_NAME Windows)  # We are targeting Windows
#set(CMAKE_SYSTEM_PROCESSOR x86_64) # 64-bit system
set(CMAKE_VERBOSE_MAKEFILE ON)

# Detect Clang Version from Environment
if(NOT DEFINED CLANG_VERSION)
    if(DEFINED ENV{CLANG_VERSION})
        set(CLANG_VERSION $ENV{CLANG_VERSION})
    else()
        set(CLANG_VERSION 18)  # Default to Clang 18
        message(WARNING "CLANG_VERSION not specified. Defaulting to CLANG_VERSION=${CLANG_VERSION}")
    endif()
endif()

# Clang Path
if(NOT DEFINED CLANG_PATH)
    if(DEFINED ENV{CLANG_PATH})
        set(CLANG_PATH $ENV{CLANG_PATH})
    else()
        # Default Clang Path for MSVC Toolchain
        set(CLANG_PATH "C:/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/Llvm/x64/bin")
    endif()
endif()

# Define C and C++ Standards
if(NOT DEFINED C_STANDARD)
    set(C_STANDARD 17 CACHE STRING "" FORCE) # Default to C17
endif()
if(NOT DEFINED CPP_STANDARD)
    set(CPP_STANDARD 17 CACHE STRING "" FORCE) # Default to C++17
endif()

set(CMAKE_C_STANDARD ${C_STANDARD} CACHE STRING "" FORCE)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD ${CPP_STANDARD} CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compiler and Linker Paths
set(CMAKE_C_COMPILER "${CLANG_PATH}/clang-cl.exe")
set(CMAKE_CXX_COMPILER "${CLANG_PATH}/clang-cl.exe")
set(CMAKE_RC_COMPILER "rc")

# Ensure correct system paths for MSVC headers/libs
set(VS_INCLUDE_PATH "C:/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/MSVC/14.36.32532/include")
set(VS_LIB_PATH "C:/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/MSVC/14.36.32532/lib/x64")

set(WINDOWS_SDK_PATH "C:/Program Files (x86)/Windows Kits/10")
set(WINDOWS_SDK_INCLUDE "${WINDOWS_SDK_PATH}/Include/10.0.22621.0")
set(WINDOWS_SDK_LIB "${WINDOWS_SDK_PATH}/Lib/10.0.22621.0")

include_directories(${VS_INCLUDE_PATH} ${WINDOWS_SDK_INCLUDE}/um ${WINDOWS_SDK_INCLUDE}/ucrt)
link_directories(${VS_LIB_PATH} ${WINDOWS_SDK_LIB}/um/x64 ${WINDOWS_SDK_LIB}/ucrt/x64)

# Clang Compiler and Linker Flags
set(CMAKE_C_FLAGS "/O2 /EHsc /DUNICODE /D_UNICODE /Wno-error")
set(CMAKE_CXX_FLAGS "/O2 /EHsc /DUNICODE /D_UNICODE /Wno-error -std:c++${CPP_STANDARD}")
set(CMAKE_EXE_LINKER_FLAGS "/LTCG /OPT:REF /OPT:ICF")
set(CMAKE_SHARED_LINKER_FLAGS "/DLL")

# Validate Clang Installation
message(STATUS "Using Clang Version: ${CLANG_VERSION}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")

# Check Compiler Existence
if(NOT EXISTS ${CMAKE_C_COMPILER})
    message(WARNING "C Compiler not found: ${CMAKE_C_COMPILER}")
endif()
if(NOT EXISTS ${CMAKE_CXX_COMPILER})
    message(WARNING "C++ Compiler not found: ${CMAKE_CXX_COMPILER}")
endif()
