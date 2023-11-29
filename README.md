Apothecary 
==========

This is the [OpenFrameworks](http://openframeworks.cc) library apothecary. It mixes formulas and potions to build and update the C/C++ lib dependencies.

This repository builds all the openFrameworks libraries through test servers and stores them. 

## Build status



Platform                     | Master branch  
-----------------------------|:----------------------------------------
Windows MSYS2         | [![Build status](https://github.com/openframeworks/apothecary/workflows/build-msys2/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Windows Visual Studio | [![Build status](https://github.com/openframeworks/apothecary/workflows/build-vs/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Android         | [![Build-android](https://github.com/openframeworks/apothecary/workflows/build-android/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Linux         | [![build-linux64](https://github.com/openframeworks/apothecary/workflows/build-linux64/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Linux armv6v/aarch64        | [![build-linux-arm](https://github.com/openframeworks/apothecary/workflows/build-linux-arm/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Emscripten        | [![build-emscripten](https://github.com/openframeworks/apothecary/workflows/build-emscripten/badge.svg)](https://github.com/openframeworks/apothecary/actions)
macOS / iOS / tvOS        | [![build-macos](https://github.com/openframeworks/apothecary/workflows/build-macos/badge.svg)](https://github.com/openframeworks/apothecary/actions)

## Built Libraries
Updates on master branch are automatically pushed to [Nightly Releases](https://github.com/openframeworks/apothecary/releases), and downloaded by running the `download_libs.sh` scripts in [openFrameworks if working from git](https://github.com/openframeworks/apothecary/#developers).

#### Running directly
To build one of the dependencies, you can run a command like this to compile OpenCV on OSX`
```
./apothecary/apothecary -t osx -j 6 update opencv
```

See the help section for more options
```
./apothecary/apothecary --help
```


------------

2014 OpenFrameworks team   
2013 Dan Wilcox <danomatika@gmail.com> supported by the CMU [Studio for Creative Inquiry](http://studioforcreativeinquiry.org/)
