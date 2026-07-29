#!/usr/bin/env bash

# This script is used to check if your kernel is updated or needs a restart!
# Usage: ./kernelCheck
# TRUE = Your kernel is updated!
# FALSE = Your kernel needs a restart to update!

actualVer=$(uname -r)
lastVer=$(dpkg --list 'linux-image-[0-9]*' | awk '/^ii/{print $2}' | sed 's/^linux-image-//' | sort -V | tail -n 1)

if [ $actualVer == $lastVer ]; then
    echo "TRUE"
else
    echo "FALSE"
fi