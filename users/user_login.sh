#!/bin/bash

read -p "Create secure user password? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
NEW_PASSWORD=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c 32;)
if getent passwd $(id -nu 1000) > /dev/null 2>&1; then
  echo "yes $(id -nu 1000) exists"
  echo "$(id -nu 1000):$NEW_PASSWORD" | chpasswd
else
  echo "No, $(id -nu 1000) does not exist"
  useradd $(id -nu 1000) -s /bin/bash
  echo "$(id -nu 1000):$NEW_PASSWORD" | chpasswd
fi
read -p "[debsec] up.sh, $HOST_NAME, Username: $(id -nu 1000), Password: $NEW_PASSWORD , press [ENTER] to continue."
fi