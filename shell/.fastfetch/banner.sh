#!/bin/sh
# banner.sh - Lightweight system information display (POSIX sh)

# === ESC + COLORS ===
ESC=$(printf '\033')

R="${ESC}[1;31m"  # Red
Y="${ESC}[1;33m"  # Yellow
G="${ESC}[1;32m"  # Green
B="${ESC}[1;34m"  # Blue
M="${ESC}[1;35m"  # Magenta
C="${ESC}[1;36m"  # Cyan
W="${ESC}[1;37m"  # White
N="${ESC}[0m"     # Reset

# Logo color shortcuts
C1="$R"; C2="$Y"; C3="$G"; C4="$B"; C5="$M"; C6="$C"; C7="$W"
C8="${ESC}[0;90m"
C9="${ESC}[1;30m"

# === SYSTEM INFO ===
# OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    os="$PRETTY_NAME"
else
    os=$(uname -s)
fi

# Host
host=$(cat /sys/class/dmi/id/product_name 2>/dev/null || hostname)

# Kernel
kernel=$(uname -r)

# Shell
shell="${SHELL##*/}"

# Uptime
uptime_sec=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
days=$((uptime_sec / 86400))
hours=$((uptime_sec % 86400 / 3600))
mins=$((uptime_sec % 3600 / 60))
uptime="${days}d ${hours}h ${mins}m"

# CPU
cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Unknown CPU")
cores=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
cpu="${cpu} (${cores})"

# Memory
mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
mem_avail=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null)
if [ -z "$mem_avail" ]; then
    mem_free=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    mem_buf=$(awk '/Buffers/ {print $2}' /proc/meminfo)
    mem_cache=$(awk '/^Cached/ {print $2}' /proc/meminfo)
    mem_avail=$(( (mem_free + mem_buf + mem_cache) / 1024 ))
fi
mem_used=$((mem_total - mem_avail))
mem_pct=0
[ "$mem_total" -gt 0 ] && mem_pct=$((mem_used * 100 / mem_total))
memory="${mem_used}M / ${mem_total}M (${mem_pct}%)"

# Disk
disk=$(df -h / 2>/dev/null | awk 'NR==2 {printf "%s / %s (%s)", $3, $2, $5}')
[ -z "$disk" ] && disk="N/A"

# Swap
swap_total=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$swap_total" -gt 0 ]; then
    swap_free=$(awk '/SwapFree/ {print int($2/1024)}' /proc/meminfo)
    swap_used=$((swap_total - swap_free))
    swap_pct=$((swap_used * 100 / swap_total))
    swap="${swap_used}M / ${swap_total}M (${swap_pct}%)"
else
    swap="Disabled"
fi

# IPs
local_ip=$(ip -4 a 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2; exit}' | cut -d/ -f1)
[ -z "$local_ip" ] && local_ip="N/A"
public_ip=$(timeout 2 wget -qO- http://icanhazip.com 2>/dev/null || echo "N/A")

# === LOGO FETCH OR FALLBACK ===
os_id=$(echo "$os" | awk '{print tolower($1)}')
cache_dir="${HOME}/.cache/banner"
mkdir -p "$cache_dir" 2>/dev/null
logo_file="${cache_dir}/${os_id}.txt"

if [ ! -f "$logo_file" ] || [ ! -s "$logo_file" ]; then
    wget -q -O "$logo_file" "https://raw.githubusercontent.com/fastfetch-cli/fastfetch/dev/src/logo/ascii/${os_id}.txt" 2>/dev/null
    if [ ! -s "$logo_file" ]; then
        wget -q -O "$logo_file" "https://raw.githubusercontent.com/fastfetch-cli/fastfetch/dev/src/logo/ascii/${os_id}_small.txt" 2>/dev/null
    fi
fi

if [ -f "$logo_file" ] && [ -s "$logo_file" ]; then
    logo_raw=$(cat "$logo_file")
else
    # fallback ASCII
    logo_raw='
$1_,met$$$$$gg.
$2,g$$$$$$$$$$$$$P.
$3,$$$P"   ""Y$$.
$4,$$$P"     `$$.
'
fi

# === TOKEN REPLACEMENT (FIXED with awk) ===
# Using awk to avoid issues with shell expansion of control characters in sed
export C1 C2 C3 C4 C5 C6 C7 C8 C9 ESC N
logo_processed=$(printf '%s' "$logo_raw" | awk '
BEGIN {
    # Load color codes from environment variables
    c[1]=ENVIRON["C1"]; c[2]=ENVIRON["C2"]; c[3]=ENVIRON["C3"];
    c[4]=ENVIRON["C4"]; c[5]=ENVIRON["C5"]; c[6]=ENVIRON["C6"];
    c[7]=ENVIRON["C7"]; c[8]=ENVIRON["C8"]; c[9]=ENVIRON["C9"];
    esc=ENVIRON["ESC"];
}
{
    # Perform substitutions
    gsub(/\$1/, c[1]); gsub(/\$2/, c[2]); gsub(/\$3/, c[3]);
    gsub(/\$4/, c[4]); gsub(/\$5/, c[5]); gsub(/\$6/, c[6]);
    gsub(/\$7/, c[7]); gsub(/\$8/, c[8]); gsub(/\$9/, c[9]);
    gsub(/\$([0-9]+)\[/, esc "["); # Handle formats like $10[
    gsub(/\$\[/, esc "[");          # Handle formats like $[
    gsub(/\$\$/, "$");               # Handle literal $$
    sub(/[[:space:]]+$/, "");      # Remove trailing whitespace
    print
}
')

# The logo is the processed text. Do NOT add a reset code to each line.
logo="$logo_processed"

# === INFO BLOCK ===
# Make sure to add a final color reset to the end of the info block
info="${R}OS${N}:        $os
${R}Host${N}:      $host
${R}Kernel${N}:    $kernel
${R}Shell${N}:     $shell
${R}Uptime${N}:    $uptime

${Y}CPU${N}:       $cpu
${Y}Memory${N}:    $memory
${Y}Disk (/)${N}:  $disk
${Y}Swap${N}:      $swap

${G}Local IP${N}:  $local_ip
${G}Public IP${N}: $public_ip
${B}█${R}█${Y}█${G}█${C}█${M}█${W}█${N}█${N}" # Added extra ${N} for safety

printf '%s\n' "$logo" > "$logo_tmp"
printf '%s\n' "$info" > "$info_tmp"

# Strip ANSI for width
sed "s/${ESC}\[[0-9;]*m//g" "$logo_tmp" > "$stripped_logo"
max_logo_width=$(awk '{if (length($0)>max) max=length($0)} END{print max+0}' "$stripped_logo")
[ -z "$max_logo_width" ] && max_logo_width=1

logo_padding=1
logo_col_width=$((max_logo_width + logo_padding))

logo_lines=$(wc -l < "$logo_tmp" | tr -d ' ')
info_lines=$(wc -l < "$info_tmp" | tr -d ' ')
[ "$info_lines" -gt "$logo_lines" ] && max_lines=$info_lines || max_lines=$logo_lines

i=1
while [ "$i" -le "$max_lines" ]; do
    logo_line=$(sed -n "${i}p" "$logo_tmp")
    info_line=$(sed -n "${i}p" "$info_tmp")

    visible_len=$(printf '%s' "$logo_line" | sed "s/${ESC}\[[0-9;]*m//g" | awk '{print length}')
    pad=$((logo_col_width - visible_len))
    [ "$pad" -lt 1 ] && pad=1
    padstr=$(printf '%*s' "$pad" '')

    printf " %s%s %s\n" "$logo_line" "$padstr" "$info_line"
    i=$((i+1))
done

# Cleanup
rm -f "$logo_tmp" "$info_tmp" "$stripped_logo"