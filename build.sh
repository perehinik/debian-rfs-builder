#!/bin/bash

docker run -it --privileged -v ./aarch64-minimal:/root -w /root --entrypoint ./steps.sh ubuntu:22.04
