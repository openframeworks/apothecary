cmake_minimum_required(VERSION 3.10)
project(libusb)

# Compiler and linker flags
#add_compile_options(-std=gnu11 -Wall -Wextra -Wshadow -Wunused -Wwrite-strings -Werror=format-security -Werror=implicit-function-declaration -Werror=implicit-int -Werror=init-self -Werror=missing-prototypes -Werror=strict-prototypes -Werror=undef -Werror=uninitialized)

# Definitions
add_definitions(-DPACKAGE_NAME="libusb-1.0" -DPACKAGE_STRING="libusb-1.0 1.0.26" -DPACKAGE_TARNAME="libusb-1.0" -DPACKAGE_URL="http://libusb.info" -DPACKAGE_VERSION="1.0.26")

# Header files
set(HEADER_FILES
    libusb/libusb.h
    libusb/libusbi.h
    libusb/version.h
    libusb/version_nano.h
)


set(COMMON_SOURCE_FILES
    libusb/libusb.h
    libusb/libusbi.h
    libusb/version.h
    libusb/version_nano.h
    libusb/core.c
    libusb/descriptor.c
    libusb/hotplug.c
    libusb/io.c
    libusb/strerror.c
    libusb/sync.c
)

include_directories(.)
include_directories(libusb)

if(APPLE)
    set(PLATFORM_SOURCE_FILES
        libusb/os/events_posix.c
        libusb/os/threads_posix.c
        libusb/os/darwin_usb.c
    )
    find_library(IOKIT_LIBRARY IOKit)
    find_library(COREFOUNDATION_LIBRARY CoreFoundation)
    find_library(SECURITY_LIBRARY Security)
    set(EXTRA_LIBS ${IOKIT_LIBRARY} ${COREFOUNDATION_LIBRARY} ${SECURITY_LIBRARY})
elseif(WIN32)
    set(PLATFORM_SOURCE_FILES
        libusb/os/events_windows.c
        libusb/os/threads_windows.c
        libusb/os/windows_common.c
        libusb/os/windows_usbdk.c
        libusb/os/windows_winusb.c
        libusb/os/events_windows.h
        libusb/os/threads_windows.h
        libusb/os/windows_common.h
        libusb/os/windows_usbdk.h
        libusb/os/windows_winusb.h
        msvc/config.h
    )
    set(OTHER_HEADER_FILES
         msvc/config.h
    )
    add_definitions(-DOS_WINDOWS -DHAVE_CONFIG_H)
    include_directories(msvc)
endif()

add_library(libusb-1.0 STATIC ${COMMON_SOURCE_FILES} ${PLATFORM_SOURCE_FILES})

# Link extra libraries
if(APPLE)
    target_link_libraries(libusb-1.0 ${EXTRA_LIBS})
endif()

# Install the library and headers
install(TARGETS libusb-1.0
        ARCHIVE DESTINATION lib
        PUBLIC_HEADER DESTINATION include
)

install(FILES ${HEADER_FILES} ${OTHER_HEADER_FILES} DESTINATION include)