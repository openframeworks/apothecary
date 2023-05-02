cmake_minimum_required(VERSION 3.0)
project(cairo)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Pixman REQUIRED)
find_package(PNG REQUIRED)
find_package(ZLIB REQUIRED)
find_package(Freetype)
find_package(Threads)
find_package(Fontconfig)


include(Configure_config.cmake)
include(Configure_features.cmake)
include_directories(${CMAKE_BINARY_DIR})

if(CAIRO_HAS_PTHREAD)
	list(APPEND CAIRO_LIBS -lpthread)
endif()

if (WIN32)
    set(CAIRO_LIBS gdi32 msimg32 user32 winmm)
endif()

include_directories(${PIXMAN_INCLUDE_DIR} ${PNG_INCLUDE_DIR} ${ZLIB_INCLUDE_DIR})
list(APPEND CAIRO_LIBS  ${PIXMAN_LIBRARY} ${PNG_LIBRARY} ${ZLIB_LIBRARY})

if(FONTCONFIG_FOUND)
    list(APPEND CAIRO_LIBS ${FONTCONFIG_LIBRARY})
endif()

if(FREETYPE_FOUND)
    find_package(BZip2)
    include_directories(${FREETYPE_INCLUDE_DIRS})
    include_directories(${BZIP2_INCLUDE_DIR})
    list(APPEND CAIRO_LIBS ${FREETYPE_LIBRARIES} ${BZIP2_LIBRARIES})
endif()

# Use options to disable features
if(NOT BUILD_GTK_DOC)
    add_definitions(-DCAIRO_NO_GTK_DOC)
endif()

if(NOT BUILD_TESTS)
    add_definitions(-DCAIRO_NO_TESTS)
endif()

if(NOT BUILD_DEPENDENCY_TRACKING)
    add_definitions(-DCAIRO_NO_DEPENDENCY_TRACKING)
endif()

if(NOT BUILD_XLIB)
    add_definitions(-DCAIRO_NO_XLIB)
endif()

if(NOT BUILD_QT)
    add_definitions(-DCAIRO_NO_QT)
endif()

if(NOT BUILD_QUARTZ_FONT)
    add_definitions(-DCAIRO_NO_QUARTZ_FONT)
endif()

if(NOT BUILD_QUARTZ)
    add_definitions(-DCAIRO_NO_QUARTZ)
endif()

if(NOT BUILD_QUARTZ_IMAGE)
    add_definitions(-DCAIRO_NO_QUARTZ_IMAGE)
endif()

include_directories(src)
add_subdirectory(src)

