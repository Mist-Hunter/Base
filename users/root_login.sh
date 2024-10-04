#!/bin/bash
set -e

source $ENV_GLOBAL

# Function to enable autologin for a specific TTY
enable_autologin() {
    local tty_dev=$1
    local service_dir="/etc/systemd/system/getty@${tty_dev}.service.d"
    mkdir -p "$service_dir"
    cat <<EOT >"$service_dir/autologin.conf"
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOT
    echo "Autologin enabled for $tty_dev."
}

# Function to generate a strong password compatible with libpam-passwdqc
generate_strong_password() {
    local length=20
    local charset='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?'
    local password=""
    
    # Ensure at least one character from each required class
    password+=$(echo ${charset:0:26} | fold -w1 | shuf | head -n1)  # lowercase
    password+=$(echo ${charset:26:26} | fold -w1 | shuf | head -n1)  # uppercase
    password+=$(echo ${charset:52:10} | fold -w1 | shuf | head -n1)  # digit
    password+=$(echo ${charset:62} | fold -w1 | shuf | head -n1)  # special

    # Fill the rest of the password
    for i in $(seq 1 $((length - 4))); do
        password+=$(echo $charset | fold -w1 | shuf | head -n1)
    done

    # Shuffle the password
    echo $password | fold -w1 | shuf | tr -d '\n'
}

# Function to change password
change_password() {
    local user=$1
    local password=$2
    local temp_file=$(mktemp)
    echo "$user:$password" > "$temp_file"
    
    # Attempt to change password using chpasswd
    if chpasswd -c SHA512 < "$temp_file" 2>"$temp_file.err"; then
        echo "Password for $user changed successfully."
        rm "$temp_file" "$temp_file.err"
        return 0
    else
        echo "Failed to change password for $user. Error:"
        cat "$temp_file.err"
        rm "$temp_file" "$temp_file.err"
        return 1
    fi
}

# Autologin, Random Root Password
echo "Create a secure root password? (y/n)"
read -r reply
if [[ $reply =~ ^[Yy]$ ]]; then
    new_password=$(generate_strong_password)
    
    if change_password root "$new_password"; then
        present_secrets "User:root" "Password:$new_password"
    else
        echo "Failed to change root password. Please check your system's password policies and try again manually."
        exit 1
    fi

    # Autologin for the current terminal
    current_tty=$(tty)
    current_tty=${current_tty#/dev/}
    enable_autologin "$current_tty"

    # Check for framebuffer devices
    if ! ls /dev/fb* > /dev/null 2>&1; then
        echo "No framebuffer devices found."
    else
        echo "Framebuffer devices found:"
        ls /dev/fb*
        enable_autologin "tty1"
    fi

    # Restart getty services without exiting the script
    echo "Reloading systemd daemon and restarting getty services..."
    systemctl daemon-reload
    for tty in $(systemctl list-units "getty@*.service" --no-legend | awk '{print $1}'); do
        systemctl try-restart "$tty"
    done
fi

echo "Script completed successfully."