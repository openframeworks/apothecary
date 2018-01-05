To run docker locally, these docker images can be used to replicate the setup on Travis. Its usefull for testing the setup without waiting for travis to build.


Build docker image from Dockverfile manually by running

```
docker build -t apothecary:linux -f docker/linux/Dockerfile .
docker build -t apothecary:linux.gcc6 -f docker/linux/Dockerfile.gcc6 .
docker build -t apothecary:linux.gcc5 -f docker/linux/Dockerfile.gcc5 .
docker build -t apothecary:android -f docker/android/Dockerfile .
docker build -t apothecary:emscripten -f docker/emscripten/Dockerfile .
```

Then run apothecary with something like this

```
docker run -v $(pwd):/apothecary apothecary:android ./apothecary/apothecary/apothecary -t android -a armv7 -j 6 update opencv
```

Or the entire build script using 

```
docker run -v $(pwd):/apothecary -e "PARALLEL=12" apothecary:linux.gcc5   apothecary/scripts/build.sh 

docker run -v $(pwd):/apothecary -e "PARALLEL=12" -e"ARCH=x86" apothecary:android   apothecary/scripts/build.sh 

docker run -v $(pwd):/apothecary -e "PARALLEL=12" apothecary:emscripten   apothecary/scripts/build.sh 
```