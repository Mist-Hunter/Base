#!/bin/bash

source $ENV_GLOBAL
source $SCRIPTS/base/users/passgen.sh

# Ensure SECURE_USER_UID and SHELL are defined
if [[ -z "$SECURE_USER_UID" ]] || [[ -z "$SHELL" ]]; then
  echo "Error: SECURE_USER_UID or SHELL variable is not set."
  exit 1
fi

# Prompt to create a password
read -p "Create password for user with UID $SECURE_USER_UID? (Y/n): " -n 1 -r
echo # (optional) move to a new line

if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Generate a new password
  new_password=$(generate_strong_password)

  # Get the username for the given UID
  username=$(id -nu "$SECURE_USER_UID")

  # Check if user exists
  if getent passwd "$username" > /dev/null 2>&1; then
    echo "User $username exists."
    echo "$username:$new_password" | chpasswd  > /dev/null 2>&1
  else
    echo "User $username does not exist. Creating user."
    useradd "$username" -s "$SHELL"
    echo "$username:$new_password" | chpasswd  > /dev/null 2>&1
  fi

  # Provide feedback to the user
  present_secrets "User:$SECURE_USER" "Password:$new_password"
fi