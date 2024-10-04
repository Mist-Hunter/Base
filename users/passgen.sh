#!/bin/bash

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