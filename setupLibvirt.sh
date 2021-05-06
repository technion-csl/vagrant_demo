#! /bin/bash

# exit immediately if a command exits with a non-zero status
set -e

function editLibvirtSettings {
    settings_file=$1
    current_settings_file=/etc/libvirt/$settings_file
    grep_results=$(sudo grep "CSL settings" $current_settings_file || true)
    if [ -z "$grep_results" ]; then
        echo moving the current $current_settings_file settings to $current_settings_file.old...
        sudo mv $current_settings_file $current_settings_file.old
        echo copying the custom CSL settings into $current_settings_file...
        sudo cp ./$settings_file $current_settings_file
    else
        echo the current $current_settings_file setting are OK!
    fi
}

sudo apt install -y cpu-checker qemu-kvm libvirt-clients libvirt-dev libvirt-daemon-system
sudo modprobe kvm kvm_intel
sudo chown root:kvm /dev/kvm
sudo chmod g+rw /dev/kvm
if [[ "$(virt-host-validate qemu)" == *"FAIL"* ]]; then
    echo "There is a problem in the host virtualization setup"
    exit -1 # stop the script
fi
sudo systemctl start libvirtd

editLibvirtSettings qemu.conf
editLibvirtSettings libvirtd.conf
