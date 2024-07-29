#!/bin/bash

read -p "Create $SECURE_USER password? " -n 1 -r
echo    # (optional) move to a new line
if [[ $reply =~ ^[Yy]$ ]]
then
new_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)
if getent passwd $(id -nu $SECURE_USER_UID) > /dev/null 2>&1; then
  echo "yes $(id -nu $SECURE_USER_UID) exists"
  echo "$(id -nu $SECURE_USER_UID):$new_password" | chpasswd
else
  echo "No, $(id -nu $SECURE_USER_UID) does not exist"
  useradd $(id -nu $SECURE_USER_UID) -s$SHELL
  echo "$(id -nu $SECURE_USER_UID):$new_password" | chpasswd
fi
read -p "[debsec] up.sh, $HOST_NAME, Username: $(id -nu $SECURE_USER_UID), Password: $new_password , press [ENTER] to continue."
fi