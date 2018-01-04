# Based on https://docs.travis-ci.com/user/common-build-problems/#Troubleshooting-Locally-in-a-Docker-Image
FROM travisci/ci-garnet:packer-1513287432-2ffda03

ENV TRAVIS_BUILD_DIR /root

ENV TARGET linux
ENV OPT gcc5

# Run install.sh installing
ADD scripts/ /root/scripts/

RUN chmod +x $TRAVIS_BUILD_DIR/scripts/linux/install.sh
RUN cd $TRAVIS_BUILD_DIR; ./scripts/linux/install.sh $OPT

