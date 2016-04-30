SET MSYS2_BASE=msys2-base-%MSYS2_ARCH%-%MSYS2_BASEVER%.tar.xz
ECHO.Downloading %MSYS2_BASE%...
appveyor DownloadFile http://kent.dl.sourceforge.net/project/msys2/Base/%MSYS2_ARCH%/%MSYS2_BASE%

SET MSYS2_PATH=c:\msys2
ECHO.Installing MSYS2...
mkdir %MSYS2_PATH%
7z x %APPVEYOR_BUILD_FOLDER%\%MSYS2_BASE% -o%MSYS2_PATH% -so | 7z x -aoa -si -ttar> nul
ECHO.Updating MSYS2...
(
	echo./usr/bin/pacman --noconfirm -Sy pacman
	echo./usr/bin/pacman --noconfirm -Syuu
)>script.sh
SET CHERE_INVOKING=1
%MSYS2_PATH%\usr\bin\bash -lc "./script.sh"
(
	echo.pacman --noconfirm --needed -Sy make unzip git mingw-w64-%MSYS2_ARCH%-cmake

	echo.exit
)>script.sh
%MSYS2_PATH%\usr\bin\bash -lc "./script.sh"

%MSYS2_PATH%\autorebase.bat > nul
