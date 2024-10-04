#!/bin/bash

source $ENV_NETWORK

# Firehol_1 https://iplists.firehol.org/?ipset=firehol_level1
## Download @ https://iplists.firehol.org/files/firehol_level1.netset
## Updates @ https://github.com/firehol/blocklist-ipsets/commits/master/firehol_level1.netset

# URLs and paths
firehol_lable="FireHOL_lvl_1"
netset_file="${FIREHOL_NETSETS_PATH}/$firehol_lable.netset"
netset_url="https://iplists.firehol.org/files/firehol_level1.netset"
github_api_url="https://api.github.com/repos/firehol/blocklist-ipsets/commits?path=firehol_level1.netset&per_page=1"
firehol_ipset_apply_script="$SCRIPTS/base/firewall/firehol_ipset_apply.sh"  # Update with the correct path

mkdir -p $FIREHOL_NETSETS_PATH

# Function to download the latest .netset file
download_netset() {
    echo "Downloading the latest .netset file..."
    curl -s -o "$netset_file" "$netset_url"
    if [ $? -ne 0 ]; then
        echo "Error downloading file from $netset_url"
        exit 1
    fi
}

# Function to check if the remote file is newer than the local file
check_for_update() {
    echo "Checking for updates..."
    
    # Get the latest commit SHA from GitHub API
    latest_commit=$(curl -s "$github_api_url" | grep -m 1 '"sha":' | cut -d '"' -f 4)
    
    # Get the local file's last update SHA (stored in the first line of the file)
    if [ -f "$netset_file" ]; then
        local_sha=$(head -n 1 "$netset_file" | grep -oP '(?<=# SHA: ).*')
    else
        local_sha=""
    fi
    
    # Compare SHAs
    if [ "$latest_commit" != "$local_sha" ]; then
        echo "New version available."
        return 0  # Indicates that an update is needed
    else
        echo "No update needed."
        return 1  # Indicates that no update is needed
    fi
}

# Main script logic
if check_for_update; then
    download_netset
    # Add the latest commit SHA to the top of the file
    sed -i "1i# SHA: $latest_commit" "$netset_file"
    echo "Applying the new .netset file..."
    firehol_ip_array=$(cat "$netset_file" | sed '/^#/d' | tr '\n' ' ' | sed 's/  */ /g')
    ipset_process --label "FireHOL_lvl_1" --hash_type "net" --ip_array $firehol_ip_array
else
    echo "Local file is up-to-date."
    # TODO check if ipset is empty
fi
