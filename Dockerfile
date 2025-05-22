# ------------------------------------------------------------
#  Build-time stage: compile everything into /build-out
# ------------------------------------------------------------
FROM i386/ubuntu:xenial AS builder

# --- Build tools & system libs ------------------------------------------------
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        gcc make pkg-config libtool automake autoconf \
        libpng-dev libjpeg-dev libfreetype6-dev libexpat1-dev \
        build-essential gcc-multilib git wget flex bison gperf \
        gettext libcurl4-openssl-dev:i386 \
        libfontconfig1-dev:i386 \
        libutf8proc-dev:i386 && \
    apt-get clean

# --- Environment -------------------------------------------------------------
ENV PREFIX=/usr/local
ENV PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
ENV LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}"
ENV PATH="${PREFIX}/bin:${PATH}"

WORKDIR /build

# --- Build NetSurf components -------------------------------------------------
# netsurf buildsystem (only if needed)
RUN wget https://git.netsurf-browser.org/buildsystem.git/snapshot/buildsystem-release/1.10.tar.gz && \
    tar xzf 1.10.tar.gz && \
    cd buildsystem-release/1.10 && \
    make install PREFIX=${PREFIX}

# Build all libs from netsurf libs/releases

# libwapcaplet
RUN wget https://download.netsurf-browser.org/libs/releases/libwapcaplet-0.4.3-src.tar.gz && \
    tar xzf libwapcaplet-0.4.3-src.tar.gz && \
    cd libwapcaplet-0.4.3 && \
    make && make install PREFIX=${PREFIX}

# libparserutils 0.2.4
RUN wget https://download.netsurf-browser.org/libs/releases/libparserutils-0.2.4-src.tar.gz && \
    tar xzf libparserutils-0.2.4-src.tar.gz && \
    cd libparserutils-0.2.4 && \
    make && make install PREFIX=${PREFIX}

# libparserutils 0.2.5 (newer version, might overwrite 0.2.4)
RUN wget https://download.netsurf-browser.org/libs/releases/libparserutils-0.2.5-src.tar.gz && \
    tar xzf libparserutils-0.2.5-src.tar.gz && \
    cd libparserutils-0.2.5 && \
    make && make install PREFIX=${PREFIX}

# libcss
RUN wget https://download.netsurf-browser.org/libs/releases/libcss-0.9.2-src.tar.gz && \
    tar xzf libcss-0.9.2-src.tar.gz && \
    cd libcss-0.9.2 && \
    make && make install PREFIX=${PREFIX}

# libhubbub
RUN wget https://download.netsurf-browser.org/libs/releases/libhubbub-0.3.8-src.tar.gz && \
    tar xzf libhubbub-0.3.8-src.tar.gz && \
    cd libhubbub-0.3.8 && \
    make && make install PREFIX=${PREFIX}

# libnsutils
RUN wget https://download.netsurf-browser.org/libs/releases/libnsutils-0.1.1-src.tar.gz && \
    tar xzf libnsutils-0.1.1-src.tar.gz && \
    cd libnsutils-0.1.1 && \
    make && make install PREFIX=${PREFIX}

# libdom - note the naming difference for this one (from git)
RUN wget https://git.netsurf-browser.org/libdom.git/snapshot/libdom-release/0.4.2.tar.gz && \
    tar xzf 0.4.2.tar.gz && \
    cd libdom-release/0.4.2 && \
    make && make install PREFIX=${PREFIX}

# libsvgtiny
RUN wget https://download.netsurf-browser.org/libs/releases/libsvgtiny-0.1.8-src.tar.gz && \
    tar xzf libsvgtiny-0.1.8-src.tar.gz && \
    cd libsvgtiny-0.1.8 && \
    make && make install PREFIX=${PREFIX}

RUN wget https://download.netsurf-browser.org/libs/releases/libnsfb-0.2.2-src.tar.gz && \
    tar xzf libnsfb-0.2.2-src.tar.gz && \
    cd libnsfb-0.2.2 && \
    make && make install PREFIX=/usr/local

RUN wget https://download.netsurf-browser.org/libs/releases/libutf8proc-2.4.0-1-src.tar.gz && \
    tar xzf libutf8proc-2.4.0-1-src.tar.gz && \
    cd libutf8proc-2.4.0-1 && \
    make && make install PREFIX=/usr/local

RUN wget https://download.netsurf-browser.org/libs/releases/nsgenbind-0.9-src.tar.gz && \
    tar xzf nsgenbind-0.9-src.tar.gz && \
    cd nsgenbind-0.9 && \
    make && make install PREFIX=/usr/local

# netsurf itself
RUN wget https://download.netsurf-browser.org/netsurf/releases/source/netsurf-3.11-src.tar.gz && \
    tar xzf netsurf-3.11-src.tar.gz && \
    cd netsurf-3.11 && \
    make TARGET=framebuffer install PREFIX=${PREFIX} COMPONENT_TYPE=lib

# --- Collect artifacts --------------------------------------------------------
RUN mkdir -p /build-out/libs && \
    cp ${PREFIX}/bin/netsurf-fb /build-out/ && \
    cp -r ${PREFIX}/share/netsurf /build-out/ && \
    ldd ${PREFIX}/bin/netsurf-fb | awk '/=>/ && $3 ~ /^\// {print $3}' | xargs -r -I{} cp -v {} /build-out/libs/

# launcher
RUN echo '#!/bin/sh\nSCRIPT_DIR=$(dirname "$(readlink -f "$0")")\n'\
'export LD_LIBRARY_PATH="$SCRIPT_DIR/libs"\n'\
'"$SCRIPT_DIR/netsurf-fb" "file://$SCRIPT_DIR/index.html"\n' \
> /build-out/launch.sh && chmod +x /build-out/launch.sh

# ------------------------------------------------------------
#  Runtime stage
# ------------------------------------------------------------
FROM scratch

COPY --from=0 /build-out/ /
WORKDIR /

ENTRYPOINT ["/launch.sh"]