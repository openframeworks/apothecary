#!/bin/bash

docker exec -i emscripten apt update
docker exec -i emscripten apt install -y coreutils libboost-tools-dev
docker exec -i emscripten apt install -y rsync
docker exec -i emscripten apt install -y gperf
docker exec -i emscripten apt install -y ccache
docker exec -i emscripten sh -c "echo \$PATH"

# DOCKER_HOME=$(docker exec -i emscripten 'echo $HOME')
# docker exec -i emscripten mkdir $DOCKER_HOME/bin

# EMMAKE=$(docker exec -i emscripten which emmake)
# docker exec -i emscripten sh -c "echo #!/usr/bin/env bash > $DOCKER_HOME/bin/emmake"
# docker exec -i emscripten sh -c "echo $EMMAKE sh -c 'CXX=\"ccache \$CXX\" \$1' >> $DOCKER_HOME/bin/emmake"
# docker exec -i emscripten cat $DOCKER_HOME/bin/emmake

# EMCMAKE=$(docker exec -i emscripten which emcmake)
# docker exec -i emscripten sh -c "echo #!/usr/bin/env bash > $DOCKER_HOME/bin/emcmake"
# docker exec -i emscripten sh -c "echo $EMCMAKE sh -c 'CXX=\"ccache \$CXX\" \$1' >> $DOCKER_HOME/bin/emcmake"
# docker exec -i emscripten cat $DOCKER_HOME/bin/emcmake
