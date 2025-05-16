FROM i386/ubuntu:xenial

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        build-essential \
        gcc-multilib \
        pkg-config \
        patchelf \
        libgtk-3-dev:i386 \
        libwebkit2gtk-4.0-dev:i386 \
        libglib2.0-dev:i386 \
        libc6-dev:i386 \
        libgdk-pixbuf2.0-dev:i386 \
        libsoup2.4-dev:i386

WORKDIR /build
COPY . .