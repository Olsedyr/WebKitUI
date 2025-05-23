#!/bin/bash

# Step 1: Build the Docker image
docker build -t netsurf-min .

# Step 2: Create the dist directory if it doesn't exist
mkdir -p ./WebKitUI/dist

# Step 3: Run the container and copy out the dist directory
docker run --rm -v $(pwd)/WebKitUI/dist:/out --entrypoint "" netsurf-min \
    cp -r /WebKitUI/dist/* /out/
