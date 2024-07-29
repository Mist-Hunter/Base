#!/bin/bash.
# From: https://github.com/imthenachoman/How-To-Secure-A-Linux-Server#securing-proc 
# /proc mounted with hidepid=2 so users can only see information about their processes
# FIXME: Stop using hidepid=2 (hidepid=1 is known to not work at all). If you were using hidepid=2, make sure to remove gid=XXX as well. > https://access.redhat.com/solutions/6704531
cp --preserve /etc/fstab /etc/fstab.$(date +"%Y%m%d%H%M%S")
# TODO: Check that hidepid=2 isn't already present
echo -e "\nproc     /proc     proc     defaults,hidepid=2     0     0         # added by $(whoami) on $(date +"%Y-%m-%d @ %H:%M:%S")" | tee -a /etc/fstab

