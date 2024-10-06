# This file is intended to:
## - write base ENV variables that can be sourced by other scripts
## - download and source help functions
## - fire off initial configuration including sysctl configuration

# /etc/environment
# /root/.ssh
# /root/.bashrc
# /root/.config/
#   ├── global.env
#   ├── docker.env
#   ├── smtp.env
#   ├── snmp.env
#   └── git.env


# Max Width
#<-------------------------------------------------------------------------------------------------->#

# Variables and Prep ------------------------------------------------------------------------------

GIT_PROTOCOL=""
GIT_SERVER_FQDN=""
GIT_USER=""

SECURE_USER_ID="1000"
SECURE_USER="$(id -nu "$SECURE_USER_ID" 2>/dev/null || echo "user")"
LAN_NIC=$(ip -o link show up | awk -F': ' 'NR==2 {print $2; exit}' | sed 's/@.*//')

BASE="/root/"
SCRIPTS="$BASE/scripts/"
CONFIGS="$BASE/.config/"
ENV_GLOBAL="$CONFIGS/global.env"
ssh_path="/root/.ssh"

mkdir -p "$SCRIPTS" "$CONFIGS" "$ssh_path"

apt update
apt install wget git openssh-client xterm -y

# Resize terminal
trap "resize >/dev/null" DEBUG
export TERM=xterm-256color

git clone "$GIT_PROTOCOL://$GIT_SERVER_FQDN/$GIT_USER/Base.git" "$SCRIPTS/base"

# Helper script(s)
source "$SCRIPTS/base/debian/logging_functions.sh"
source "$SCRIPTS/base/debian/env_writer.sh"

# System Variables -------------------------------------------------------------------------------
cat <<EOT > /etc/environment

# Localization
export TZ="America/Vancouver"
export LANG="en_US.UTF-8"

# Shell
export SHELL="/bin/bash"
export EDITOR="nano"

# Modprobe Blacklist
export MOD_BLACKLIST="/etc/modprobe.d/blacklist.conf"

EOT
source /etc/environment

# User Variables -------------------------------------------------------------------------------
env_writer \
--service 'Global' \
--content "
# FILEPATHS
export BASE=\"$BASE\"
export SCRIPTS=\"$SCRIPTS\"
export CONFIGS=\"$CONFIGS\"
export LOGS=/var/log

# filepaths 
export base=\"$BASE\"
export scripts=\"$SCRIPTS\"
export configs=\"$CONFIGS\"
export logs=/var/log

# Logging
source $SCRIPTS/base/debian/logging_functions.sh
"

# IP Tables / Network
env_writer \
--source \
--service 'Network' \
--content "
# System
export LAN_NIC=$LAN_NIC             # Predictable network interface name assigned by udev (v197) for the primary network interface
export DOMAIN="lan"                 # Referenced by scripts that need to know the local or remote domain extension
export FIREWALL="iptables"          # Referenced by scripts that need to know what, if any firewall is intended to be used
export REV_PROXY_FQDN="172.27.0.1"  # Local Reverse Proxy IP (if used)

# Trusted Subnets
export GREEN="10.0.0.0/24"          # Subnet treated with high trust
export CYAN="192.168.111.0/24"      # Semi-trusted Subnet

# Untrusted Subnets
export ORANGE="172.27.0.0/24"       # DMZ Subnet
export BLUE="192.168.0.0/24"        # Guest Subnet

# Isolated Subnets
export BROWN="192.168.7.0/24"       # Isolated Subnet

# VPN Subnets
export VPN="10.2.0.0/24"            # Subnet for VPN clients, similar to GREEN
export BLACK="172.27.7.0/24"        # VPN outbound international
export GRAY="172.27.9.0/24"         # VPN outbound national

# Alias for RFC1918 Local area subnets
export RFC1918="192.168.0.0/16,172.16.0.0/12,10.0.0.0/8"
"

# SMTP Secrets
env_writer \
--service 'SMTP' \
--content '
export ADMIN_EMAIL=""
export SMTP_USER=""
export SMTP_PASS=""
export SMTP_SERVER_FQDN=""
export SMTP_PORT="587"
'

# SNMP
env_writer \
--service 'SNMP' \
--content '
export SNMP_AGENT_PORT="161"
export SNMP_POLLER_FQDN=""
export SNMP_LOCATION=""
'

# SSH
env_writer \
--service 'SSH' \
--content '
export SSH_ALLOW_FQDN=""
export SSH_ALLOW_IPS="$GREEN"
'

# Docker -----------------------------------------------------------------------------------------
env_writer \
--source \
--service 'Docker' \
--content '
# Paths
export DOCKER_CONTROLLER="$SCRIPTS/docker/.controller"
export DOCKER_ROOT_DIR="/var/lib/docker"
export DOCKER_MOUNTS="$DOCKER_ROOT_DIR/mounts"
export DOCKER_VOLUMES="$DOCKER_ROOT_DIR/volumes"
export DOCKER_CONFIGS="$CONFIGS/containers"
export DOCKER_API_PORT=2376

# Docker
export DOCKER_REGISTRY_MIRROR_FQDN=""

# Portainer
export PORTAINER_SERVER_FQDN=""

# Docker Controller
alias dc="$DOCKER_CONTROLLER/docker-controller.sh"
'

# Restic Info
env_writer \
--service 'Restic' \
--content '
# Server Details, REST: https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html#rest-server
export RESTIC_SERVER_FQDN=""
export RESTIC_SERVER_PORT="443"
export RESTIC_SERVER_TYPE="Rest"

# Server User Credentials
export RESTIC_SERVER_USER_NAME=""
export RESTIC_SERVER_USER_PASSWORD=""
export RESTIC_SERVER_BASE_REPO_URL="rest:https://$RESTIC_SERVER_USER_NAME:$RESTIC_SERVER_USER_PASSWORD@$RESTIC_SERVER_FQDN"  #/$RESTIC_SERVER_USER_NAME-$LABEL

# Default Repo Password
export RESTIC_REPO_DEFAULT_PASSWORD=""
export 
'

# Git -----------------------------------------------------------------------------------------------
env_writer \
--service 'GIT' \
--content "
# Git
export GIT_SERVER_FQDN=\"$GIT_SERVER_FQDN\"
export GIT_USER=\"$GIT_USER\"

# Specific Repo SSH aliases
export GIT_APT_URL=\"git@$GIT_SERVER_FQDN-Apt:/$GIT_USER\"
export GIT_DOCKER_URL=\"git@$GIT_SERVER_FQDN-Docker:/$GIT_USER\"
"

### Identity Files
cat <<EOT > "$ssh_path/gitRepo-Apt-deploy.key"
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

cat <<EOT > "$ssh_path/gitRepo-Docker-deploy.key"
-----BEGIN OPENSSH PRIVATE KEY-----
-----END OPENSSH PRIVATE KEY-----
EOT

### Aliases
cat <<EOT >> /root/.ssh/config
# Github SSH Server Aliases ------------------------------------
Host $GIT_SERVER_FQDN-Apt
    Hostname $GIT_SERVER_FQDN
    IdentityFile=$ssh_path/gitRepo-Apt-deploy.key

Host $GIT_SERVER_FQDN-Docker
    Hostname $GIT_SERVER_FQDN
    IdentityFile=$ssh_path/gitRepo-Docker-deploy.key

EOT

# Fix permission all all the keys and config above
chmod -R 700 "$ssh_path"

# Bash RC -----------------------------------------------------------------------------------------------
cat <<EOT >> /root/.bashrc

# Non-Root user, from preseed.cfg
export SECURE_USER_UID="$SECURE_USER_ID"
export SECURE_USER="$SECURE_USER"
export SECURE_USER_GROUP=users

# Environmental Variables Global list
export ENV_GLOBAL="$ENV_GLOBAL"
source "$ENV_GLOBAL"

# Aliases
alias aptup="$SCRIPTS/base/debian/update.sh"
alias update="$SCRIPTS/base/debian/update.sh"
alias clean="$SCRIPTS/apt/clean.sh"
alias pullall="$SCRIPTS/base/debian/pullall.sh"
EOT

# Reload .bashrc
. ~/.bashrc

# Clone Apt, don't ask about new fingerprints
export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no'
git clone "$GIT_APT_URL/Apt.git" "$SCRIPTS/apt"

# Prep-VM
. "$SCRIPTS/base/prepVM.sh"

# Debian Base
. "$SCRIPTS/base/up.sh"

# source $ENV_GIT
# git clone "$GIT_DOCKER_URL/docker.git" "$SCRIPTS/docker"

