Apothecary 
==========

This is the [openFrameworks](http://openframeworks.cc) library apothecary. It mixes formulas and potions to build and update the C/C++ lib dependencies.

This repository builds all the openFrameworks libraries through test servers and stores them. 

## Build status

|                  |    Building    |    INFO    |
|-----------------:|:--------------:|:----------:|
| Windows 64       |    complete    |   VS2022   |
| Windows ARM64    |    complete    |   VS2022   |
| Windows ARM64EC  |    complete    |   VS2022   |
| Linux            |    complete    |            |
| Linux armv6      |    complete    |            |
| Linux armv7      |    complete    |            |
| Linux arm64      |                |            |
| MacOS 64         |    complete    |            |
| MacOS ARM64      |    complete    |            |
| Emscripten       |    complete    |            |
| iOS ARM64        |    complete    |            |
| iOS X86_64 SIM   |    complete    |            |
| iOS ARM64 SIM    |    complete    |            |
| tvOS ARM64       |    complete    |            |
| tvOS X86_64 SIM  |    complete    |            |
| tvOS ARM64 SIM   |    complete    |            |
| XROS ARM64       |    complete    |            |
| XROS X86_64 SIM  |    complete    |            |
| XROS ARM64 SIM   |    complete    |            |
| MAC CATOS ARM64  |    complete    |            |
| MAC CATOS x86_64 |    complete    |            |
| Android ARM64    |    complete    |   NDK 23   |
| Android X86_64   |    complete    |   NDK 23   |
| Android X86      |    complete    |   NDK 23   |
| Android ARMV7    |    complete    |   NDK 23   |

## Built Libraries
Updates on master branch are automatically pushed to [Nightly Releases](https://github.com/openframeworks/apothecary/releases), and downloaded by running the `download_libs.sh` scripts in [openFrameworks if working from git](https://github.com/openframeworks/apothecary/#developers).


### Setup your Environment to build apothecary
For your target type, run the script/osx/install.sh

### Build scripts for target
For your target type, run the build and deploy scripts. This will build all the calculated formulaes required for type and install them in output dir . For macOS:
```
scripts/osx/build_and_deploy_all.sh
```

Build VS 2022:
```
scripts/vs/build_and_deploy_all.sh
```

Build iOS:
```
scripts/ios/build_and_deploy_all.sh
```

Build Android:
```
scripts/android/build_android_arm64.sh
scripts/android/build_android_armv7.sh
scripts/android/build_android_x86.sh
scripts/android/build_android_x86_64.sh
```


#### Running directly
To build one of the dependencies, you can run a command like this to compile OpenCV on OSX`
```
./apothecary/apothecary -t osx -a64 -j 6 update opencv
```

To build all of the dependencies, you can run a command like this for Android
```
./apothecary/apothecary -t android -a arm64 update core
./apothecary/apothecary -t android -a x86_64 update addons
```

To build all of the dependencies, you can run a command like this for macOS 
```
./apothecary/apothecary -t osx -a arm64 update core
./apothecary/apothecary -t osx -a x86_64 update core
```

To build all of the dependencies, you can run a command like this for VS 
```
./apothecary/apothecary -t vs -a arm64 update core
./apothecary/apothecary -t vs -a x86_64 update core
```

To build all of the dependencies, you can run a command like this for VS 
```
./apothecary/apothecary -t emscripten update core
./apothecary/apothecary -t emscripten update addons
```

See the help section for more options
```
./apothecary/apothecary --help
```


------------

2014 openFrameworks team
2013 Dan Wilcox <danomatika@gmail.com> supported by the CMU [Studio for Creative Inquiry](http://studioforcreativeinquiry.org/)
2024 Dan Rosser
