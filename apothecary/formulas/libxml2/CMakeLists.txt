cmake_minimum_required(VERSION 2.8.10)
project( xml2 )

if(MINGW OR UNIX)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-attributes")
endif()


set(XML2_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libxml2)
include_directories( "${XML2_SOURCE_DIR}/include" "${CMAKE_INSTALL_PREFIX}/include")
LINK_DIRECTORIES("${CMAKE_INSTALL_PREFIX}/lib")

#for windows only must fix later
include_directories("${XML2_SOURCE_DIR}/win32/VC10")

file( GLOB XML2_HEADERS ${XML2_SOURCE_DIR}/*.h )
file( GLOB XML2_SOURCES ${XML2_SOURCE_DIR}/*.c )

file( GLOB API_HEADERS ${XML2_SOURCE_DIR}/include/libxml/*.h )

#source_group( libxml FILES ${GLEW_HEADERS} )
#source_group( src    FILES ${GLEW_SOURCES} )
#include_directories(${ANDROID_NDK}/platforms/android-14/arch-arm/usr/include/asm)
#MESSAGE(${ANDROID_NDK}/platforms/android-14/arch-arm/usr/include)


if(XML2_BUILD_SHARED)
	set(XML2_LIBTYPE SHARED)
else()
	set(XML2_LIBTYPE STATIC)
	add_definitions( "-DLIBXML_STATIC" )
endif()

add_library( xml2 ${XML2_LIBTYPE} ${XML2_SOURCES} ${XML2_HEADERS} )
target_link_libraries(xml2 iconv ws2_32)

set_target_properties(xml2 PROPERTIES PUBLIC_HEADER "${API_HEADERS}")

set(BINDIR bin)
set(BINCOMPONENT runtime)
set(LIBDIR lib)
set(LIBCOMPONENT dev)
set(INCLUDEDIR include/libxml)
set(INCLUDECOMPONENT dev)

install(TARGETS xml2
	RUNTIME DESTINATION ${BINDIR} COMPONENT ${BINCOMPONENT}
	LIBRARY DESTINATION ${LIBDIR} COMPONENT ${LIBCOMPONENT}
	ARCHIVE DESTINATION ${LIBDIR} COMPONENT ${LIBCOMPONENT}
	PUBLIC_HEADER DESTINATION ${INCLUDEDIR} COMPONENT ${INCLUDECOMPONENT})