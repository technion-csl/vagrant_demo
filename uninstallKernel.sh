#! /bin/bash

# print commands and their arguments as they are executed
set -x
# exit immediately if a command in this script exits with a non-zero status
set -e

if [ "$#" -ne "1" ]; then
    echo "Usage: $0 kernel_name"
    exit -1
fi
kernel_name="$1"

rm -f /boot/vmlinuz-$kernel_name*
rm -f /boot/initrd.img-$kernel_name*
rm -f /boot/System.map-$kernel_name*
rm -f /boot/config-$kernel_name*
rm -f /var/lib/initramfs-tools/$kernel_name*
rm -rf /lib/modules/$kernel_name*/

update-grub

