Apothecary 
==========

This is the [OpenFrameworks](http://openframeworks.cc) library apothecary. It mixes formulas and potions to build and update the C/C++ lib dependencies.

This repository builds all the openFrameworks libraries through test servers and stores them. 

## Build status



Platform                     | Master branch  
-----------------------------|:----------------------------------------
Windows MSYS2 32bits         | [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/1)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master)
Windows MSYS2 64bits         | [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/2)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master)
Windows Visual Studio 32bits | [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/7)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/8)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/9)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/10)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master)
Windows Visual Studio 64bits | [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/3)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/4)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/5)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master) [![Build status](https://appveyor-matrix-badges.herokuapp.com/repos/arturoc/apothecary/branch/master/6)](https://ci.appveyor.com/project/arturoc/apothecary/branch/master)
Android         | [![Build-android](https://github.com/openframeworks/apothecary/workflows/build-android/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Linux         | [![build-linux64](https://github.com/openframeworks/apothecary/workflows/build-linux64/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Linux armv6v/armv7        | [![build-linux-arm](https://github.com/openframeworks/apothecary/workflows/build-linux-arm/badge.svg)](https://github.com/openframeworks/apothecary/actions)
Emscripten        | [![build-emscripten](https://github.com/openframeworks/apothecary/workflows/build-emscripten/badge.svg)](https://github.com/openframeworks/apothecary/actions)
macOS / iOS / tvOS        | [![build-macos](https://github.com/openframeworks/apothecary/workflows/build-macos/badge.svg)](https://github.com/openframeworks/apothecary/actions)

## Built Libraries
Updates on master branch are automatically pushed to [http://ci.openframeworks.cc/libs/ ](http://ci.openframeworks.cc/libs/ ), and downloaded by running the `download_libs.sh` scripts in [openFrameworks if working from git](https://github.com/openframeworks/apothecary/#developers).

## Run locally
#### Using Docker
To run the scripts locally, we have created a set of Docker images to replicate the setup on Travis. Read more in [/docker](/docker/README.md). 

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
