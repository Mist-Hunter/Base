#!/bin/bash

# Step 1: Install virt-what
apt install virt-what -y

# Step 2: Capture output of virt-what

DEV_TYPE=$(virt-what)
if [[ $DEV_TYPE = "" ]]; then
    # If physical, replace with Proc architecture
    DEV_TYPE=$(uname -m)
fi

# Step 3: Check if DEV_TYPE is already in /etc/environment
if ! grep -q "^DEV_TYPE=" /etc/environment; then
    echo "Device type from 'virt-what'" >> /etc/environment
    echo "DEV_TYPE=$DEV_TYPE" >> /etc/environment
    echo >> /etc/environment
    echo "DEV_TYPE has been added to /etc/environment."
else
    echo "DEV_TYPE is already present in /etc/environment."
fi

apt remove virt-what