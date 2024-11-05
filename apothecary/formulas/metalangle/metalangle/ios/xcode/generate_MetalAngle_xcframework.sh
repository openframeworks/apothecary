#!/bin/sh

SCHEME=MetalANGLE
SCHEME_MAC=MetalANGLE_mac
SCHEME_TV=MetalANGLE_tvos
SCHEME_VISION=MetalANGLE_xros

ARCHS=~/Library/Developer/Xcode/Archives

clean()
{
	echo "*** Cleaning ***"
	rm -rf $ARCHS/xrOS.xcarchive
	rm -rf $ARCHS/xrOSSimulator.xcarchive
	rm -rf $ARCHS/AppleTvOS.xcarchive
	rm -rf $ARCHS/AppleTvSimulator.xcarchive
	rm -rf $ARCHS/iOSDevice.xcarchive
	rm -rf $ARCHS/iOSSimulator.xcarchive
	rm -rf $ARCHS/MacCatalyst.xcarchive
	rm -rf $ARCHS/macOS.xcarchive
}

if [[ ! -d "$ARCHS/xrOS.xcarchive" ]]; then
	echo "*** Creating archive for visionOS ***"
	xcodebuild archive -scheme $SCHEME_VISION -archivePath $ARCHS/xrOS.xcarchive -sdk xros SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/xrOS.xcarchive" ]]; then

  echo "Error: Failed to create archive for visionOS"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/xrOSSimulator.xcarchive" ]]; then
	echo "*** Creating archive for visionOS Simulator ***"
	xcodebuild archive -scheme $SCHEME_VISION -archivePath $ARCHS/xrOSSimulator.xcarchive -sdk xrsimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/xrOSSimulator.xcarchive" ]]; then

  echo "Error: Failed to create archive for visionOS Simulator"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/AppleTvOS.xcarchive" ]]; then
	echo "*** Creating archive for tvOS ***"
	xcodebuild archive -scheme $SCHEME_TV -archivePath $ARCHS/AppleTvOS.xcarchive -sdk appletvos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/AppleTvOS.xcarchive" ]]; then

  echo "Error: Failed to create archive for tvOS"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/AppleTvSimulator.xcarchive" ]]; then
	echo "*** Creating archive for tvOS Simulator ***"
	xcodebuild archive -scheme $SCHEME_TV -archivePath $ARCHS/AppleTvSimulator.xcarchive -sdk appletvsimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/AppleTvSimulator.xcarchive" ]]; then

  echo "Error: Failed to create archive for tvOS Simulator"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/iOSDevice.xcarchive" ]]; then
	echo "*** Creating archive for iOS ***"
	xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/iOSDevice.xcarchive -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/iOSDevice.xcarchive" ]]; then

  echo "Error: Failed to create archive for iOS"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/iOSSimulator.xcarchive" ]]; then
	echo "*** Creating archive for iOS Simulator ***"
	xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/iOSSimulator.xcarchive -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/iOSSimulator.xcarchive" ]]; then

  echo "Error: Failed to create archive for iOS Simulator"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/MacCatalyst.xcarchive" ]]; then
	echo "*** Creating archive for Mac Catalyst ***"
	xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/MacCatalyst.xcarchive -destination "generic/platform=macOS,variant=Mac Catalyst" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/MacCatalyst.xcarchive" ]]; then

  echo "Error: Failed to create archive for MacCatalyst"
  clean
  exit 0

fi

if [[ ! -d "$ARCHS/macOS.xcarchive" ]]; then
	echo "*** Creating archive for macOS ***"
	xcodebuild archive -scheme $SCHEME_MAC -archivePath $ARCHS/macOS.xcarchive -destination "generic/platform=macOS,name=Any Mac" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
fi

if [[ ! -d "$ARCHS/macOS.xcarchive" ]]; then

  echo "Error: Failed to create archive for macOS"
  clean
  exit 0

fi

if [[ ! -d "$SCHEME.xcframework" ]]; then
	echo "**** Creating XCFramework ****"
	xcodebuild -create-xcframework -framework $ARCHS/iOSSimulator.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/iOSDevice.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/MacCatalyst.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/macOS.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/AppleTvSimulator.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/AppleTvOS.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/xrOSSimulator.xcarchive/Products/Library/Frameworks/$SCHEME.framework -framework $ARCHS/xrOS.xcarchive/Products/Library/Frameworks/$SCHEME.framework -output $SCHEME.xcframework
fi

if [[ ! -d "$SCHEME.xcframework" ]]; then

  echo "Error: Failed to create XCFramework"
  clean
  exit 0

fi

clean
