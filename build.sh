#!/bin/bash

DOCKER_IMAGE=debian-rfs-builder:1.0.1

# 1. Check if direectory with user scripts was specified
# 2. Check if that direcory contains user-steps.sh
# 3. Copy all data from dir spoecified by user to ./aarch64-minimal/user_steps

if [ -z "$(docker images -q ${DOCKER_IMAGE} 2> /dev/null)" ]; then
  docker build . -t ${DOCKER_IMAGE}
fi

docker run -it --rm --privileged -v ./aarch64-minimal:/root -w /root -u root --entrypoint ./steps.sh ${DOCKER_IMAGE}

mv -f ./aarch64-minimal/rootfs.img ./
