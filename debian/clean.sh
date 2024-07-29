#!/bin/bash
# Refference: https://itsfoss.com/free-up-space-ubuntu-linux/

apt autoremove -y
apt clean
du -sh /var/cache/apt
apt autoclean -y

# Log Cleanup
du -sh /var/log
journalctl --disk-usage
journalctl --vacuum-time=3d

# Temp files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Logrotate
rm -f /var/log/auth.log.*
rm -f /var/log/syslog.*
rm -f /var/log/kern.log.*
rm -f /var/log/daemon.log.*
rm -f /var/log/dpkg.log.*
rm -f /var/log/mail.log.*
rm -f /var/log/messages.log.*
rm -f /var/log/cron.log.*
rm -f /var/log/apt/term.log.*
rm -f /var/log/apt/history.log.*

du -sh /var/log

# Bash history cleanup
echo "" > /root/.bash_history

# Restic cleanup
if command -v restic &> /dev/null
then
    restic cache --cleanup
fi

# Snap cleanup
if command -v snap &> /dev/null
then
    du -h /var/lib/snapd/snaps
fi

# cat /etc/logrotate.conf