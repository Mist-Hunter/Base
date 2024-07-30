#!/bin/bash

source $ENV_GIT
# FIXME can't user github.com /raw/ anymore?
GIT_SERVER="raw.githubusercontent.com"

# Systems/cloud-ubuntu/prepOracleVM.sh
# https://github.com/bohanyang/debi?tab=readme-ov-file#available-options

# NOTE !! Remove default GRUB password from systems/preVM.sh
rm -f /etc/grub.d/40_custom && sed -i '/set superusers="root"/d' /etc/default/grub && sed -i '/password_pbkdf2 root/d' /etc/default/grub && update-grub

curl -fLO https://$GIT_SERVER/$GIT_USER/Base/main/debian/cloud-installer/install.sh && chmod a+rx install.sh && \
./install.sh \
--ethx \
--version 12 \
--hostname ox2 \
--timezone America/Los_Angeles \
--filesystem ext4 \
--serial \
--sudo-with-password \
--user user \
--password password \
--dry-run
