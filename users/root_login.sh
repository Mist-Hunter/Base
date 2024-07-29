#!/bin/bash

# FIXME Oracle cloud sometimes uses pts/0 and sometimes ttyS0
## https://support.oracle.com/knowledge/Oracle%20Database%20Products/2753391_1.html

# Autologin, Random Root Password---------------------------------------------------------------------------------------------------
# agetty Auto-Login, ref: https://wiki.archlinux.org/title/Getty#Automatic_login_to_virtual_console , https://man7.org/linux/man-pages/man8/agetty.8.html

read -p "Create a secure root password? " -n 1 -r
echo # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)
    echo "root:$NEW_PASSWORD" | chpasswd
    read -p "Systems, debian-base, prepVM, Root, Password: $NEW_PASSWORD , press [ENTER] to continue."

    # Autologin for the current terminal
    TTY_DEV=$(ps hotty $$)
    mkdir -p "/etc/systemd/system/serial-getty@${TTY_DEV}.service.d"
    cat <<EOT >"/etc/systemd/system/serial-getty@${TTY_DEV}.service.d/autologin.conf"
# Autologin configuration for current terminal ($TTY_DEV)
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOT

    echo "Autologin enabled for current terminal ($TTY_DEV)."

    # Check if the physical video console is available
    TTY_DEV="tty1"
    if [ -e /dev/$TTY_DEV ]; then
        mkdir -p "/etc/systemd/system/getty@${TTY_DEV}.service.d"
        cat <<EOT >"/etc/systemd/system/getty@${TTY_DEV}.service.d/autologin.conf"
# Autologin configuration for /dev/$TTY_DEV (physical video console)
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOT

        echo "Autologin enabled for /dev/$TTY_DEV(physical video console)."
    fi
fi

# FIXME verify autologin in RPI