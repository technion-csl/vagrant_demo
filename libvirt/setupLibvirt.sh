#! /bin/bash

# use "bash strict mode" (http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail

function installLibvirt {
    $APT_INSTALL cpu-checker qemu-kvm libvirt-clients libvirt-dev libvirt-daemon-system
    kvm_device=/dev/kvm
    if [ ! -c "$kvm_device" ]; then
        sudo modprobe --remove kvm-intel kvm # kvm_intel should be removed first because it uses kvm
    fi
    sudo modprobe --all kvm kvm_intel # --all to load multiple modules with the same command
    sudo chmod a+rw $kvm_device
    sudo chmod a+rw /var/run/libvirt/libvirt-sock
    sudo systemctl start libvirtd
}

function testLibvirt {
    if [[ "$(virt-host-validate qemu)" == *"FAIL"* ]]; then
        echo "There is a problem in the host virtualization setup"
        exit -1 # stop the script
    fi
}

function editLibvirtSettings {
    current_settings_file=/etc/libvirt/$1
    script_directory=$(dirname "$0")
    new_settings_file=$script_directory/$1
    grep_results=$(sudo grep "CSL settings" $current_settings_file || true)
    if [ -z "$grep_results" ]; then
        echo moving the current $current_settings_file settings to $current_settings_file.old...
        sudo mv $current_settings_file $current_settings_file.old
        echo copying the custom CSL settings into $current_settings_file...
        sudo cp $new_settings_file $current_settings_file
    else
        echo the current $current_settings_file settings are OK!
    fi
    sudo systemctl restart libvirtd
}

installLibvirt
editLibvirtSettings qemu.conf
editLibvirtSettings libvirtd.conf
testLibvirt

