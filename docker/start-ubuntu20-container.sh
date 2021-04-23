#! /bin/bash

# exit immediately if a command exits with a non-zero status
set -e

source global_variables.sh
run_flags="--interactive --tty --privileged"
mount_flags="--mount type=bind,source=/lib/modules,destination=/lib/modules,readonly"
if [[ "$(docker images -q $image_name 2> /dev/null)" == "" ]]; then
    docker build --tag $image_name - < Dockerfile
fi
if [ ! "$(docker ps -q -f name=$container_name)" ]; then
    docker create $run_flags $mount_flags --name $container_name $image_name
fi
docker start $container_name
docker exec $run_flags $container_name bash

