#!/bin/bash

runonceunits=$(cd /etc/systemd/system/ && ls *runonce*)
if [ -z "$runonceunits" ]
then
      echo "\$runonceunits is empty"
else
    for servicename in $runonceunits
    do
        systemctl disable $servicename
        rm /etc/systemd/system/$servicename
        systemctl daemon-reload
    done
fi