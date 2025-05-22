# ------------------------------------------------------------
#  Build-time stage: compile everything into /build-out
# ------------------------------------------------------------
FROM --platform=linux/386 i386/ubuntu:xenial AS builder

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
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- Environment -------------------------------------------------------------
ENV PREFIX=/usr/local
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
ENV LD_LIBRARY_PATH=/usr/local/lib
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
    make && make install PREFIX=${PREFIX}

RUN wget https://download.netsurf-browser.org/libs/releases/libutf8proc-2.4.0-1-src.tar.gz && \
    tar xzf libutf8proc-2.4.0-1-src.tar.gz && \
    cd libutf8proc-2.4.0-1 && \
    make && make install PREFIX=${PREFIX}

RUN wget https://download.netsurf-browser.org/libs/releases/nsgenbind-0.9-src.tar.gz && \
    tar xzf nsgenbind-0.9-src.tar.gz && \
    cd nsgenbind-0.9 && \
    make && make install PREFIX=${PREFIX}

# netsurf itself
RUN wget https://download.netsurf-browser.org/netsurf/releases/source/netsurf-3.11-src.tar.gz && \
    tar xzf netsurf-3.11-src.tar.gz && \
    cd netsurf-3.11 && \
    env PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig make TARGET=framebuffer install PREFIX=${PREFIX} COMPONENT_TYPE=lib

# --- Collect artifacts --------------------------------------------------------
RUN mkdir -p /build-out/libs && \
    cp ${PREFIX}/bin/netsurf-fb /build-out/ && \
    cp -r ${PREFIX}/share/netsurf /build-out/ && \
    # Copy all required libraries
    ldd ${PREFIX}/bin/netsurf-fb | awk '/=>/ {print $3}' | grep -v '^$' | xargs -I{} cp -v {} /build-out/libs/ && \
    # Copy essential config files
    cp ${PREFIX}/etc/netsurf/* /build-out/ 2>/dev/null || :
# Create dist structure with ALL required files
RUN mkdir -p /build-out/WebKitUI/dist && \
    # Executable
    cp /build-out/netsurf-fb /build-out/WebKitUI/dist/ && \
    # Libraries
    cp -r /build-out/libs /build-out/WebKitUI/dist/ && \
    # Resources
    cp -r /build-out/share /build-out/WebKitUI/dist/ && \
    # Config files
    [ -d /build-out/etc ] && cp -r /build-out/etc /build-out/WebKitUI/dist/ || : && \
    # Create launcher script
    echo '#!/bin/sh\n\
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")\n\
export LD_LIBRARY_PATH="$SCRIPT_DIR/libs"\n\
export NETSURFRES="$SCRIPT_DIR/share/netsurf"\n\
export FRAMEBUFFER=/dev/fb0\n\
exec "$SCRIPT_DIR/netsurf-fb" "file://$SCRIPT_DIR/index.html"' > /build-out/WebKitUI/dist/launch.sh && \
    chmod +x /build-out/WebKitUI/dist/launch.sh && \
    # Create minimal test page
    echo '<html><body><h1>NetSurf Works!</h1></body></html>' > /build-out/WebKitUI/dist/index.html
# ------------------------------------------------------------
#  Runtime stage
# ------------------------------------------------------------
FROM scratch

COPY --from=builder /build-out/WebKitUI/dist /WebKitUI/dist
WORKDIR /WebKitUI/dist

# Needed environment variables
ENV LD_LIBRARY_PATH=/WebKitUI/dist/libs
ENV NETSURFRES=/WebKitUI/dist/share/netsurf
ENV FRAMEBUFFER=/dev/fb0

ENTRYPOINT ["./launch.sh"]
