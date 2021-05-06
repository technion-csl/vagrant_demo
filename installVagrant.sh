#! /bin/bash

# exit immediately if a command exits with a non-zero status
set -e

# install the dependencies recommended in https://github.com/vagrant-libvirt/vagrant-libvirt#readme
sudo apt build-dep -y vagrant ruby-libvirt
sudo apt install -y qemu libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
sudo apt install -y libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev

# install the libvirt plugin
# remember that this script assumes it is called from the makefile,
# so we have "export VAGRANT_HOME := $(ROOT_DIR)/.vagrant.d"
vagrant_plugin=vagrant-libvirt
if [[ $(vagrant plugin list) == *"$vagrant_plugin"* ]] ; then
    echo "$vagrant_plugin is installed"
else
    echo "$vagrant_plugin is currently not installed"
    echo "going to install it via:"
    vagrant plugin install $vagrant_plugin
fi

