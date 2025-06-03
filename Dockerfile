# syntax=docker/dockerfile:1.4
FROM --platform=linux/386 i386/debian:buster-slim AS builder

# Install required system dependencies + imagemagick
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
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
    libnghttp2-14 \
    librtmp1 \
    libssh2-1 \
    libpsl5 \
    libldap-2.4-2 \
    libidn2-0 \
    libunistring2 \
    libkrb5-3 \
    libgssapi-krb5-2 \
    libk5crypto3 \
    libcom-err2 \
    libkeyutils1 \
    libfuse2 \
    desktop-file-utils \
    xz-utils \
    python3 \
    libgpgme-dev \
    libassuan-dev \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

ENV PREFIX=/opt/netsurf
ENV PATH=$PREFIX/bin:$PATH
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
ENV LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH

WORKDIR /build

# Install CMake 3.25.2
RUN wget https://cmake.org/files/v3.25/cmake-3.25.2.tar.gz && \
    tar -xzf cmake-3.25.2.tar.gz && \
    cd cmake-3.25.2 && \
    ./bootstrap --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf cmake-3.25.2*

# Buildsystem and source fetching
RUN wget -O buildsystem.tar.gz https://git.netsurf-browser.org/buildsystem.git/snapshot/buildsystem-release/1.10.tar.gz && \
    tar xzf buildsystem.tar.gz && cd buildsystem-release/1.10 && make install PREFIX=$PREFIX

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

# Build netsurf framebuffer
WORKDIR /build/netsurf-3.11
RUN sed -i '1i #ifdef NETSURF_USE_CURL' content/fetchers/curl.h && echo '#endif' >> content/fetchers/curl.h && echo '/* stub curl.c */' > content/fetchers/curl.c && \
    make TARGET=framebuffer PREFIX=$PREFIX NETSURF_USE_SSL=NO NETSURF_USE_VIDEO=NO NETSURF_USE_MOZJS=NO NETSURF_USE_JS=NO NETSURF_USE_CURL=NO NETSURF_USE_FETCH_CURL=NO NETSURF_USE_JPEG=NO && \
    make install TARGET=framebuffer PREFIX=$PREFIX

# Create AppDir
WORKDIR /AppDir
RUN mkdir -p usr/bin usr/lib usr/share/netsurf && \
    cp $PREFIX/bin/netsurf-fb usr/bin/ && \
    cp -r $PREFIX/share/netsurf/* usr/share/netsurf/ && \
    echo '<html><body><h1>NetSurf Works!</h1></body></html>' > usr/share/netsurf/index.html

# Generate dummy icon
RUN convert -size 256x256 xc:none netsurf.png

# Improved library bundling with recursive dependency resolution
WORKDIR /AppDir/usr/lib

# Copy dynamic linker with correct architecture
RUN cp /lib/ld-linux.so.2 .

# Copy direct dependencies
RUN ldd ../bin/netsurf-fb | awk '/=> \// {print $3}' | xargs -I{} cp -L -n {} . || true

# Recursive dependency copying
RUN while true; do \
        missing=0; \
        for lib in *.so*; do \
            deps=$(ldd "$lib" 2>/dev/null | awk '/=> \// {print $3}' | grep -v '^$' || true); \
            for dep in $deps; do \
                base=$(basename "$dep"); \
                if [ -f "$dep" ] && [ ! -f "$base" ]; then \
                    cp -L -n "$dep" .; \
                    missing=1; \
                fi; \
            done; \
        done; \
        [ "$missing" = 0 ] && break; \
    done

# Verify all libraries are present
RUN echo "Verifying libraries:" && \
    ldd ../bin/netsurf-fb | awk '/not found/ {print "Missing library:", $1}' && \
    ! ldd ../bin/netsurf-fb | grep -q 'not found'

# Set RPATH for all libraries
RUN find . -maxdepth 1 -type f -name '*.so*' -exec patchelf --set-rpath '$ORIGIN' {} \; || true

# Patch main binary with correct rpath (but don't change interpreter)
RUN patchelf --set-rpath '$ORIGIN/../lib' ../bin/netsurf-fb

# Create AppRun script that uses the bundled dynamic linker explicitly
WORKDIR /AppDir
RUN echo '#!/bin/sh\nexport HERE="$(dirname "$(readlink -f "$0")")"\nexport LD_LIBRARY_PATH="$HERE/usr/lib"\nexport NETSURFRES="$HERE/usr/share/netsurf"\nexec "$HERE/usr/lib/ld-linux.so.2" "$HERE/usr/bin/netsurf-fb" file://"$HERE/usr/share/netsurf/index.html"' > AppRun && \
    chmod +x AppRun

# Create desktop entry
RUN echo '[Desktop Entry]\nType=Application\nName=NetSurf FB\nExec=AppRun\nIcon=netsurf\nCategories=Network;WebBrowser;' > netsurf.desktop

# AppImage tooling
WORKDIR /appimagetool_build
RUN wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-i686.AppImage && \
    chmod +x appimagetool-i686.AppImage

# Build AppImage
WORKDIR /
RUN /appimagetool_build/appimagetool-i686.AppImage --appimage-extract && \
    ./squashfs-root/AppRun /AppDir /netsurf-fb-i386.AppImage

# Export result
FROM scratch AS export-stage
COPY --from=builder /netsurf-fb-i386.AppImage /netsurf-fb-i386.AppImage