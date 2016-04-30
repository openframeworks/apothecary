SET MSYS2_BASE=msys2-base-x86_64-%MSYS2_BASEVER%.tar.xz
IF "%APPVEYOR%"=="True" (
  ECHO.Downloading %MSYS2_BASE%...
  appveyor DownloadFile http://kent.dl.sourceforge.net/project/msys2/Base/x86_64/%MSYS2_BASE%
)
SET MSYS2_PATH=c:\msys2
ECHO.Installing MSYS2...
rem mkdir %MSYS2_PATH%
7z x %APPVEYOR_BUILD_FOLDER%\%MSYS2_BASE% -so | 7z x -aoa -si -ttar > nul

move msys64 %MSYS2_PATH%
%MSYS2_PATH%\autorebase.bat > nul

echo %PATH%
ECHO.Updating MSYS2...
(
	echo "PATH is $PATH"
	echo./usr/bin/pacman --noconfirm -Sy pacman
	echo./usr/bin/pacman --noconfirm -Syuu
)>script.sh
SET PATH=%MSYS2_PATH%;%PATH;
SET CHERE_INVOKING=1
%MSYS2_PATH%\usr\bin\bash -lc "./script.sh"
(
	echo "PATH is $PATH"
	echo./usr/bin/pacman --noconfirm --needed -Sy make unzip git mingw-w64-%MSYS2_ARCH%-cmake
	echo.exit
)>script.sh
%MSYS2_PATH%\usr\bin\bash -lc "./script.sh"

rem %MSYS2_PATH%\autorebase.bat > nul
