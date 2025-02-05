cmake_minimum_required(VERSION 3.15)

set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_VERSION 1)

# Raspberry Pi - 3 Model A+/B+ & 4 Model B 400/B & 5 & Compute 3/3-lite/3+/4 (64-Bit)

set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)
set(GCC_VERSION 14.2.0)

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

if(NOT DEFINED M_CPU)
    set(M_CPU cortex-a53) # Default to cortex-a53 / cortex-A76
endif()

if(NOT DEFINED TOOLCHAIN_ROOT)
    if(DEFINED ENV{TOOLCHAIN_ROOT})
        set(TOOLCHAIN_ROOT $ENV{TOOLCHAIN_ROOT})
    else()
        set(TOOLCHAIN_ROOT rasbian) # Default value
        message(WARNING "TOOLCHAIN_ROOT not specified. Defaulting to TOOLCHAIN_ROOT=rasbian")
    endif()
endif()

if(NOT DEFINED SYSROOT)
    if(DEFINED ENV{SYSROOT})
        set(SYSROOT $ENV{SYSROOT})
    else()
        set(SYSROOT raspbian_rootfs) # Default value
        message(WARNING "SYSROOT not specified. Defaulting to SYSROOT=raspbian_rootfs")
    endif()
endif()

set(tools ${TOOLCHAIN_ROOT}) # warning change toolchain path here.
set(rootfs_dir ${SYSROOT}/rootfs) # warning change compiled rootfs path here.

set(CMAKE_FIND_ROOT_PATH ${rootfs_dir} CACHE STRING "" FORCE)
set(CMAKE_SYSROOT ${rootfs_dir} CACHE STRING "" FORCE)

SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(EXTRA_LINKS "")
if (EXISTS "${CMAKE_SYSROOT}/lib/")
    list(APPEND EXTRA_LINKS "-Wl,-rpath-link,${CMAKE_SYSROOT}/lib/" "-L${CMAKE_SYSROOT}/lib/")
endif()
if (EXISTS "${CMAKE_SYSROOT}/lib64/")
    list(APPEND EXTRA_LINKS "-Wl,-rpath-link,${CMAKE_SYSROOT}/lib64/" "-L${CMAKE_SYSROOT}/lib64/")
endif()
if (EXISTS "${CMAKE_SYSROOT}/lib/aarch64-linux-gnu/")
    list(APPEND EXTRA_LINKS "-Wl,-rpath-link,${CMAKE_SYSROOT}/lib/aarch64-linux-gnu" "-L${CMAKE_SYSROOT}/lib/aarch64-linux-gnu")
endif()

message(STATUS "CMAKE_SYSROOT: ${CMAKE_SYSROOT}")
message(STATUS "CMAKE_LIBRARY_ARCHITECTURE: ${CMAKE_LIBRARY_ARCHITECTURE}")
message(STATUS "TOOLCHAIN_ROOT: ${TOOLCHAIN_ROOT}")

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fPIC ${EXTRA_LINKS}")

set(CFLAGS "--sysroot=${SYSROOT} -I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include -I/usr/include -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CFLAGS} ${CFLAGS} -fPIC ${EXTRA_LINKS} -mcpu=${M_CPU}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CFLAGS} ${CFLAGS} -fPIC ${EXTRA_LINKS} -mcpu=${M_CPU}")

# NEON
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a+fp+simd")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8-a+fp+simd")

## Compiler Binary 
set(BIN_PREFIX "${TOOLCHAIN_ROOT}/bin/")

find_program(CMAKE_C_COMPILER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-gcc PATHS "${TOOLCHAIN_ROOT}/bin" "/usr/bin" "/usr/aarch64-linux-gnu/bin" "/opt/aarch64-linux-gnu/bin" NO_DEFAULT_PATH)
find_program(CMAKE_CXX_COMPILER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-g++ PATHS "${TOOLCHAIN_ROOT}/bin" "/usr/bin" "/usr/aarch64-linux-gnu/bin" "/opt/aarch64-linux-gnu/bin" NO_DEFAULT_PATH)

find_program(CMAKE_LINKER ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ld PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_AR ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ar PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_NM ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-nm PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_RANLIB ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-ranlib PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_STRIP ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-strip PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJCOPY ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-objcopy PATHS "${TOOLCHAIN_ROOT}/bin/")
find_program(CMAKE_OBJDUMP ${CMAKE_SYSTEM_PROCESSOR}-linux-gnu-objdump PATHS "${TOOLCHAIN_ROOT}/bin/")

# Check if critical tools exist
if(NOT EXISTS ${CMAKE_C_COMPILER})
    message(FATAL_ERROR "C Compiler not found: ${CMAKE_C_COMPILER}")
endif()

if(NOT EXISTS ${CMAKE_CXX_COMPILER})
    message(FATAL_ERROR "C++ Compiler not found: ${CMAKE_CXX_COMPILER}")
endif()

if(NOT EXISTS ${CMAKE_LINKER})
    message(FATAL_ERROR "Linker not found: ${CMAKE_LINKER}")
endif()

