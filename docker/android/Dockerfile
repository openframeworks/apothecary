FROM ubuntu:14.04

ENV DOCKER true
ENV ANDROID_HOME /opt/android
ENV TRAVIS_BUILD_DIR /root/

RUN apt-get update && apt install -y \
    software-properties-common \ 
    wget \
    unzip \
    build-essential \
    autoconf \
    libtool \
    libboost-tools-dev \
    gperf \
    curl

# Install Java 8
RUN apt-add-repository ppa:webupd8team/java
RUN apt-get update
RUN echo Y | apt-get install -y oracle-java8-installer

# Install android sdk
RUN mkdir $ANDROID_HOME
RUN cd $ANDROID_HOME && wget -q http://dl.google.com/android/repository/sdk-tools-linux-3859397.zip -O android-sdk.zip
RUN cd $ANDROID_HOME && unzip android-sdk.zip && rm -f android-sdk.zip
ENV PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin

RUN echo Y | sdkmanager "platform-tools"
RUN echo Y | sdkmanager "platforms;android-26"

# Run install.sh installing ndk and cmake
ADD scripts/android/install.sh /root/install.sh
ADD scripts/android/install-cmake.sh /root/scripts/android/install-cmake.sh

RUN chmod +x /root/install.sh
RUN cd $TRAVIS_BUILD_DIR; ./install.sh