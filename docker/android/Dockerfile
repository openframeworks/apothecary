FROM ubuntu:16.04

RUN apt-get update && apt install -y \
    git \
    software-properties-common \ 
    wget \
    openjdk-8-jre-headless
    
RUN git clone --depth 1 http://github.com/openFrameworks/openFrameworks.git
RUN ./openFrameworks/scripts/linux/ubuntu/install_dependencies.sh

RUN wget http://dl.google.com/android/repository/sdk-tools-linux-3859397.zip
RUN unzip sdk-tools-linux-3859397.zip
RUN ./tools/bin/sdkmanager

# RUN wget http://dl.google.com/android/repository/android-ndk-r15c-linux-x86_64.zip