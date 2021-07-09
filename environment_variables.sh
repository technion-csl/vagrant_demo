#! /bin/bash
export ROOT_DIR=$PWD
# don't modify this variable because we rely on identical paths in the guest and host
export SHARED_VAGRANT_DIR=$ROOT_DIR
# change the directory where Vagrant stores global state because it is set to ~/.vagrant.d by default,
# and this causes conflicts between servers as the ~ directory is mounted on NFS.
export VAGRANT_HOME=$ROOT_DIR/.vagrant.d
export APT_INSTALL="sudo apt install -y"
export APT_REMOVE="sudo apt purge -y"
export VAGRANT_UP="vagrant up --provider=libvirt"
export VAGRANT_SSH="vagrant ssh"
export VAGRANT_HALT="vagrant halt || vagrant halt --force"
export VAGRANT_DESTROY="vagrant destroy --force"
