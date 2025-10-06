#!/bin/sh
# Test to see exactly what's happening with color codes

ESC=$(printf '\033')
N="${ESC}[0m"
R="${ESC}[1;31m"
Y="${ESC}[1;33m"

C1="$R"
C2="$Y"

# Simulate one problematic line from the logo
test_line=' $$$$P      d$'"'"'     $1,$2    $$$$P$'

echo "=== ORIGINAL LINE WITH TOKENS ==="
echo "$test_line"
echo ""

echo "=== AFTER OLD PROCESSING (no reset before color) ==="
processed_old=$(printf '%s' "$test_line" | \
  sed "s/\$1/$C1/g" | sed "s/\$2/$C2/g" | sed 's/\$\$/$/g')
printf '%s\n' "$processed_old"
echo ""

echo "=== AFTER NEW PROCESSING (reset before color) ==="
processed_new=$(printf '%s' "$test_line" | \
  sed "s/\$1/${N}${C1}/g" | sed "s/\$2/${N}${C2}/g" | sed 's/\$\$/$/g')
printf '%s\n' "$processed_new"
echo ""

echo "=== WITH END RESET ADDED ==="
printf '%s%s\n' "$processed_new" "$N"
echo ""

echo "=== WHAT FASTFETCH MIGHT DO (reset after EVERY token) ==="
# Maybe fastfetch adds reset after each color application?
processed_ff=$(printf '%s' "$test_line" | \
  sed "s/\$1/${C1}${N}/g" | sed "s/\$2/${C2}${N}/g" | sed 's/\$\$/$/g')
printf '%s\n' "$processed_ff"
echo ""

echo "Compare the outputs above. The yellow should only appear where $2 is explicitly set."