meta:
	ADDON_NAME = ofxOQS
	ADDON_DESCRIPTION = Private Open Quantum Safe addon generated from Apothecary liboqs, oqsprovider and OpenSSH packages
	ADDON_AUTHOR = Apothecary
	ADDON_TAGS = "pqc" "liboqs" "openssl" "openssh"
	ADDON_URL = https://github.com/openframeworks/apothecary

common:
	ADDON_INCLUDES = libs/liboqs/include
	ADDON_INCLUDES += src
	ADDON_SOURCES_EXCLUDE = libs/%
	ADDON_INCLUDES_EXCLUDE = libs/oqsprovider/%
	ADDON_INCLUDES_EXCLUDE += libs/openssh/%

osx:
	ADDON_LIBS = libs/liboqs/lib/osx/liboqs.a

linux64:
	ADDON_LIBS = libs/liboqs/lib/linux64/liboqs.a

linux/64:
	ADDON_LIBS = libs/liboqs/lib/linux/64/liboqs.a

linuxaarch64:
	ADDON_LIBS = libs/liboqs/lib/linuxaarch64/liboqs.a

linux/aarch64:
	ADDON_LIBS = libs/liboqs/lib/linux/aarch64/liboqs.a

linuxarm64:
	ADDON_LIBS = libs/liboqs/lib/linuxarm64/liboqs.a

linux/arm64:
	ADDON_LIBS = libs/liboqs/lib/linux/arm64/liboqs.a
