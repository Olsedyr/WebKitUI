#!/bin/bash
set -e

IMAGE_NAME=webkitui-builder:temp
CONTAINER_NAME=temp-webkit-builder

# 1. Build only the build stage
docker build --target builder -t $IMAGE_NAME .

# 2. Create a container from it
docker create --name $CONTAINER_NAME $IMAGE_NAME

# 3. Copy out the build artifacts
rm -rf dist
docker cp $CONTAINER_NAME:/build-out ./dist

# 4. Clean up
docker rm $CONTAINER_NAME
