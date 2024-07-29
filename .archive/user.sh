#!/bin/bash
# Create User

# https://manpages.debian.org/jessie/passwd/useradd.8.en.html 

user=$(id -nu 1000)
if getent passwd $user > /dev/null 2>&1; then
echo "yes $user exists"
else
echo "No, $user does not exist"
useradd $user -s /bin/bash 
echo "$user:pass" | sudo chpasswd
fi
