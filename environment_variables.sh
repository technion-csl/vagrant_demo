#! /bin/bash
set -x # print the commands as they execute
export ROOT_DIR=$PWD
# don't modify this variable because we rely on identical paths in the guest and host
export SHARED_VAGRANT_DIR=$ROOT_DIR
# change the directory where Vagrant stores global state because it is set to ~/.vagrant.d by default,
# and this causes conflicts between servers as the ~ directory is mounted on NFS.
export VAGRANT_HOME=$ROOT_DIR/.vagrant.d
export APT_INSTALL="sudo apt install -y"
export APT_REMOVE="sudo apt purge -y"
