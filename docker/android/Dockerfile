FROM ubuntu:16.04

ENV DOCKER true
ENV ANDROID_HOME /opt/android
ENV NDK_ROOT /opt/ndk_dir

RUN apt-get update && apt install -y \
    git \
    software-properties-common \ 
    wget \
    openjdk-8-jre-headless \ 
    unzip
    
RUN git clone --depth 1 http://github.com/openFrameworks/openFrameworks.git
RUN ./openFrameworks/scripts/linux/ubuntu/install_dependencies.sh

RUN mkdir $ANDROID_HOME
RUN cd $ANDROID_HOME && wget -q http://dl.google.com/android/repository/sdk-tools-linux-3859397.zip -O android-sdk.zip
RUN cd $ANDROID_HOME && unzip android-sdk.zip && rm -f android-sdk.zip
ENV PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin

RUN echo y | sdkmanager "platform-tools"
RUN echo y | sdkmanager "platforms;android-26"

RUN mkdir $NDK_ROOT
RUN cd $NDK_ROOT && wget -q http://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip -O android-ndk.zip
RUN cd $NDK_ROOT && unzip android-ndk.zip && rm -f android-ndk.zip
