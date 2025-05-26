#!/bin/bash
IMAGE_NAME=netsurf-builder:latest
CONTAINER_NAME=netsurf-temp-copy

# Build the image
docker build -t $IMAGE_NAME .

# Run container in detached mode (so it exists but does nothing)
docker create --name $CONTAINER_NAME $IMAGE_NAME

# Copy the build output folder to local host
docker cp $CONTAINER_NAME:/build-out/WebKitUI/dist ./dist

# Remove temporary container
docker rm $CONTAINER_NAME
