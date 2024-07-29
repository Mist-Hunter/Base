# Create Serial Console
# Presumes a serial interface on tty0 in VM or device
# This step likely precedes this script running, commneting out.

sub="console=tty0 console=ttyS0,115200"
if [[ "$grub_cmdline_linux_default" == *"$sub"* ]]; then
    echo "system, debian-base, prepVM: GRUB Already present:  $(grep $sub /etc/default/grub)"
else
    echo "system, debian-base, prepVM: GRUB Adding $sub to $grub_cmdline_linux_default"
    sed -i 's/grub_cmdline_linux_default="[^"]*/& console=tty0 console=ttyS0,115200/' /etc/default/grub
    update-grub
fi
