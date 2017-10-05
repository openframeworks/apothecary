Build docker image by running

```
docker build -t apothecary/android docker/android/
```

Run apothecary 

```
docker run -v $(PWD):/apothecary apothecary/android ./apothecary/apothecary/apothecary -t android -a armv7 update opencv
```