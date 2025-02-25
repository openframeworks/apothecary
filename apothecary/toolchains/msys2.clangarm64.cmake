# Check if the toolchain is already defined
if(NOT _MSYS_CLANGARM64_TOOLCHAIN)
    set(_MSYS_CLANGARM64_TOOLCHAIN 1)

    message(STATUS "MinGW Clang ARM64 toolchain loading...")

    # Set the target system to Windows
    set(CMAKE_SYSTEM_NAME "Windows" CACHE STRING "Target operating system" FORCE)
    set(CMAKE_SYSTEM_PROCESSOR "aarch64" CACHE STRING "Target processor architecture" FORCE)

    # Detect MSYS2 clangarm64 root directory by looking for clangarm64.ini
    set(Z_CLANGARM64_ROOT_DIR_CANDIDATE "${CMAKE_CURRENT_LIST_DIR}")
    while(NOT DEFINED Z_CLANGARM64_ROOT_DIR)
        if(EXISTS "${Z_CLANGARM64_ROOT_DIR_CANDIDATE}msys64/clangarm64.ini")
            set(Z_CLANGARM64_ROOT_DIR "${Z_CLANGARM64_ROOT_DIR_CANDIDATE}msys64/clangarm64" CACHE INTERNAL "MinGW Clang ARM64 root directory")
        elseif(IS_DIRECTORY "${Z_CLANGARM64_ROOT_DIR_CANDIDATE}")
            get_filename_component(Z_CLANGARM64_ROOT_DIR_TEMP "${Z_CLANGARM64_ROOT_DIR_CANDIDATE}" DIRECTORY)
            if(Z_CLANGARM64_ROOT_DIR_TEMP STREQUAL Z_CLANGARM64_ROOT_DIR_CANDIDATE)
                break() # Reached root without finding MSYS2
            endif()
            set(Z_CLANGARM64_ROOT_DIR_CANDIDATE "${Z_CLANGARM64_ROOT_DIR_TEMP}")
        else()
            message(WARNING "Could not find 'clangarm64.ini'. Check your MSYS2 installation!")
            break()
        endif()
    endwhile()
    unset(Z_CLANGARM64_ROOT_DIR_CANDIDATE)

    # Compiler and target settings
    set(CMAKE_C_COMPILER "${Z_CLANGARM64_ROOT_DIR}/bin/aarch64-w64-mingw32-clang.exe" CACHE FILEPATH "C compiler" FORCE)
    set(CMAKE_CXX_COMPILER "${Z_CLANGARM64_ROOT_DIR}/bin/aarch64-w64-mingw32-clang++.exe" CACHE FILEPATH "C++ compiler" FORCE)
    set(CMAKE_RC_COMPILER "${Z_CLANGARM64_ROOT_DIR}/bin/llvm-rc.exe" CACHE FILEPATH "Resource compiler" FORCE)
    set(CMAKE_MAKE_PROGRAM "${Z_CLANGARM64_ROOT_DIR}/bin/mingw32-make.exe" CACHE FILEPATH "Make program" FORCE)

    # Set the compiler target for cross-compiling
    set(CMAKE_C_COMPILER_TARGET "aarch64-w64-mingw32" CACHE STRING "C compiler target")
    set(CMAKE_CXX_COMPILER_TARGET "aarch64-w64-mingw32" CACHE STRING "C++ compiler target")

    # Basic include and link directories
    set(CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES
        "${Z_CLANGARM64_ROOT_DIR}/include/c++/v1"
        "${Z_CLANGARM64_ROOT_DIR}/lib/clang/19/include"
        "${Z_CLANGARM64_ROOT_DIR}/include"
        CACHE PATH "C implicit include directories" FORCE)
    set(CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES
        "${Z_CLANGARM64_ROOT_DIR}/include/c++/v1"
        "${Z_CLANGARM64_ROOT_DIR}/lib/clang/19/include"
        "${Z_CLANGARM64_ROOT_DIR}/include"
        CACHE PATH "C++ implicit include directories" FORCE)

    set(CMAKE_C_IMPLICIT_LINK_DIRECTORIES
        "${Z_CLANGARM64_ROOT_DIR}/aarch64-w64-mingw32/lib"
        "${Z_CLANGARM64_ROOT_DIR}/lib"
        "${Z_CLANGARM64_ROOT_DIR}/lib/clang/19/lib/windows"
        CACHE PATH "C implicit link directories" FORCE)
    set(CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES
        "${Z_CLANGARM64_ROOT_DIR}/aarch64-w64-mingw32/lib"
        "${Z_CLANGARM64_ROOT_DIR}/lib"
        "${Z_CLANGARM64_ROOT_DIR}/lib/clang/19/lib/windows"
        CACHE PATH "C++ implicit link directories" FORCE)

    # Standard libraries for linking
    set(CMAKE_C_STANDARD_LIBRARIES
        "-lmingw32 -lunwind -lmoldname -lmingwex -lkernel32 -lpthread -ladvapi32 -lshell32 -luser32"
        CACHE STRING "C standard libraries" FORCE)
    set(CMAKE_CXX_STANDARD_LIBRARIES
        "-lc++ -lmingw32 -lunwind -lmoldname -lmingwex -lkernel32 -lpthread -ladvapi32 -lshell32 -luser32"
        CACHE STRING "C++ standard libraries" FORCE)

    # Mark advanced variables
    mark_as_advanced(CMAKE_C_COMPILER CMAKE_CXX_COMPILER CMAKE_RC_COMPILER)
    mark_as_advanced(CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
    mark_as_advanced(CMAKE_C_IMPLICIT_LINK_DIRECTORIES CMAKE_CXX_IMPLICIT_LINK_DIRECTORIES)
    mark_as_advanced(CMAKE_C_STANDARD_LIBRARIES CMAKE_CXX_STANDARD_LIBRARIES)

    message(STATUS "MinGW Clang ARM64 toolchain loaded")
endif()