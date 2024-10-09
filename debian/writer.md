writer should be a bash function that can write any content to a file, but it specializes in ENV / CONFIG files.
It supports:

--content
    multiline, variable expandable via "" vrs '', indent and leading white space tollerant.
--path
    required full path and name of output file
--source
    optionaly sources --path after completion


Support different levels of indentation while not passing indentation into file.

Examples
```bash
writer \
--path 'SNMP' \
--content '
export SNMP_PORT="161"
export SNMP_POLLER_FQDN="mistDockerGreen.lan"
export SNMP_LOCATION="Server Rack"
'

writer \
--path 'SNMP' \
--content '
    export SNMP_PORT="161"
    export SNMP_POLLER_FQDN="mistDockerGreen.lan"
    export SNMP_LOCATION="Server Rack"
'

if true; then
    writer \
    --path 'SNMP' \
    --content '
    export SNMP_PORT="161"
    export SNMP_POLLER_FQDN="mistDockerGreen.lan"
    export SNMP_LOCATION="Server Rack"
    '
fi
```

# TODO if not --source then don't use export?
# TODO create a sub function for writting contents thats automatically idempotent based on (unique) key_comment. Default will just be to append to --file assuring there's a space between last entry and new entry but should support options --comment that can be used for idempotence? Support 'Sections'

## sources, aliases
# TODO handle indents
# TODO handle single line edits idempotently
# TODO handle single value edits