@echo off
if "%1"=="Win32" (
	call "%VS140COMNTOOLS%vsvars32.bat"

	echo +++++++++++++++++++++++++++++++++++++++++
	echo +++++++++       Build      ++++++++++++++
	echo +++++++++++++++++++++++++++++++++++++++++

	devenv libpng.sln /Build "LIB Release|x86"

) else (
	if "%1"=="x64" (
		call "%VS140COMNTOOLS%..\..\VC\vcvarsall" amd64

		echo +++++++++++++++++++++++++++++++++++++++++
		echo +++++++++       Build      ++++++++++++++
		echo +++++++++++++++++++++++++++++++++++++++++

		devenv libpng.sln /Build "LIB Release|x64"
	)
)
