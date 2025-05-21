#!/bin/bash
# https://wiki.debian.org/LXQt

apt install --no-install-recommends \
    xserver-xorg-core \
    lxqt-core \
    lxqt-themes \
    lxqt-config \
    lxqt-notificationd \
    qterminal \
    openbox \
    emptty

# Remove
# HexChat, FireFox ESR