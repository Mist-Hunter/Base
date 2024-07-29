#!/bin/bash
# With help from ChatGPT

# Strictly speaking, those packages (linux-image-amd64, linux-headers-amd64) aren't necessary, however at least the image package is highly recommended during upgrades to ensure that your kernel is upgraded.

# Get the name of the current Linux kernel
current_kernel=$(uname -r)
# Get the list of installed Linux kernels
kernels=$(dpkg --list | egrep -i 'linux-image|linux-headers' | awk '/ii/{ print $2}')
kernels=$(echo "$kernels" | grep -v "$current_kernel" | grep -v "linux-image-amd64")

echo "apt, debian, kernelPurge.sh: Keeping only newest kernel! Purging $kernels."
# Remove all kernels except the current one
for kernel in $kernels; do
  apt --purge remove "$kernel" -y
done

