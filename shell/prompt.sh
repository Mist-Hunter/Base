#!/bin/bash

# Refference: https://ss64.com/bash/syntax-prompt.html

# DEV_TYPE is expected system variable see /apt/virt-what

# user coloring based on privillage level. Root is red, anything else green.

# hostname coloring based DEV_TYPE. Color on left, DEV_TYPE value on right
# brown = lxc
# green = kvm,,xen,xen-hvm,aws
# red   = x86_64,aarch64,x86_64,armv7l

# FIXME verify DEV_TYPE exists and veriy PS1 doesn't

# TODO @ symbol could related to matching subnet color code (red, orange etc)

# Define colors
RED='\[\033[01;31m\]'
GREEN='\[\033[01;32m\]'
BROWN='\[\033[01;33m\]'
LIGHT_BLUE='\[\033[1;34m\]'
DARK_GRAY='\[\033[1;30m\]'
BOLD_YELLOW='\[\033[1;33m\]'
DEFAULT='\[\033[00m\]'

# Get the current username and hostname
USER=$(whoami)
HOSTNAME=$(hostname)

# Determine user color
if [ "$USER" == "root" ]; then
    USER_COLOR=$RED
else
    USER_COLOR=$GREEN
fi

# Determine hostname color based on DEV_TYPE
case "$DEV_TYPE" in
    *lxc*)
        HOSTNAME_COLOR=$BROWN
        ;;
    *kvm* | *xen* | *xen-hvm* | *aws*)
        HOSTNAME_COLOR=$GREEN
        ;;
    *x86_64* | *aarch64* | *armv7l*)
        HOSTNAME_COLOR=$RED
        ;;
    *)
        HOSTNAME_COLOR=$DEFAULT
        ;;
esac

# Set the prompt (PS1) with colored username and hostname
export PS1="${USER_COLOR}\u${DARK_GRAY}@\[\033[00m\]${HOSTNAME_COLOR}\h\[\033[00m\] ${LIGHT_BLUE}\w${DEFAULT} ${BOLD_YELLOW}\$${DEFAULT} "
