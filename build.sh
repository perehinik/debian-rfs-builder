#!/bin/bash

DOCKER_IMAGE=debian-rfs-builder:1.0.1

if [ -z "$(docker images -q ${DOCKER_IMAGE} 2> /dev/null)" ]; then
  docker build . -t ${DOCKER_IMAGE}
fi
docker run -it --rm --privileged -v ./aarch64-minimal:/root -w /root -u root --entrypoint ./steps.sh ${DOCKER_IMAGE}
