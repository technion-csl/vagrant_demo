#! /bin/bash

download_dir=/tmp
docker_pool_url=https://download.docker.com/linux/ubuntu/dists/bionic/pool/stable/amd64
cd $download_dir
wget $docker_pool_url/containerd.io_1.4.4-1_amd64.deb
wget $docker_pool_url/docker-ce-cli_20.10.5~3-0~ubuntu-bionic_amd64.deb
wget $docker_pool_url/docker-ce_20.10.5~3-0~ubuntu-bionic_amd64.deb
sudo dpkg -i containerd.io_1.4.4-1_amd64.deb
sudo dpkg -i docker-ce-cli_20.10.5~3-0~ubuntu-bionic_amd64.deb
sudo dpkg -i docker-ce_20.10.5~3-0~ubuntu-bionic_amd64.deb
echo
if [[ "$(groups)" == *"docker"* ]]; then
    echo "The user $USER belongs to the docker group"
else
    echo "The user $USER does not belong to the docker group"
    echo "Adding it via:"
    sudo adduser $USER docker
    echo "Please logout and login to belong to the new groups"
    exit -1 # stop the script
fi
# test that the installation succeeded
docker run hello-world
# remove the hello-world container
docker container prune -f
# automatically start docker on boot
sudo systemctl enable containerd.service
sudo systemctl enable docker.service

