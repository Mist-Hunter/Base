#!/bin/bash

# Line rules
# These rules color the entire line based on the matched pattern

# Highlight critical errors and high-priority messages
LINE_RULE_1="(ERROR|CRITICAL|ALERT|EMERGENCY):BOLD_RED"

# Highlight warnings
LINE_RULE_2="(WARNING|WARN):BOLD_YELLOW"

# Highlight informational and notice messages
LINE_RULE_3="(INFO|NOTICE):WHITE"

# Highlight debug messages
LINE_RULE_4="(DEBUG):BLUE"

# Highlight success messages
LINE_RULE_5="(success|succeeded|Succeeded|Success):BOLD_GREEN"

# Highlight failure messages
LINE_RULE_6="(fail|failed|Fail|Failed|FAIL|FAILED):BOLD_RED"

# Word rules
# These rules color specific words or patterns within a line

# Highlight common system service names and kernel messages
WORD_RULE_1="(systemd\[\d+\]|kernel:|sshd\[\d+\]|sudo:):BOLD_MAGENTA"

# Highlight IP addresses
WORD_RULE_2="([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}):CYAN"

# Highlight MAC addresses
WORD_RULE_3="([0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}):CYAN"

# Highlight quoted strings
# FIXME caused infinite loop
# WORD_RULE_4="(\"[^\"]*\"):YELLOW"

# Highlight filenames with common extensions
WORD_RULE_5="(\w+\.(?:cpp|h|py|sh|conf|log|txt|service)):BOLD_CYAN"

# Highlight user references
WORD_RULE_6="([Uu]ser\s+\w+):MAGENTA"

# Highlight process IDs
WORD_RULE_7="(pid\s+\d+):BLUE"

# Highlight short date-time format (e.g., "Jan 23 14:30:01")
WORD_RULE_8="(\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\b):WHITE"

# Highlight long date-time format (e.g., "Mon Jan 23 14:30:01 2023")
WORD_RULE_9="((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4}):WHITE"