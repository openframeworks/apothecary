# Based on https://docs.travis-ci.com/user/common-build-problems/#Troubleshooting-Locally-in-a-Docker-Image
FROM travisci/ci-garnet:packer-1513287432-2ffda03

ENV TRAVIS_BUILD_DIR /root
ENV TARGET=android

# Install more recent version of cmake 
RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1.tar.gz
RUN tar xf cmake-3.22.1.tar.gz
RUN cd cmake-3.22.1; ./configure; make -j12; make install
RUN cmake --version

RUN sudo apt-get update -q
RUN sudo apt-get install -y libboost-tools-dev gperf realpath


# Run install.sh installing ndk
ADD scripts/ /root/scripts/
RUN chmod +x $TRAVIS_BUILD_DIR/scripts/android/install.sh
RUN cd $TRAVIS_BUILD_DIR; ./scripts/android/install.sh