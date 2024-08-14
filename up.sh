#!/bin/bash
# TODO: Check for evidence preVM.sh has run @ BLACKLIST="/etc/modprobe.d/blacklist.conf"
# TODO make this script idempotent

# NOTE: This script now presumes .$SCRIPTS/apt & .$SCRIPTS/systems exist already (from kick)
apt update

# Favorite Apps
apt install -y \
  `# dnsutils - includes tools like nslookup and dig for DNS troubleshooting` \
  dnsutils \
  `# htop - interactive process viewer and system monitor` \
  htop \
  `# ncdu - disk usage analyzer with an ncurses interface` \
  ncdu \
  `# net-tools - networking utilities including ifconfig and netstat` \
  net-tools \
  `# tmux - terminal multiplexer that allows multiple terminal sessions to be accessed simultaneously` \
  tmux \
  `# tree - display directory tree structures` \
  tree

# Set DEV_TYPE
. $scripts/base/dev-type/define.sh

# Setup Firewall
if [[ "$FIREWALL" == "iptables" ]]; then
  # NOTE: Multiple SCRIPTS rely on this script completing, keep early in the install sequence.
  . $SCRIPTS/base/firewall/up.sh

    # Install GIT Firewall Rules
  # NOTE: this is needed in the event of a firewall being present
  . $SCRIPTS/apt/git/up.sh
fi

# Make Directories
mkdir -p $SCRIPTS

if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then
  # Bare metal RPi
  # Handle USB Restic Drive (should be /sda)
  read -p "Prepare / mount an external USB drive?" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    read -p "READ: configure the dietpi-drive_manager to mount USB drive at /mnt/usb. Press [Enter] to continue."
    dietpi-drive_manager
    mkdir -p $BASE/backups
    ln -s /mnt/usb $BASE/backups
  fi
fi

cd $SCRIPTS

# Configure Bash
# Aliases
if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then
cat <<EOT >> ~/.bashrc

#Aliases
alias aptUp="$SCRIPTS/base/debian/update.sh && dietpi-update"
EOT
else
cat <<EOT >> ~/.bashrc

#Shell / Prompt Configuration (bash-it replacement)
. $scripts/base/shell/prompt.sh
EOT
fi

# Neofetch
. $SCRIPTS/apt/neofetch/up.sh

# Setup Update Service
. $SCRIPTS/base/debian/updaterservice.sh

# Pseudo-Cron
# . $SCRIPTS/apt/cron/systemd_pesudo_cron_install.sh

# Btop
. $SCRIPTS/apt/btop/up.sh

# PS_Mem
. $SCRIPTS/apt/ps_mem/up.sh

# Lynis Add a legal banner to /etc/issue, to warn unauthorized users [BANN-7126], Add legal banner to /etc/issue.net, to warn unauthorized users [BANN-7130]
. $SCRIPTS/base/debian/warning.sh    # <--- 1 Point. 

if [[ $DEV_TYPE = "armv7l" ]] || [[ $DEV_TYPE = "aarch64" ]]; then

  # Bare metal RPi
 
  # Remote Exceptions.  http://3.230.113.73:9011/Allocom/USBridgeSig/rpi-usbs-5.4.51-v7+/ax88179_178a.ko Connecting to 3.230.113.73:9011... timed out.
  # iptables -I OUTPUT -m set ! --match-set BOGONS dst -d 3.230.113.73 -p tcp --dport 9011 -m comment --comment "Systems, dietpi-BASE, up.sh: Allow Dietpi out, except to BOGONS. dietpi-update." -j ACCEPT

  #SSH will be installed by default, needs to come first for SSH exceptions or will lock out.
  . $SCRIPTS/apt/sshd/up.sh

  # Because Crowdsec won't work, install anti-scan rules
  #. $SCRIPTS/base/firewall/anti-scan.sh

  # #iptables-save > $IPTABLES_PERSISTENT_RULES
  #. $SCRIPTS/base/firewall/save.sh  

  # Install Blinkt *** Needs to be last, because it interupts.
  # . $SCRIPTS/apt/blinkt/up.sh

fi

# Default Hostname
. $SCRIPTS/base/hostname/newhost.sh

# Root Login
. $SCRIPTS/base/users/root_login.sh

# Secure User Login
. $SCRIPTS/base/users/user_login.sh

if [[ "$HOST_NAME" != *preseed* && "$HOST_NAME" != *Template* ]]; then

  read -p "Install Docker? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    # Install Docker
    cd $SCRIPTS
    source $ENV_GIT
    git clone $GIT_DOCKER_URL/Docker.git $SCRIPTS/docker
    . $SCRIPTS/docker/up.sh
  fi
else
  echo "Skipping Docker install due to non-permanent host-name: $HOST_NAME"
fi

# Run Audit
. $SCRIPTS/apt/lynis/up.sh
