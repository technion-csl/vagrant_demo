#! /bin/bash

# exit immediately if a command exits with a non-zero status
set -e

function add_groups {
    user=$(whoami)
    groups=$(groups)
    for group in kvm libvirtd; do
        if [[ "$groups" == *"$group"* ]]; then
            echo "The user $user belongs to the $group group"
        else
            echo "The user $user does not belong to the $group group"
            echo "Adding it via:"
            sudo groupadd --force $group
            sudo adduser $user $group
            echo "Please logout and login to belong to the new groups"
            exit -1 # stop the script
        fi
    done
}

if [[ "$(whoami)" == "root" ]]; then
    echo "Running as the root user, which can run qemu and libvirt directly"
else
    add_groups
fi

sudo apt install -y cpu-checker qemu-kvm libvirt-clients libvirt-dev libvirt-daemon-system
sudo modprobe kvm kvm_intel
sudo chown root:kvm /dev/kvm
sudo chmod g+rw /dev/kvm
if [[ "$(virt-host-validate qemu)" == *"FAIL"* ]]; then
    echo "There is a problem in the host virtualization setup"
    exit -1 # stop the script
fi
sudo systemctl start libvirtd
sudo systemctl disable apparmor.service

