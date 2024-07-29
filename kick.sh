# This file in intended to:
## - write base ENV varibles that can be sourced by other scripts
## - download and source help functions
## - fire off initial configuration including sysctl configuration

# /etc/environment
# /root/.bashrc
# /root/.config/
#   ├── global.env
#   ├── docker.env
#   ├── smtp.env
#   ├── snmp.w
#   └── git.env

# Phase 1 ===============================================

GIT_PROTOCOL=""
GIT_SERVER=""
GIT_USER=""

apt update
apt install wget -y

# Prep-CT
# source <(wget -O - $GIT_PROTOCOL://$GIT_SERVER/$GIT_USER/Systems/raw/branch/master/debian-base/prepCT.sh)

# Prep-VM
source <(wget -O - $GIT_PROTOCOL://$GIT_SERVER/$GIT_USER/Systems/raw/branch/master/debian-base/prepVM.sh)

# Phase 2 ===============================================

GIT_PROTOCOL=""
GIT_SERVER=""
GIT_USER=""

# Helper script(s)
source <(wget -O -  https://gist.githubusercontent.com/$GIT_USER/610e3b5451a4970964cb21bf796541b7/raw/bcdf7aec3a80ea615b26d18d56a798413150f2d4/env_writer.sh)

ENV_PATH="/root/.config"
ENV_GLOBAL="$ENV_PATH/global.env"
mkdir -p $ENV_PATH

# System Variables -------------------------------------------------------------------------------
cat <<EOT > /etc/environment

# Localization
export TZ="America/Vancouver"
export LANG="en_US.UTF-8" 

# Shell
export SHELL="/bin/bash"
export EDITOR="nano"

# Modproble Blacklist
export MOD_BLACKLIST="/etc/modprobe.d/blacklist.conf"

EOT

# User Variables -------------------------------------------------------------------------------
env_writer \
--service 'Global' \
--content '
# Filepaths
export BASE="/root"
export SCRIPTS="/root/scripts"
export CONFIGS="/root/.config"
export LOGS="/var/log"
'

# IP Tables / Network
env_writer \
--service 'Network' \
--content '
# System 
export DOMAIN      = lan                          # Referenced by scripts that need to know the local or remote domain extension
export FIREWALL    = iptables                     # Referenced by scripts that need to know what, if any firewall is intended to be used
export REV_PROXY   = "172.27.0.1"                 # Local Reverse Proxy IP (if used)

# Trusted Subnets
export GREEN       = "10.0.0.0/24"                # Subnet treated with high trust
export CYAN        = "192.168.111.0/24"           # Semi-trusted Subnet

# Untrusted Subnets
export ORANGE      = "172.27.0.0/24"              # DMZ Subnet
export BLUE        = "192.168.0.0/24"             # Guest Subnet

# Isolated Subnets
export BROWN       = "192.168.7.0/24"             # Isolated Subnet

# VPN Subnets
export VPN         = "10.2.0.0/24"                # Subnet for VPN clients, similar to GREEN
export BLACK       = "172.27.7.0/24"              # VPN outbound international
export GRAY        = "172.27.9.0/24"              # VPN outbound national

# Alias for RFC1918 Local area subnets
export RFC1918     = "192.168.0.0/16,172.16.0.0/12,10.0.0.0/8"  
'

# SMTP Secrets
env_writer \
--service 'SMTP' \
--content '
export ADMIN_EMAIL=""
export SMTP_USER=""
export SMTP_PASS=""
export SMTP_SERVER=""
export SMTP_PORT="587"
'

# SNMP
env_writer \
--service 'SNMP' \
--content '
export SNMP_AGENT_PORT="161"                        
export SNMP_POLLER=""
export SNMP_LOCATION=""
'

# Docker -----------------------------------------------------------------------------------------
env_writer \
--source \
--service 'Docker' \
--content '
# Paths
export DOCKER_ROOT_DIR=/var/lib/docker
export DOCKER_MOUNTS="$DOCKER_ROOT_DIR/mounts"
export DOCKER_VOLUMES="$DOCKER_ROOT_DIR/volumes"
export DOCKER_CONFIGS="/etc/docker/containers"

# Docker
export DOCKER_REGISTRY_MIRROR=""

# Portainer
export PORTAINER_SERVER=""
export PORTAINER_HOST=""
'

# Restic Info
env_writer \
--service 'Restic' \
--content '
# Server Details, REST: https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#rest-server
RESTIC_SERVER_URL=""
RESTIC_SERVER_PORT=443
RESTIC_SERVER_TYPE="Rest"

# Server User Credentials
RESTIC_SERVER_USER_NAME=""
RESTIC_SERVER_USER_PASSWORD=""
RESTIC_SERVER_BASE_REPO_URL="rest:https://$RESTIC_SERVER_USER_NAME:$RESTIC_SERVER_USER_PASSWORD@$RESTIC_SERVER_URL"  #/$RESTIC_SERVER_USER_NAME-$LABEL

# Default Repo Password
RESTIC_REPO_DEFAULT_PASSWORD=""
'

# Git -----------------------------------------------------------------------------------------------
env_writer \
--service 'GIT' \
--content "
# Git
export GIT_SERVER=$GIT_SERVER
export GIT_USER=$GIT_USER

# Specific Repo SSH aliases
export GIT_APT_URL="git@$GIT_SERVER-Apt:/$GIT_USER"
export GIT_DOCKER_URL="git@$GIT_SERVER-Docker:/$GIT_USER"
"

# SSH Path (for GIT aliases)
SSH_PATH="/root/.ssh"
mkdir -p $SSH_PATH

### Identity Files
cat <<EOT > $SSH_PATH/gitRepo-Apt-deploy.key
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

cat <<EOT > $SSH_PATH/gitRepo-Docker-deploy.key
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

### Aliases
cat <<EOT >> /root/.ssh/config
# Github SSH Server Aliases ------------------------------------
Host $GIT_SERVER-Apt
    Hostname $GIT_SERVER
    IdentityFile=$SSH_PATH/gitRepo-Apt-deploy.key

Host $GIT_SERVER-Docker
    Hostname $GIT_SERVER
    IdentityFile=$SSH_PATH/gitRepo-Docker-deploy.key

EOT

# Fix permission all all the keys and config above
chmod -R 700 $SSH_PATH

# First time Git Setup on Clients
apt install git openssh-client -y

git clone $GIT_APT_URL/Apt.git $SCRIPTS/apt

# Bash RC -----------------------------------------------------------------------------------------------
cat <<EOT >> /root/.bashrc

# Environmental Variables Global list
export ENV_GLOBAL="$ENV_GLOBAL"
source $ENV_GLOBAL

# APT aliases
aptUP=$SCRIPTS/debian/update.sh
update=$SCRIPTS/debian/update.sh
clean=$SCRIPTS/clean.sh

EOT
# Reload .bashrc
. ~/.bashrc

# Debian Base, don't clone !! Systems !!
source <(wget -O - $GIT_PROTOCOL://$GIT_SERVER/$GIT_USER/Systems/raw/branch/master/debian-base/up.sh)