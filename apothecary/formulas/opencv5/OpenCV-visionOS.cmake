# Stock OpenCV has no OpenCV-visionOS.cmake. ios-cmake 4.6 sets
# CMAKE_SYSTEM_NAME=visionOS, so without this file imgcodecs treats the
# build as generic APPLE and compiles macosx_conversions.mm (AppKit).
message(STATUS "OpenCV: visionOS target (no AppKit/Cocoa)")
set(XROS ON)
set(WITH_CAP_IOS OFF)
