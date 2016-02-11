APOTHECARY_PATH=$(dirname "$0")/../../apothecary
cd $APOTHECARY_PATH
./apothecary update core
cd ..
TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_linux.tar.bz2
tar cjf $TARBALL $(ls  | grep -v apothecary | grep -v scripts)
openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in scripts/id_rsa.enc -out scripts/id_rsa -d
cp scripts/ssh_config ~/.ssh/config
chmod 600 scripts/id_rsa
scp -i scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
ssh -i scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
rm scripts/id_rsa
