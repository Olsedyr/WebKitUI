# syntax=docker/dockerfile:1.4
FROM --platform=linux/386 i386/ubuntu:bionic AS builder

# Install dependencies
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        gcc \
        make \
        pkg-config \
        libtool \
        autoconf \
        automake \
        git \
        wget \
        curl \
        ca-certificates \
        build-essential \
        zlib1g-dev \
        libglib2.0-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libnspr4-dev \
        libnss3-dev \
        libx11-dev \
        libxrender-dev \
        libxt-dev \
        libxtst-dev \
        libxft-dev \
        libxinerama-dev \
        libxrandr-dev \
        libxcomposite-dev \
        libxcursor-dev \
        libxdamage-dev \
        libxext-dev \
        libxfixes-dev \
        libxpm-dev \
        libxaw7-dev \
        x11proto-core-dev \
        libxmu-dev \
        xutils-dev \
        python \
        perl \
        flex \
        bison \
        gperf \
        ruby \
        libpng-dev \
        libjpeg-dev \
        libgmp-dev \
        libexpat1-dev \
        libsqlite3-dev \
        libpango1.0-dev \
        libcairo2-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        patchelf \
        libssl1.1:i386 \
        libssl-dev:i386

ENV PREFIX=/opt/netsurf
ENV PATH=$PREFIX/bin:$PATH
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
ENV LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH

WORKDIR /build

# Buildsystem
RUN wget https://git.netsurf-browser.org/buildsystem.git/snapshot/buildsystem-release/1.10.tar.gz && \
    tar xzf 1.10.tar.gz && \
    mkdir -p $PREFIX && \
    cd buildsystem-release/1.10 && \
    make install PREFIX=$PREFIX

# Download and extract all sources
RUN wget https://download.netsurf-browser.org/libs/releases/libwapcaplet-0.4.3-src.tar.gz && tar xzf libwapcaplet-0.4.3-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libparserutils-0.2.5-src.tar.gz && tar xzf libparserutils-0.2.5-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libcss-0.9.2-src.tar.gz && tar xzf libcss-0.9.2-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libhubbub-0.3.8-src.tar.gz && tar xzf libhubbub-0.3.8-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libnsutils-0.1.1-src.tar.gz && tar xzf libnsutils-0.1.1-src.tar.gz && \
    wget https://git.netsurf-browser.org/libdom.git/snapshot/libdom-release/0.4.2.tar.gz && tar xzf 0.4.2.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libsvgtiny-0.1.8-src.tar.gz && tar xzf libsvgtiny-0.1.8-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libnsfb-0.2.2-src.tar.gz && tar xzf libnsfb-0.2.2-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/libutf8proc-2.4.0-1-src.tar.gz && tar xzf libutf8proc-2.4.0-1-src.tar.gz && \
    wget https://download.netsurf-browser.org/libs/releases/nsgenbind-0.9-src.tar.gz && tar xzf nsgenbind-0.9-src.tar.gz && \
    wget https://download.netsurf-browser.org/netsurf/releases/source/netsurf-3.11-src.tar.gz && tar xzf netsurf-3.11-src.tar.gz

# Build and install all required libraries (order matters)
WORKDIR /build/libwapcaplet-0.4.3
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libparserutils-0.2.5
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libcss-0.9.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libhubbub-0.3.8
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libnsutils-0.1.1
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libdom-release/0.4.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libsvgtiny-0.1.8
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libnsfb-0.2.2
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/libutf8proc-2.4.0-1
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

WORKDIR /build/nsgenbind-0.9
RUN make PREFIX=$PREFIX && make install PREFIX=$PREFIX

# Build NetSurf framebuffer frontend only
WORKDIR /build/netsurf-3.11
RUN make clean && \
    make TARGET=framebuffer PREFIX=$PREFIX && \
    make install TARGET=framebuffer PREFIX=$PREFIX && \
    ls -l $PREFIX/bin

# Create output folders
RUN mkdir -p /build-out/libs /build-out/share

# Copy the binary and bundled libs into build-out for packaging
RUN cp $PREFIX/bin/netsurf-fb /build-out/ && \
    cp -r $PREFIX/lib /build-out/libs && \
    cp -r $PREFIX/share/netsurf /build-out/share

# Copy all dependencies and patch them
RUN set -eux; \
    INTERP="$(ldd $PREFIX/bin/netsurf-fb | awk '/ld-linux/ {print $1}')"; \
    cp -v "$INTERP" /build-out/libs/; \
    find /usr/lib/i386-linux-gnu /lib/i386-linux-gnu $PREFIX/lib -type f \( -name "*.so*" -o -name "ld-*.so" \) | \
    while read LIB; do \
        if ldd $PREFIX/bin/netsurf-fb | grep -q "$LIB"; then \
            mkdir -p /build-out/libs/$(dirname "$LIB"); \
            cp -v "$LIB" /build-out/libs/"$LIB"; \
        fi; \
    done; \
    cp -v /usr/lib/i386-linux-gnu/libssl.so.1.1* /build-out/libs/; \
    cp -v /usr/lib/i386-linux-gnu/libcrypto.so.1.1* /build-out/libs/; \
    rm -f /build-out/libs/libssl.so.3* /build-out/libs/libcrypto.so.3*; \
    echo "=== SSL libraries ==="; \
    ls -l /build-out/libs/libssl* /build-out/libs/libcrypto*; \
    echo "====================="

# Patch all shared libraries and the main binary
RUN find /build-out/libs -type f -name "*.so*" | while read lib; do \
      echo "Patching $lib"; \
      patchelf --set-rpath '$ORIGIN' "$lib"; \
      for dep in $(patchelf --print-needed "$lib"); do \
        base_dep=$(basename "$dep"); \
        patchelf --replace-needed "$dep" "$base_dep" "$lib"; \
      done; \
    done && \
    patchelf --set-rpath '$ORIGIN/libs' /build-out/netsurf-fb && \
    patchelf --set-interpreter '$ORIGIN/libs/ld-linux.so.2' /build-out/netsurf-fb

# Final verification
RUN echo "=== Final ldd of netsurf-fb ===" && ldd /build-out/netsurf-fb

# Copy and run patch script BEFORE creating dist folder
COPY patch-libs.sh /patch-libs.sh
RUN chmod +x /patch-libs.sh && cd /build-out && /patch-libs.sh

# Create final dist folder with launch script and index.html
RUN mkdir -p /build-out/WebKitUI/dist && \
    cp /build-out/netsurf-fb /build-out/WebKitUI/dist/netsurf && \
    cp -r /build-out/libs /build-out/WebKitUI/dist/ && \
    cp -r /build-out/share /build-out/WebKitUI/dist/ && \
    printf '#!/bin/sh\nSCRIPT_DIR=$(dirname "$(readlink -f "$0")")\nexport LD_LIBRARY_PATH=$SCRIPT_DIR/libs:$LD_LIBRARY_PATH\nexport NETSURFRES="$SCRIPT_DIR/share/netsurf"\nexec "$SCRIPT_DIR/netsurf"