#!/bin/bash
# Sysbench https://linuxhint.com/use-sysbench-for-linux-performance-testing/ , https://blog.knoldus.com/how-to-do-performance-testing-of-linux-machines-sysbench/
apt install sysbench -y

# Hard Drive
sysbench fileio --file-test-mode=seqwr run
sysbench fileio --file-total-size=100G cleanup

# Ram, Hugepages
sysbench memory run
3
# CPU, NUMA
sysbench cpu run

# No difference in performance between kvm64 and host seen.

# Intel QuickSync, the following command gave the same results for 'host' and 'kmv64'
# ls -l /dev/dri
# total 0
# drwxr-xr-x 2 root root      60 Feb 24 07:11 by-path
# crw-rw---- 1 root video 226, 0 Feb 24 07:11 card0

# https://perfectmediaserver.com/advanced/passthrough-igpu-gvtg/