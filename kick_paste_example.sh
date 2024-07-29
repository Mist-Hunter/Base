# This file in intended to:
## - write base ENV varibles that can be sourced by other scripts
## - download and source help functions
## - fire off initial configuration including sysctl configuration

# /etc/environment
# /root/.ssh
# /root/.bashrc
# /root/.config/
#   ├── global.env
#   ├── docker.env
#   ├── smtp.env
#   ├── snmp.w
#   └── git.env

# Variables and Prep ------------------------------------------------------------------------------

GIT_PROTOCOL=""
GIT_SERVER=""
GIT_USER=""

BASE="/root/"
SCRIPTS="$BASE/scripts/"
CONFIGS="$BASE/.config/"
ENV_GLOBAL="$CONFIGS/global.env"
ssh_path="/root/.ssh"

mkdir -p $SCRIPTS $CONFIGS $ssh_path

apt update
apt install wget git openssh-client -y

git clone $GIT_PROTOCOL://$GIT_SERVER/$GIT_USER/Base.git $SCRIPTS/base

# Helper script(s)
source $SCRIPTS/base/debian/env_writer.sh

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
--content "
# Filepaths
export BASE=$BASE
export SCRIPTS=$SCRIPTS
export CONFIGS=$CONFIGS
export LOGS=/var/log
"

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
export DOCKER_CONFIGS="$CONFIGS/containers"

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
RESTIC_SERVER_PORT="443"
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

### Identity Files
cat <<EOT > $ssh_path/gitRepo-Apt-deploy.key
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

cat <<EOT > $ssh_path/gitRepo-Docker-deploy.key
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

### Aliases
cat <<EOT >> /root/.ssh/config
# Github SSH Server Aliases ------------------------------------
Host $GIT_SERVER-Apt
    Hostname $GIT_SERVER
    IdentityFile=$ssh_path/gitRepo-Apt-deploy.key

Host $GIT_SERVER-Docker
    Hostname $GIT_SERVER
    IdentityFile=$ssh_path/gitRepo-Docker-deploy.key

EOT

# Fix permission all all the keys and config above
chmod -R 700 $ssh_path

git clone $GIT_APT_URL/Apt.git $SCRIPTS/apt

# Bash RC -----------------------------------------------------------------------------------------------
cat <<EOT >> /root/.bashrc

# Non-Root user, from preseed.cfg
export SECURE_USER=user
export SECURE_USER_UID=1000
export SECURE_USER_GROUP=users

# Environmental Variables Global list
export ENV_GLOBAL="$ENV_GLOBAL"
source $ENV_GLOBAL

# APT aliases
aptUP=$SCRIPTS/base/debian/update.sh
update=$SCRIPTS/base/debian/update.sh
clean=$SCRIPTS/base/clean.sh

EOT
# Reload .bashrc
. ~/.bashrc

# Prep-VM
. $SCRIPTS/base/prepVM.sh

# Debian Base
. $SCRIPTS/base/up.sh