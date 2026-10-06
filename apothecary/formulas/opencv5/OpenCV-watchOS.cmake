# Same gap as OpenCV-tvOS.cmake: CMAKE_SYSTEM_NAME=watchOS has no stock
# OpenCV platform file, so imgcodecs would pull AppKit.
message(STATUS "OpenCV: watchOS target (no AppKit, no iOS camera)")
set(WITH_CAP_IOS OFF)
set(WITH_AVFOUNDATION OFF)
