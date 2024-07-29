#!/bin/bash

# TODO detect default hostames
source /etc/os-release
os_label="${ID^}"
template_name="Template-$os_label-$version_id$(date +'%Y%m%d')"
read -p "Current hostname is '$(hostname)', Set default template hostname to '$template_name'?" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  . $SCRIPTS/apt/hostname/newhost.sh "$template_name"
fi