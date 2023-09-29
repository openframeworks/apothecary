cmake_minimum_required(VERSION 3.10)
project(svgtiny VERSION 0.1.4)

set(COMPONENT_TYPE "lib-static")

# Find libxml2 package
if(NOT LIBXML2_INCLUDE_DIR OR NOT LIBXML2_LIBRARY)
    message(FATAL_ERROR "Please specify the LIBXML2_ROOT variable to the root directory of libxml2 installation.")
endif()

include_directories(${LIBXML2_INCLUDE_DIR})

file(GLOB_RECURSE SRC_FILES
    src/*.c
    libdom/src/*/*.c
    libdom/bindings/xml/libxml_xmlparser.c
    libwapcaplet/src/*.c
    libparserutils/src/*.c
    libparserutils/src/*/*.c
    libparserutils/src/*/*/*.c
)


set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_BSD_SOURCE -D_DEFAULT_SOURCE -DWITHOUT_ICONV_FILTER")

if (NOT CMAKE_C_COMPILER_VERSION VERSION_LESS 2.0)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}")
else()
    # __inline__ is a GCCism
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Dinline=__inline__")
endif()

# BeOS/Haiku/AmigaOS standard library headers create warnings
if (NOT "${CMAKE_BUILD_TYPE}" MATCHES "i586-pc-haiku" AND NOT "${CMAKE_BUILD_TYPE}" MATCHES "amigaos")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${WARNFLAGS}")
endif()


include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/libdom/include
    ${CMAKE_CURRENT_SOURCE_DIR}/libdom/src
    ${CMAKE_CURRENT_SOURCE_DIR}/libdom/bindings
    ${CMAKE_CURRENT_SOURCE_DIR}/libwapcaplet/include
    ${CMAKE_CURRENT_SOURCE_DIR}/libparserutils/include
    ${CMAKE_CURRENT_SOURCE_DIR}/libparserutils/src
)


add_library(svgtiny STATIC ${SRC_FILES})
target_link_libraries(svgtiny dom wapcaplet expat m ${LIBXML2_LIBRARY})


install(TARGETS svgtiny DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES include/svgtiny.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(FILES libsvgtiny.pc.in DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/pkgconfig RENAME libsvgtiny.pc)


add_custom_target(clean-all
    COMMAND ${CMAKE_BUILD_TOOL} clean
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/cmake/clean-all.cmake
)
