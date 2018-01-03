# Based on https://docs.travis-ci.com/user/common-build-problems/#Troubleshooting-Locally-in-a-Docker-Image
FROM travisci/ci-garnet:packer-1513287432-2ffda03

ENV TRAVIS_BUILD_DIR /root

ENV TARGET emscripten

# Copied from the build logs in travis
RUN sudo -E apt-add-repository -y "ppa:ubuntu-toolchain-r/test"
RUN sudo -E apt-get -yq update
RUN sudo -E apt-get -yq --no-install-suggests --no-install-recommends --force-yes install libstdc++6 gcc-4.9 realpath coreutils libboost-tools-dev gperf

# Install cmake 3.9.2 (preinstalled on travis)
RUN wget http://www.cmake.org/files/v3.9/cmake-3.9.2.tar.gz
RUN tar xf cmake-3.9.2.tar.gz
RUN cd cmake-3.9.2; ./configure; make -j12; make install
RUN cmake --version

# Run install.sh installing
ADD scripts/ /root/scripts/

RUN chmod +x $TRAVIS_BUILD_DIR/scripts/emscripten/install.sh
RUN cd $TRAVIS_BUILD_DIR; ./scripts/emscripten/install.sh

