
Run apothecary from network image

```
docker run -v $(PWD):/apothecary openframeworks/apothecary:android ./apothecary/apothecary/apothecary -t android -a armv7 update opencv
```


Build docker image from Dockverfile by running

```
docker build -t openframeworks/apothecary:android docker/android/
```

Run apothecary 

```
docker run -v $(PWD):/apothecary openframeworks/apothecary:android ./apothecary/apothecary/apothecary -t android -a armv7 update opencv
```


Publish to docker hub

```
docker tag apothecary/android openframeworks/apothecary:android
docker push openframeworks/apothecary:android
```