#!/bin/bash

# Line rules
LINE_RULE_1="(Shader|HDR|shader|WARNING|Unloading|Total:|UnloadTime|Camera|Null|null|NULL):$WHITE"
LINE_RULE_2="(Valheim l-.*|Load world:.*|isModded:.*|Am I Host\?|version|world):$YELLOW"
LINE_RULE_3="(Connections|ZDOS:|sent:|recv:|New connection|queue|connecting|Connecting|socket|Socket|RPC|Accepting connection|socket|msg|Connected|Got connection|handshake):$CYAN"
LINE_RULE_4="(New peer connected|<color=orange>.*</color>|ZDOID):$GREEN"
LINE_RULE_5="(ERROR:|Exception|HDSRDP|wrong password):${BOLD}${RED}"
LINE_RULE_6="(Added .* locations,|Loaded .* locations|Loading .* zdos|save|Save|backup):$MAGENTA"
LINE_RULE_7="(Console: ):$BLUE"

# Word rules
WORD_RULE_1="(varExp|\$SERVER_NAME|\$SERVER_PLAYER_PASS|\$WORLD_NAME):${BOLD}${YELLOW}"
WORD_RULE_2="(?:ZDOID from ([\w\s]+) :):${BOLD}${GREEN}"
WORD_RULE_3="(SteamID \d{17}|client \d{17}|socket \d{17}):${BOLD}${CYAN}"