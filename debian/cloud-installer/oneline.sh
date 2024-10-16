#!/bin/bash

source $ENV_GIT

# Systems/cloud-ubuntu/prepOracleVM.sh
# https://github.com/bohanyang/debi?tab=readme-ov-file#available-options

# NOTE !! Remove default GRUB password from systems/preVM.sh
rm -f /etc/grub.d/40_custom && sed -i '/set superusers="root"/d' /etc/default/grub && sed -i '/password_pbkdf2 root/d' /etc/default/grub && update-grub

# if Gitea
# curl -fLO https://$GIT_SERVER_FQDN/$GIT_USER/Base/raw/branch/main/debian/cloud-installer/install.sh

# if Github
GIT_SERVER_FQDN="raw.githubusercontent.com"
curl -fLO https://$GIT_SERVER_FQDN/$GIT_USER/Base/main/debian/cloud-installer/install.sh  

chmod a+rx install.sh

./install.sh \
--ethx \
--version 12 \
--hostname debian-preseed \
--timezone America/Los_Angeles \
--filesystem ext4 \
--serial \
--sudo-with-password \
--user user \
--password password \
--dry-run
