#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

if [ -z "${NO_FORCE+x}" ]; then
    export FORCE="-f"
else
    export FORCE=""
fi


#!/bin/bash

# Configuration
mkdir -p out
for zip in out/*.zip; do
  echo "Extracting $zip..."
  unzip -o "$zip" -d out/
done
echo "Extraction complete."
rm out/*.zip
for tarball in out/*.tar.bz2; do
  echo "Extracting $tarball..."
  tar -xjf "$tarball" -C out/
done
echo ".tar.bz2 extraction complete."
rm -f out/*.tar.bz2 
