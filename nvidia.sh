#!/bin/bash

# Main focus is getting the driver installed.

# Driver version: nvidia-smi. https://gitlab.com/nvidia/container-images/cuda/-/blob/master/doc/support-policy.md

# Headless Drivers? https://linuxhint.com/install-nvidia-gpu-drivers-headless-debian-11-server/ , https://linuxhint.com/install-nvidia-gpu-drivers-headless-ubuntu-server-22-04-lts/

# https://wiki.debian.org/NvidiaGraphicsDrivers >> Bookworm: https://wiki.debian.org/NvidiaGraphicsDrivers#Debian_12_.22Bookworm.22
# Note Prereq: https://wiki.debian.org/NvidiaGraphicsDrivers#Prerequisites ,the build env adds about 8g

# Blacklist. Un-blacklist "drm: provides Direct Rendering Manager support"

if lspci | grep 'NVIDIA Corporation'; then

echo "system, debian-base, nvidia.sh: installing NVIDIA Drivers."

nvidia_sources="/etc/apt/sources.list.d/nvidia.list"
if [ -e nvidia_sources ]; then
echo "The file $nvidia_sources exists."
else
echo "The file $nvidia_sources does not exist, creating"
cat << EOT > $nvidia_sources
# Refference: https://wiki.debian.org/NvidiaGraphicsDrivers#Debian_12_.22Bookworm.22
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
EOT
fi
apt update

echo "Unblocking DRM kernel mod required for driver."
MOD_BLACKLIST="/etc/modprobe.d/blacklist.conf"
sed -i '/drm/d' $MOD_BLACKLIST
sed -i -e '/^$/N;/^\n$/D' $MOD_BLACKLIST # Remove extra empty lines
update-initramfs -u

# linux-headers-amd64 = 248 Mb
# nvidia-driver --no-install-recommends = 596 Mb

apt install firmware-misc-nonfree -y #<--- Mentioned here. Seems like system was unstable without it. Getting Kernel panics on umount cifs shutdown
apt install linux-headers-amd64 nvidia-driver nvidia-smi --no-install-recommends # <-- 2023-09-01 > 660 MB

# apt install nvidia-cude-dev nvidia-cuda-toolkit

# nvidia-cude-dev = 3 GB
# nvidia-cuda-toolkit 200 Mb

# TODO: X-Server being installed?

# Install NVTOP https://github.com/XuehaiPan/nvitop
apt install nvtop -y

# Test
echo "NVIDIA-SMI should show the GPU now, running."
nvidia-smi

else
    echo "system, debian-base, nvidia.sh: NVIDA GPU not present, skipping."
fi