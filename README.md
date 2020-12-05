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
Linux 64                   | [![Linux 64 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="linux"%20OPT="gcc4"&label=gcc4&branch=master)](https://travis-ci.org/openframeworks/apothecary) [![Linux 64 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="linux"%20OPT="gcc5"&label=gcc5&branch=master)](https://travis-ci.org/openframeworks/apothecary) [![Linux 64 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="linux"%20OPT="gcc6"&label=gcc6&branch=master)](https://travis-ci.org/openframeworks/apothecary)
Linux armv6l                 | [![Linux armv6l Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="linuxarmv6l"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
Linux armv7l                 | [![Linux armv7l Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="linuxarmv7l"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
Emscripten                   | [![Emscripten Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="emscripten"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
macos                        | [![macos Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="osx"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
iOS                          | [![iOS Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="ios"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
tvos                         | [![tvos Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="tvos"&label=build&branch=master)](https://travis-ci.org/openframeworks/apothecary)
Android                      | [![Android Arm7 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="android"%20ARCH="armv7"&label=arm7&branch=master)](https://travis-ci.org/openframeworks/apothecary) [![Android Arm64 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="android"%20ARCH="arm64"&label=arm64&branch=master)](https://travis-ci.org/openframeworks/apothecary) [![Android x86 Build Status](http://badges.herokuapp.com/travis/openframeworks/apothecary?env=TARGET="android"%20ARCH="x86"&label=x86&branch=master)](https://travis-ci.org/openframeworks/apothecary)



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
