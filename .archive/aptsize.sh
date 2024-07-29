#!/bin/bash

# This command retrieves and lists the installed packages along with their disk space usage to facilitate analysis and management of disk space.

total=0; dpkg-query -Wf '${Installed-Size}\t${Package}\n' | awk '{size = $1 * 1024; total += size; printf "%.2f MB\t%s\n", size / (1024 * 1024), $2} END {printf "\nTotal Disk Space Usage: %.2f MB\n", total / (1024 * 1024)}' | sort -nr
