#! /bin/bash

# exit immediately if a command exits with a non-zero status
set -e

image_name=idanyani/ubuntu20
container_name=ubuntu20
if [[ "$(docker images -q $image_name 2> /dev/null)" == "" ]]; then
    docker build --tag $image_name - < Dockerfile
fi
if [ ! "$(docker ps -q -f name=$container_name)" ]; then
    docker create --interactive --tty --name $container_name $image_name
fi
docker start $container_name
docker exec -it $container_name bash

