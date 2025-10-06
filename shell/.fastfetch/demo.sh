#!/bin/bash

# A script to demonstrate and render multiple colors in a POSIX terminal,
# identically reproducing the output from the provided fastfetch screenshot.

# --- Color Definitions (using 256-color ANSI escape codes) ---
# These specific codes are chosen to closely match the Debian logo colors
# used by fastfetch.
# \033[38;5;...m sets the foreground color.
# \033[0m resets all text formatting.

C1="\033[38;5;197m" # Light Red / Pink for the main swirl
C2="\033[38;5;160m" # Darker Red for accents
C3="\033[0;97m"     # Bright White for punctuation
TITLE="\033[38;5;197m" # Using the same Light Red for info titles
INFO="\033[0;97m"      # Bright White for info text
RESET="\033[0m"     # Resets all color and formatting attributes

# --- Render the Debian Logo ---
# Using `echo -e` to ensure the ANSI color escape codes are interpreted
# correctly by the terminal, fixing the rendering issue.
# The entire multi-line string is passed to a single `echo -e` command.

echo -e "\
${C2}           ,met${C1}\$\$gg.
${C2}        ,g\$\$${C1}\$\$\$\$\$\$\$\$\$P.
${C2}       ,g\$\$P${C3}\"\"       \"\"'${C1}Y\$\$\"${C3}.${RESET}
${C2}      ,\$\$P'              \"${C1}\$\$\$.${RESET}
${C2}     ',\$P       ${C2},ggs.     \"${C1}\$\$b:
${C2}     \`d\$\$'     ,\$P\"'   \"${C1}Y\$b\$P\"
${C2}      \$\$\$       d\$'     \`${C1}b\$\$P
${C2}      \$\$\$       \$\$.   -   ,${C1}d\$\$'
${C2}      \$\$\$       Y\$b._   _,${C1}d\$P'
${C2}      Y\$\$.    '${C3}. \`\"${C1}Y\$\$\$\$P\"'${RESET}
${C2}      \`\"${C1}Y\$b._\"${C3}\"      _\"${RESET}
${C2}        \`\"${C1}Y\$b._   -\"${RESET}
${C2}           \`\"${C1}Y\$\$\$b._
${C2}               \`\"${C1}Y\$b.
${C2}                   \"\"${RESET}"


# --- Mock System Info (for demonstration) ---
# The -e flag for echo enables the interpretation of backslash escapes (like \033).
# We manually add spacing to align the text, similar to the original output.
echo
echo -e "${TITLE}OS:${INFO}      Debian GNU/Linux bookworm 12.12 x86_64${RESET}"
echo -e "${TITLE}Kernel:${INFO}  Linux 6.1.0-37-amd64${RESET}"
echo -e "${TITLE}Shell:${INFO}   bash 5.2.15${RESET}"
echo

# --- Color Palette ---
# This loop generates the color blocks at the bottom.
# \033[48;5;...m sets the background color.
# We print two spaces with a colored background to create each block.

echo -n "        " # Indentation for the palette
# Print the 8 standard colors
for i in {0..7}; do
    echo -en "\033[48;5;${i}m  ${RESET}"
done
echo "" # Newline for the second row

echo -n "        " # Indentation for the palette
# Print the 8 bright colors
for i in {8..15}; do
    echo -en "\033[48;5;${i}m  ${RESET}"
done
echo "" # Final newline
echo ""

