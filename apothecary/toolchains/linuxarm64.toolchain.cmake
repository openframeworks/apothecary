# Linux Ubuntu ARM64 Toolchain File

# Specify the system
set(CMAKE_SYSTEM_NAME Linux)        # Cross-compilation target system
set(CMAKE_SYSTEM_PROCESSOR aarch64) # Architecture (ARM64)
set(CMAKE_VERBOSE_MAKEFILE ON)

# GCC Version (Set this variable when invoking CMake)
if(NOT DEFINED GCC_VERSION)
    if(DEFINED ENV{GCC_VERSION})
        set(GCC_VERSION $ENV{GCC_VERSION})
    else()
        set(GCC_VERSION 14) # Default value
        message(WARNING "GCC_VERSION not specified. Defaulting to GCC_VERSION=${GCC_VERSION}")
    endif()
endif()

if(NOT DEFINED SYSROOT)
    if(DEFINED ENV{SYSROOT})
        set(SYSROOT $ENV{SYSROOT})
    else()
        set(SYSROOT "")
    endif()
endif()

if(NOT DEFINED TOOLCHAIN_ROOT)
    if(DEFINED ENV{TOOLCHAIN_ROOT})
        set(TOOLCHAIN_ROOT $ENV{TOOLCHAIN_ROOT})
    else()
        set(TOOLCHAIN_ROOT "" )
    endif()
endif()

if(NOT DEFINED CROSS_CPU)
    if(DEFINED ENV{CROSS_CPU})
        set(CROSS_CPU $ENV{CROSS_CPU})
    else()
        set(CROSS_CPU cortex-a53)
        message(WARNING "CROSS_CPU not specified. Defaulting to CROSS_CPU=cortex-a53")
    endif()
endif()

# Path to GCC 
if(NOT DEFINED GCC_PATH)
    if(DEFINED ENV{GCC_PATH})
        set(GCC_PATH $ENV{GCC_PATH}) # Use GCC_PATH from the env
    else()
        set(GCC_PATH "/usr/bin")
    endif()
endif()

if(NOT DEFINED C_STANDARD)
    set(C_STANDARD 17 CACHE STRING "" FORCE) # Default to C17
endif()
if(NOT DEFINED CPP_STANDARD)
    set(CPP_STANDARD 17 CACHE STRING "" FORCE) # Default to C++17
endif()

set(CMAKE_C_STANDARD ${C_STANDARD} CACHE STRING "" FORCE)
set(CMAKE_C_STANDARD_REQUIRED ON )
set(CMAKE_CXX_STANDARD ${CPP_STANDARD} CACHE STRING "" FORCE)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Compiler Binary Paths
set(CMAKE_C_COMPILER "${GCC_PATH}/aarch64-linux-gnu-gcc")
set(CMAKE_CXX_COMPILER "${GCC_PATH}/aarch64-linux-gnu-g++")

# Paths to system libraries and includes
set(CMAKE_SYSROOT "")
set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

find_program(CMAKE_C_COMPILER aarch64-linux-gnu-gcc PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++ PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_LINKER aarch64-linux-gnu-ld PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_AR aarch64-linux-gnu-ar PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_NM aarch64-linux-gnu-nm PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_RANLIB aarch64-linux-gnu-ranlib PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_STRIP aarch64-linux-gnu-strip PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJCOPY aarch64-linux-gnu-objcopy PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJDUMP aarch64-linux-gnu-objdump PATHS "${TOOLCHAIN_ROOT}/bin/")

message(STATUS "Using GCC Version: ${GCC_VERSION}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")

# Check for the existence of the specified GCC version
if(NOT EXISTS ${CMAKE_C_COMPILER})
    message(WARNING "C Compiler not found: ${CMAKE_C_COMPILER}")
endif()
if(NOT EXISTS ${CMAKE_CXX_COMPILER})
    message(WARNING "C++ Compiler not found: ${CMAKE_CXX_COMPILER}")
endif()

set(EXTRA_LINKS "-L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu \
    -Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu")

set(CFLAGS "-I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include \
    -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include \
    -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE \
    -D_FILE_OFFSET_BITS=64 \
    -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST")

# Compiler and linker flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CFLAGS} -fPIC -O3 -Wall -Wextra -march=armv8-a ${EXTRA_LINKS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CFLAGS} -fPIC -O3 -Wall -Wextra -std=c++${CPP_STANDARD} -march=armv8-a ${EXTRA_LINKS}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+simd+crypto")
set(CMAKE_EXE_LINKER_FLAGS "-fPIE -pie ${EXTRA_LINKS}")
set(CMAKE_SHARED_LINKER_FLAGS "-shared -fPIC")

message(STATUS "Using GCC Version: ${GCC_VERSION}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "C++ Compiler: ${CMAKE_CXX_COMPILER}")
message(STATUS "System Root: ${CMAKE_SYSROOT}")
