FROM i386/ubuntu:xenial

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
        build-essential \
        gcc-multilib \
        pkg-config \
        patchelf \
        rsync \
        xvfb x11-xkb-utils \
        libgtk-3-dev:i386 \
        libwebkit2gtk-4.0-dev:i386 \
        libglib2.0-dev:i386 \
        libc6-dev \
        libgdk-pixbuf2.0-dev:i386 \
        libsoup2.4-dev:i386 \
        xserver-xorg-core:i386 \
        xserver-xorg-input-evdev:i386 \
        xserver-xorg-video-dummy:i386 \
        xserver-xorg-input-libinput:i386 \
        ttf-dejavu-core \
        && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

CMD ["./build.sh"]