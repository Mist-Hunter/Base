#! /bin/bash

DEV_TYPE=$(virt-what)
if [[ $DEV_TYPE = "" ]]; then
    # If physical, replace with Proc architecture
    DEV_TYPE=$(uname -m)
fi
echo $DEV_TYPE