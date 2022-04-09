#!/usr/bin/env bash

mkdir out/
docker build -t chroot-builder .
docker run -v $(pwd)/out:/out --privileged chroot-builder:latest
