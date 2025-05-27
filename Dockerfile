# syntax=docker/dockerfile:1.4
FROM --platform=linux/386 i386/debian:buster-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    ca-certificates \
    pkg-config \
    patchelf \
    zlib1g-dev \
    libpng-dev \
    libssl-dev \
    libexpat1-dev \
    bison \
    flex \
    gperf \
    libcurl4-openssl-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PREFIX=/opt/netsurf
ENV PATH=$PREFIX/bin:$PATH
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
ENV LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH

WORKDIR /build

# Buildsystem
RUN wget -O buildsystem.tar.gz https://git.netsurf-browser.org/buildsystem.git/snapshot/buildsystem-release/1.10.tar.gz && \
    tar xzf buildsystem.tar.gz && \
    cd buildsystem-release/1.10 && make install PREFIX=$PREFIX

# Download and extract all required libraries
RUN wget https://download.netsurf-browser.org/libs/releases/libwapcaplet-0.4.3-src.tar.gz && tar xzf libwapcaplet-0.4.3-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libparserutils-0.2.5-src.tar.gz && tar xzf libparserutils-0.2.5-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libcss-0.9.2-src.tar.gz && tar xzf libcss-0.9.2-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libhubbub-0.3.8-src.tar.gz && tar xzf libhubbub-0.3.8-src.tar.gz && \
    wget -O libdom-release-0.4.2.tar.gz https://git.netsurf-browser.org/libdom.git/snapshot/libdom-release/0.4.2.tar.gz && tar xzf libdom-release-0.4.2.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libnsutils-0.1.1-src.tar.gz && tar xzf libnsutils-0.1.1-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libutf8proc-2.4.0-1-src.tar.gz && tar xzf libutf8proc-2.4.0-1-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/nsgenbind-0.9-src.tar.gz && tar xzf nsgenbind-0.9-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libnsfb-0.2.2-src.tar.gz && tar xzf libnsfb-0.2.2-src.tar.gz && \
    wget https://download.netsurf-browser.org/netsurf/releases/source/netsurf-3.11-src.tar.gz && tar xzf netsurf-3.11-src.tar.gz

# Build and install libraries in correct order
WORKDIR /build/libwapcaplet-0.4.3
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libparserutils-0.2.5
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libcss-0.9.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libhubbub-0.3.8
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libdom-release/0.4.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libnsutils-0.1.1
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libutf8proc-2.4.0-1
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/nsgenbind-0.9
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libnsfb-0.2.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/netsurf-3.11
RUN sed -i '1i #ifdef NETSURF_USE_CURL' content/fetchers/curl.h && \
    echo '#endif' >> content/fetchers/curl.h && \
    echo '/* stub curl.c */' > content/fetchers/curl.c && \
    make TARGET=framebuffer PREFIX=$PREFIX \
        NETSURF_USE_SSL=NO \
        NETSURF_USE_VIDEO=NO \
        NETSURF_USE_MOZJS=NO \
        NETSURF_USE_JS=NO \
        NETSURF_USE_CURL=NO \
        NETSURF_USE_FETCH_CURL=NO \
        NETSURF_USE_JPEG=NO && \
    make install TARGET=framebuffer PREFIX=$PREFIX









# Bundle everything into dist/
WORKDIR /dist
RUN cp $PREFIX/bin/netsurf-fb . && \
    cp -r $PREFIX/share/netsurf ./share && \
    echo '<html><body><h1>NetSurf Works!</h1></body></html>' > index.html

# Copy required libraries
RUN ldd netsurf-fb | awk '/=>/ {print $3}' | xargs -I{} cp --parents {} . && \
    cp /lib/ld-linux.so.2 . && \
    patchelf --set-interpreter ./ld-linux.so.2 netsurf-fb && \
    patchelf --set-rpath '$ORIGIN' netsurf-fb

# Create launch script
RUN echo '#!/bin/sh\nexport LD_LIBRARY_PATH=.\nexport NETSURFRES=./share/netsurf\nexec ./netsurf-fb file://./index.html' > launch.sh && \
    chmod +x launch.sh
