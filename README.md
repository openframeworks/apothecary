Apothecary 
==========

This is the [OpenFrameworks](http://openframeworks.cc) library apothecary. It mixes formulas and potions to build and update the C/C++ lib dependencies.

This repository builds all the openFrameworks libraries through test servers and stores them. 

## Build status

Travis-ci Build for: Linux, OSX, iOS, tvOS, Emscripten and Android:    [![Build Status](https://travis-ci.org/openframeworks/apothecary.svg?branch=master)](https://travis-ci.org/openframeworks/apothecary)

Visual Studio and MSYS2: [No Build]


## Built Libraries
Updates on master branch are automatically pushed to [http://ci.openframeworks.cc/libs/ ](http://ci.openframeworks.cc/libs/ ), and downloaded by running the `download_libs.sh` scripts in [openFrameworks if working from git](https://github.com/openframeworks/openFrameworks/#developers).

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
