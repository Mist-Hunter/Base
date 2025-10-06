#!/bin/sh

# Updated test for logo fetching from fastfetch repo - now auto-detects os_id like original
# Run this to debug on your actual system: prints os_id, URLs tried, and logo to terminal
# Debian Banner: https://github.com/fastfetch-cli/fastfetch/blob/dev/src/logo/ascii/debian.txt

# === AUTO-DETECT OS ===
if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_id="${ID:-linux}"
else
    os_id="linux"
fi

# === SETUP ===
cache_dir="${HOME}/.cache/banner_test"
logo_file="${cache_dir}/${os_id}.txt"

mkdir -p "$cache_dir" 2>/dev/null

# Clear cache for fresh test
rm -f "$logo_file"

echo "Debug: os_id = $os_id (auto-detected)"
echo "Debug: cache_dir = $cache_dir"

# === TRY FETCH (CORRECTED PATHS) ===
if [ ! -f "$logo_file" ] || [ ! -s "$logo_file" ]; then
    # Main logo
    logo_url="https://raw.githubusercontent.com/fastfetch-cli/fastfetch/dev/src/logo/ascii/${os_id}.txt"
    echo "Trying main URL: $logo_url"
    if ! timeout 3 wget -O "$logo_file.tmp" "$logo_url" 2>/dev/null || [ ! -s "$logo_file.tmp" ]; then
        rm -f "$logo_file.tmp"
        logo_url="https://raw.githubusercontent.com/fastfetch-cli/fastfetch/v2.20.0/src/logo/ascii/${os_id}.txt"  # Adjust tag!
        echo "Dev failed; trying stable: $logo_url"
        timeout 3 wget -O "$logo_file.tmp" "$logo_url" 2>/dev/null
    fi
    if [ -s "$logo_file.tmp" ]; then
        mv "$logo_file.tmp" "$logo_file"
        echo "Success: Main logo downloaded (${os_id}.txt)"
    else
        echo "Warning: Downloaded but empty file"
        rm -f "$logo_file.tmp"
    fi
    
    # Small logo fallback (appended _small, same dir)
    if [ ! -s "$logo_file" ]; then
        logo_url="https://raw.githubusercontent.com/fastfetch-cli/fastfetch/dev/src/logo/ascii/${os_id}_small.txt"
        echo "Trying small URL: $logo_url"
        if timeout 3 wget -O "$logo_file.tmp" "$logo_url" 2>/dev/null; then
            if [ -s "$logo_file.tmp" ]; then
                mv "$logo_file.tmp" "$logo_file"
                echo "Success: Small logo downloaded (${os_id}_small.txt)"
            else
                echo "Warning: Downloaded but empty file"
                rm -f "$logo_file.tmp"
            fi
        else
            echo "Failed: wget exit code $? (network/404/timeout?)"
            rm -f "$logo_file.tmp"
        fi
    fi
fi

# === OUTPUT LOGO TO TERMINAL ===
echo ""
echo "=== FETCHED LOGO (or fallback) ==="
# === FASTFETCH INTERPRETER (POSIX sed) ===
logo=""  # Initialize empty
if [ -f "$logo_file" ] && [ -s "$logo_file" ]; then
    logo=$(cat "$logo_file")
    
    # Define color palette with actual ESC bytes via printf (POSIX-compatible)
    # $1=Red (accents), $2=Yellow (body), $3=Green (highlights), $4=Blue, etc.
    C1=$(printf '\033[1;31m')  # Red
    C2=$(printf '\033[1;33m')  # Yellow
    C3=$(printf '\033[1;32m')  # Green
    C4=$(printf '\033[1;34m')  # Blue
    C5=$(printf '\033[1;35m')  # Magenta
    C6=$(printf '\033[1;36m')  # Cyan
    C7=$(printf '\033[1;37m')  # White
    C8=$(printf '\033[0;90m')  # Gray (dim)
    C9=$(printf '\033[1;30m')  # Black (bold, for shadows)
    N=$(printf '\033[0m')      # Reset (use after if needed, but fastfetch doesn't auto-reset per char)
    
    # Process: Pipe to sed for replacements (handles multi-line)
    # Note: Use a temp file or command sub to build sed expr safely
    sed_expr="s/\$1/${C1}/g
s/\$2/${C2}/g
s/\$3/${C3}/g
s/\$4/${C4}/g
s/\$5/${C5}/g
s/\$6/${C6}/g
s/\$7/${C7}/g
s/\$8/${C8}/g
s/\$9/${C9}/g
s/\\$\\$/\\$/g"  # FIX: Replaces the literal "$$" (fastfetch escape) with "$"
    logo=$(printf '%s\n' "$logo" | sed "$sed_expr")
    echo "Success: Interpreted colors in logo"
else
    # Generic fallback (plain or colored) - use heredoc for multi-line
    cat << EOF
$(printf '    %s\n  (.. |%s\n  (<> |\n  / __  \\\n ( /  \\ /|\n_/\ \__)/_)\n\\/-____\\/%s\n' "$C4" "$N" "$N")
EOF
    echo "Used fallback (no download succeeded)"
    logo=""  # No need to print again
fi

# Now print the processed logo (if fetched)
if [ -n "$logo" ]; then
    printf '%s\n' "$logo"
fi
echo "=== END LOGO ==="

# Cleanup (after printing)
rm -f "$logo_file" "$logo_file.tmp"
echo ""
echo "Test complete. Check output above for clues."
