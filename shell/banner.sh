#!/bin/sh
# banner.sh - Lightweight system information display (POSIX sh)

# This project uses some fastfetch project code: https://github.com/fastfetch-cli/fastfetch

# Color Codes
## https://github.com/fastfetch-cli/fastfetch/blob/dev/src/common/color.h

    # define FF_COLOR_FG_RED "31"
    # define FF_COLOR_FG_GREEN "32"
    # define FF_COLOR_FG_YELLOW "33"
    # define FF_COLOR_FG_BLUE "34"
    # define FF_COLOR_FG_MAGENTA "35"
    # define FF_COLOR_FG_CYAN "36"
    # define FF_COLOR_FG_WHITE "37"

# Color arrays (example Debian)
## https://github.com/fastfetch-cli/fastfetch/blob/af26828f910c91d4e1dd11dab5bfe2e0df636ff0/src/logo/builtin.c#L1369

    # // Debian
    # {
    #     .names = {"Debian", "debian-linux"},
    #     .lines = FASTFETCH_DATATEXT_LOGO_DEBIAN,
    #     .colors = {
    #         FF_COLOR_FG_RED,
    #         FF_COLOR_FG_WHITE,
    #     },
    #     .colorKeys = FF_COLOR_FG_RED,
    #     .colorTitle = FF_COLOR_FG_RED,
    # },

## https://raw.githubusercontent.com/fastfetch-cli/fastfetch/refs/heads/dev/src/logo/ascii/debian.txt

#         $2_,met$$$$$$$$$$gg.
#      ,g$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P.
#    ,g$$$$P""       """Y$$$$.".
#   ,$$$$P'              `$$$$$$.
# ',$$$$P       ,ggs.     `$$$$b:
# `d$$$$'     ,$P"'   $1.$2    $$$$$$
#  $$$$P      d$'     $1,$2    $$$$P
#  $$$$:      $$$.   $1-$2    ,d$$$$'
#  $$$$;      Y$b._   _,d$P'
#  Y$$$$.    $1`.$2`"Y$$$$$$$$P"'
#  `$$$$b      $1"-.__
#   $2`Y$$$$b
#    `Y$$$$.
#      `$$$$b.
#        `Y$$$$b.
#          `"Y$$b._
#              `""""

## Logos contain extra $$ that are probably managed here: https://github.com/fastfetch-cli/fastfetch/blob/dev/src/common/printing.c

# === ESC + COLORS ===
ESC=$(printf '\033')

# Base ANSI colors for info display
R="${ESC}[1;31m"  # Bold Red
Y="${ESC}[1;33m"  # Bold Yellow
G="${ESC}[1;32m"  # Bold Green
B="${ESC}[1;34m"  # Bold Blue
M="${ESC}[1;35m"  # Bold Magenta
C="${ESC}[1;36m"  # Bold Cyan
W="${ESC}[1;37m"  # Bold White
N="${ESC}[0m"     # Reset

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
current_date=$(date '+%Y-%m-%d %H:%M:%S')

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

# Public IP and Location
public_ip_base=$(timeout 2 wget -qO- http://icanhazip.com 2>/dev/null || echo "N/A")

if [ "$public_ip_base" != "N/A" ]; then
    # Use ipinfo.io to get location data in JSON
    location_json=$(timeout 2 wget -qO- "http://ipinfo.io/${public_ip_base}/json" 2>/dev/null)
    
    # POSIX way to parse a simple JSON line for city
    # Note: This is fragile and assumes 'city' is on its own line and before other fields.
    # For complex JSON, jq is strongly recommended.
    city=$(printf '%s' "$location_json" | grep '"city":' | head -n 1 | awk -F'"' '{print $4}')
    
    if [ -n "$city" ]; then
        public_ip="${public_ip_base} (${city})"
    else
        public_ip="$public_ip_base"
    fi
else
    public_ip="N/A"
fi


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

# === DISTRO-SPECIFIC COLOR MAPPINGS ===
# Logo color tokens ($1-$9) map to distro-specific colors
# Colors persist until next color token (no auto-reset)
# Based on: https://github.com/fastfetch-cli/fastfetch/blob/dev/src/logo/builtin.c

# === DISTRO-SPECIFIC COLOR MAPPINGS ===
# Logo color tokens ($1-$9) map to distro-specific colors
# Colors persist until next color token (no auto-reset)
# Based on: https://github.com/fastfetch-cli/fastfetch/blob/dev/src/logo/builtin.c

case "$os_id" in
    debian)
        # FF_COLOR_FG_RED, FF_COLOR_FG_WHITE
        C1="${ESC}[31m"   # Red
        C2="${ESC}[37m"   # White
        ;;
    ubuntu)
        # FF_COLOR_FG_RED, FF_COLOR_FG_RED
        C1="${ESC}[31m"   # Red
        C2="${ESC}[31m"   # Red
        ;;
    kubuntu)
        # FF_COLOR_FG_BLUE, FF_COLOR_FG_WHITE
        C1="${ESC}[34m"   # Blue
        C2="${ESC}[37m"   # White
        ;;
    pfsense)
        # Not in the C file - using generic
        C1="${ESC}[31m"   # Red
        C2="${ESC}[37m"   # White
        ;;
    proxmox|pve)
        # FF_COLOR_FG_WHITE, FF_COLOR_FG_256 "202" (orange)
        C1="${ESC}[37m"      # White
        C2="${ESC}[38;5;202m"  # Orange (256-color)
        ;;
    openwrt)
        # FF_COLOR_FG_BLUE
        C1="${ESC}[34m"   # Blue
        C2="${ESC}[34m"   # Blue (single color logo)
        ;;
    q4os)
        # FF_COLOR_FG_BLUE, FF_COLOR_FG_RED
        C1="${ESC}[34m"   # Blue
        C2="${ESC}[31m"   # Red
        ;;
    *)
        # Generic fallback
        C1="${ESC}[32m"   # Green
        C2="${ESC}[37m"   # White
        ;;
esac

# Set remaining color slots (most logos only use $1 and $2)
C3="${C1}"
C4="${C2}"
C5="${C1}"
C6="${C2}"
C7="${ESC}[37m"
C8="${ESC}[90m"
C9="${ESC}[30m"

# === TOKEN REPLACEMENT (no bashism) ===
# Replace color tokens with ANSI codes
# Note: Colors persist until next token (fastfetch behavior)
logo_processed=$(
  printf '%s' "$logo_raw" | \
  sed "s/\$1/${C1}/g" | sed "s/\$2/${C2}/g" | sed "s/\$3/${C3}/g" | \
  sed "s/\$4/${C4}/g" | sed "s/\$5/${C5}/g" | sed "s/\$6/${C6}/g" | \
  sed "s/\$7/${C7}/g" | sed "s/\$8/${C8}/g" | sed "s/\$9/${C9}/g" | \
  sed "s/\$\[0m/$N/g" | sed "s/\$\[1m//g" | \
  sed "s/\$\[/${ESC}[/g" | \
  sed 's/[[:space:]]*$//' | \
  sed 's/\$\$/$/g'
)

# No additional processing - use as-is
logo="$logo_processed"

# === INFO BLOCK ===
info="${R}OS${N}:        $os
${R}Host${N}:      $host
${R}Kernel${N}:    $kernel
${R}Shell${N}:     $shell

${R}CPU${N}:       $cpu
${R}Memory${N}:    $memory
${R}Disk (/)${N}:  $disk
${R}Swap${N}:      $swap

${R}Public IP${N}: $public_ip
${R}Local IP${N}:  $local_ip
${R}Date${N}:      $current_date
${R}Uptime${N}:    $uptime

${B}████${R}████${Y}████${G}████${C}████${M}████${W}████${N}"

# === SIDE-BY-SIDE RENDER ===
logo_tmp="/tmp/banner_logo_$$"
info_tmp="/tmp/banner_info_$$"
stripped_logo="${logo_tmp}.stripped"

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

    printf " %s%s%s %s\n" "$logo_line" "$N" "$padstr" "$info_line"
    i=$((i+1))
done

# Cleanup
rm -f "$logo_tmp" "$info_tmp" "$stripped_logo"
