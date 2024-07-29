#!/bin/bash

# From: https://gist.github.com/hvmonteiro/7f897cd8ae3993195855040056f87dc6

# http://www.patorjk.com/software/taag/#p=display&f=ANSI%20Regular&t=WARNING%0A

## https://pastebin.com/JQi0yWXy

#   * Add a legal banner to /etc/issue, to warn unauthorized users [BANN-7126] 
#       https://cisofy.com/lynis/controls/BANN-7126/

#   * Add legal banner to /etc/issue.net, to warn unauthorized users [BANN-7130] 
#       https://cisofy.com/lynis/controls/BANN-7130/

# /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf

# ██     ██  █████  ██████  ███    ██ ██ ███    ██  ██████  
# ██     ██ ██   ██ ██   ██ ████   ██ ██ ████   ██ ██       
# ██  █  ██ ███████ ██████  ██ ██  ██ ██ ██ ██  ██ ██   ███ 
# ██ ███ ██ ██   ██ ██   ██ ██  ██ ██ ██ ██  ██ ██ ██    ██ 
#  ███ ███  ██   ██ ██   ██ ██   ████ ██ ██   ████  ██████ 

cat <<EOT > /etc/issue
------------------------------------------------------------------------
Unauthorized access to this system is forbidden and will be
prosecuted by law. By accessing this system, you agree that your actions
may be monitored if unauthorized usage is suspected.
------------------------------------------------------------------------

EOT

cat <<EOT > /etc/issue.net
------------------------------------------------------------------------
Unauthorized access to this system is forbidden and will be
prosecuted by law. By accessing this system, you agree that your actions
may be monitored if unauthorized usage is suspected.
------------------------------------------------------------------------

EOT

# The work below is achieved via the autologin.conf config in debia-base 'up.sh'
# cat <<EOT > /etc/systemd/system/getty.target.wants/getty@ttyS0.service
# [Service]
# ExecStart=-/sbin/agetty --noclear -a root %I $TERM
# # Add this line to use a different issue file for ttyS0
# IssuesFiles=/etc/issue.ttyS0
# EOT

# cat <<EOT > /etc/systemd/system/getty@ttyS0.service
# [Service]
# ExecStart=-/sbin/agetty --noclear -a root %I $TERM
# # Add this line to use a different issue file for ttyS0
# IssuesFiles=/etc/issue.ttyS0
# EOT

# systemctl daemon-reload
# systemctl enable getty@ttyS0.service

# cat <<EOT > /etc/issue.ttyS0
# ██████  ███████ ██████  ██  █████  ███    ██    TTY: \l
# ██   ██ ██      ██   ██ ██ ██   ██ ████   ██    Host: \n
# ██   ██ █████   ██████  ██ ███████ ██ ██  ██    Arch: \m
# ██   ██ ██      ██   ██ ██ ██   ██ ██  ██ ██    Kernel: \r
# ██████  ███████ ██████  ██ ██   ██ ██   ████    Build: \v

# --------------------------------------------------------------------------------------------
# Unauthorized access to this system is forbidden and will be
# prosecuted by law. By accessing this system, you agree that your actions
# may be monitored if unauthorized usage is suspected.
# EOT