#! /bin/bash

source global_variables.sh
docker rm --force $container_name
docker image rm --force $image_name

