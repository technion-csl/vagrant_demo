#! /bin/bash

# use "bash strict mode" (http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail

# install the dependencies recommended in https://github.com/vagrant-libvirt/vagrant-libvirt#readme
apt_install="sudo apt install -y"
$apt_install vagrant ruby-libvirt
$apt_install qemu libvirt-daemon-system libvirt-clients ebtables dnsmasq-base
$apt_install libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev

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

