# syntax=docker/dockerfile:1.4
FROM --platform=linux/386 i386/debian:buster-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    ca-certificates \
    libssl-dev \
    libpng-dev \
    zlib1g-dev \
    pkg-config \
    patchelf \
    && rm -rf /var/lib/apt/lists/*

ENV PREFIX=/opt/netsurf
ENV PATH=$PREFIX/bin:$PATH
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH

WORKDIR /build

# Build system
RUN wget https://git.netsurf-browser.org/buildsystem.git/snapshot/buildsystem-release/1.10.tar.gz && \
    tar xzf buildsystem-release-1.10.tar.gz && \
    cd buildsystem-release/1.10 && \
    make install PREFIX=$PREFIX


# Download minimal required libraries
RUN wget https://download.netsurf-browser.org/libs/releases/libwapcaplet-0.4.3-src.tar.gz && tar xzf *.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libnsfb-0.2.2-src.tar.gz && tar xzf *.tar.gz && \
    wget https://download.netsurf-browser.org/netsurf/releases/source/netsurf-3.11-src.tar.gz && tar xzf *.tar.gz

# Build libraries
WORKDIR /build/libwapcaplet-0.4.3
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libnsfb-0.2.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

# Build NetSurf framebuffer frontend
WORKDIR /build/netsurf-3.11
COPY <<EOF framebuffer/Config
override NETSURF_USE_SSL := NO
override NETSURF_USE_VIDEO := NO
override NETSURF_USE_MOZJS := NO
override NETSURF_USE_JS := NO
EOF

RUN make TARGET=framebuffer PREFIX=$PREFIX && \
    make install TARGET=framebuffer PREFIX=$PREFIX

# Create final bundle
WORKDIR /dist
RUN cp $PREFIX/bin/netsurf-fb . && \
    cp -r $PREFIX/share/netsurf ./share && \
    echo '<html><body><h1>NetSurf Works!</h1></body></html>' > index.html

# Copy required libraries
RUN ldd netsurf-fb | awk '/=>/ {print $3}' | xargs -I{} cp --parents {} . && \
    cp /lib/ld-linux.so.2 . && \
    patchelf --set-interpreter ./ld-linux.so.2 netsurf-fb

# Create launch script
COPY <<EOF launch.sh
#!/bin/sh
export LD_LIBRARY_PATH=.
export NETSURFRES=./share/netsurf
exec ./netsurf-fb file://./index.html
EOF

RUN chmod +x launch.sh