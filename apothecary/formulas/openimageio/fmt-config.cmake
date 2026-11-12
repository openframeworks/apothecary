include("${CMAKE_CURRENT_LIST_DIR}/fmt-version.cmake")
set(fmt_VERSION "${PACKAGE_VERSION}")
if(NOT TARGET fmt::fmt-header-only)
    add_library(fmt::fmt-header-only INTERFACE IMPORTED)
    set_target_properties(fmt::fmt-header-only PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${APOTHECARY_FMT_ROOT}/include"
        INTERFACE_COMPILE_DEFINITIONS FMT_HEADER_ONLY)
endif()
