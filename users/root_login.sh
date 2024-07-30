#!/bin/bash

# Autologin, Random Root Password---------------------------------------------------------------------------------------------------
# agetty Auto-Login, ref: https://wiki.archlinux.org/title/Getty#Automatic_login_to_virtual_console , https://man7.org/linux/man-pages/man8/agetty.8.html

read -p "Create a secure root password? " -n 1 -r
echo # (optional) move to a new line
if [[ $reply =~ ^[Yy]$ ]]; then
    new_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)
    echo "root:$new_password" | chpasswd
    read -p "Systems, debian-base, prepVM, Root, Password: $new_password , press [ENTER] to continue."

    # Autologin for the current terminal
    tty_dev=$(awk -F': ' '/uart:/ && !/uart:unknown/ {print "ttyS" $1; exit}' /proc/tty/driver/serial)  # NOTE > $(ps hotty $$) doesn't work under sudo bash.
    mkdir -p "/etc/systemd/system/serial-getty@${tty_dev}.service.d"
    cat <<EOT >"/etc/systemd/system/serial-getty@${tty_dev}.service.d/autologin.conf"
# Autologin configuration for current terminal ($tty_dev)
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOT

    echo "Autologin enabled for current terminal ($tty_dev)."

# Check if the physical video console is available
if ! ls /dev/fb* > /dev/null 2>&1; then
    echo "No framebuffer devices found."
else
    echo "Framebuffer devices found:"
    ls /dev/fb*
    # FIXME tty1 will always exist
    tty_dev="tty1"
    if [ -e /dev/$tty_dev ]; then
        mkdir -p "/etc/systemd/system/getty@${tty_dev}.service.d"
        cat <<EOT > "/etc/systemd/system/getty@${tty_dev}.service.d/autologin.conf"
# Autologin configuration for /dev/$tty_dev (physical video console)
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOT

        echo "Autologin enabled for /dev/$tty_dev(physical video console)."
    fi
fi
