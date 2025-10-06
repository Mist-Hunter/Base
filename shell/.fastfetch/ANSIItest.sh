#!/bin/sh
# troubleshoot_banner.sh - A diagnostic tool for banner_fixed.sh

echo "--- Banner Troubleshooting Script ---"

# --- 1. Color Rendering Test ---
# This section prints each color variable from the main script to see if your
# terminal displays them correctly. Each name should match its color.
echo "\n[+] 1. Testing Color Variable Rendering..."
ESC=$(printf '\033')
N="${ESC}[0m"
TITLE="${ESC}[38;5;197m"
INFO="${ESC}[0;97m"
C1="${ESC}[38;5;197m"
C2="${ESC}[38;5;160m"
C3="${ESC}[0;97m"
C4="${ESC}[1;34m"
C5="${ESC}[1;35m"
C6="${ESC}[1;36m"
C7="${ESC}[1;37m"
C8="${ESC}[0;90m"
C9="${ESC}[1;30m"

printf "  ${TITLE}TITLE${N} (Light Red/Pink)\n"
printf "  ${INFO}INFO${N} (Bright White)\n"
printf "  ${C1}C1${N} (Light Red/Pink)\n"
printf "  ${C2}C2${N} (Darker Red)\n"
printf "  ${C3}C3${N} (Bright White)\n"
printf "  ${C4}C4${N} (Blue)\n"
printf "  ${C5}C5${N} (Magenta)\n"
printf "  ${C6}C6${N} (Cyan)\n"
printf "  ${C7}C7${N} (White)\n"
printf "  ${C8}C8${N} (Dark Grey)\n"
printf "  ${C9}C9${N} (Bright Black)\n"

# --- 2. Logo Fetch & Processing Test ---
# This tests if the script can download the logo file and if the `sed`
# commands are correctly replacing the color tokens.
echo "\n[+] 2. Testing Logo Fetch and Processing..."
if [ -f /etc/os-release ]; then . /etc/os-release && os_id=$(echo "$ID" | awk '{print tolower($0)}'); fi
[ -z "$os_id" ] && os_id=$(uname -s | awk '{print tolower($0)}')
logo_url="https://raw.githubusercontent.com/fastfetch-cli/fastfetch/dev/src/logo/ascii/${os_id}.txt"

echo "  Attempting to download logo for '${os_id}' from:"
echo "  ${logo_url}"

logo_raw=$(wget -qO- "$logo_url")

if [ -z "$logo_raw" ]; then
    echo "  [!] Could not download logo. Using internal fallback for test."
    logo_raw='${c2},met${c1}gg.\n${c2},g$${c1}$$$P.'
fi

echo "\n  --- Raw Logo (from web or fallback) ---"
printf "%s\n" "$logo_raw"
echo "  -----------------------------------------"

logo_processed=$(
  printf '%s' "$logo_raw" | sed \
    -e "s/\${c1}/${C1}/g" -e "s/\$1/${C1}/g" \
    -e "s/\${c2}/${C2}/g" -e "s/\$2/${C2}/g" \
    -e "s/\${c3}/${C3}/g" -e "s/\$3/${C3}/g" \
    -e "s/\${reset}/${N}/g" \
    -e 's/\$\$/$/g'
)

echo "\n  --- Processed Logo (with colors applied) ---"
printf "%s\n" "$logo_processed"
echo "  --------------------------------------------"


# --- 3. Width Calculation Test ---
# This part checks the logic for calculating the "visible" width of the logo,
# which is crucial for aligning the columns correctly.
echo "\n[+] 3. Testing Logo Width Calculation..."
stripped_logo=$(printf '%s' "$logo_processed" | sed "s/${ESC}\[[0-9;]*m//g")
max_width=$(printf '%s' "$stripped_logo" | awk '{if (length($0)>max) max=length($0)} END{print max+0}')

echo "  Logo with ANSI codes stripped for measurement:"
printf "%s\n" "$stripped_logo"
echo "\n  Calculated max width: ${max_width} characters."

# --- 4. 256-Color Support Test ---
# Displays the standard 16-color palette. If these blocks don't show up
# as distinct colors, your terminal may not fully support the script.
echo "\n[+] 4. Testing Terminal 256-Color Support..."
printf "  "
i=0; while [ "$i" -lt 8 ]; do printf "${ESC}[48;5;%sm  " "$i"; i=$((i+1)); done
printf "${N}\n"
printf "  "
i=8; while [ "$i" -lt 16 ]; do printf "${ESC}[48;5;%sm  " "$i"; i=$((i+1)); done
printf "${N}\n\n"

echo "--- Troubleshooting Complete ---"
