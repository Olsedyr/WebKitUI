# Use a 32-bit base image
FROM i386/ubuntu:16.04

# Install required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    squashfs-tools \
    pkg-config \
    libgtk-3-dev \
    libwebkit2gtk-4.0-dev \
    wget \
    fuse \
    libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libenchant1c2a \
    libsecret-1-0 \
    libhyphen0 \
    libssl-dev \
    libgpgme11 \
    libfuse2 \
    patchelf \
    libglib2.0-bin \
    libfuse-dev \
    libgpgme11:i386 \
    libfuse2:i386   \
    appstream

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Compile the app
RUN gcc -m32 -o minimal-ui main.c $(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.0) && \
    patchelf --set-rpath '$ORIGIN/../lib' minimal-ui

# Prepare AppDir layout
RUN mkdir -p \
    AppDir/usr/bin \
    AppDir/usr/lib \
    AppDir/usr/lib/i386-linux-gnu \
    AppDir/usr/share/minimal-ui \
    AppDir/usr/share/glib-2.0/schemas \
    AppDir/usr/share/applications \
    AppDir/usr/share/icons/hicolor/128x128/apps

# Copy core app files
RUN cp minimal-ui AppDir/usr/bin/ && \
    cp index.html AppDir/usr/share/minimal-ui/ && \
    cp minimalui.desktop AppDir/usr/share/applications/ && \
    cp minimalui.png AppDir/usr/share/icons/hicolor/128x128/apps/

# Create symlink for icon
RUN ln -s ../../share/icons/hicolor/128x128/apps/minimalui.png AppDir/minimalui.png

# Copy necessary libraries into the AppImage
RUN cp -a /usr/lib/i386-linux-gnu/lib{gtk-3*,gdk-3*,webkit2gtk-4.0*,javascriptcoregtk-4.0*,soup-2.4*,gio-2.0*,gobject-2.0*,glib-2.0*,gstreamer*,secret*} AppDir/usr/lib/ || true && \
    cp -a /usr/lib/i386-linux-gnu/gdk-pixbuf-2.0 AppDir/usr/lib/ && \
    cp -a /usr/share/glib-2.0/schemas/*.gschema.xml AppDir/usr/share/glib-2.0/schemas/
# Compile schemas
RUN glib-compile-schemas AppDir/usr/share/glib-2.0/schemas/

# Create AppRun
RUN echo '#!/bin/sh' > AppDir/AppRun && \
    echo 'exec "$(dirname "$0")/usr/bin/minimal-ui" "$@"' >> AppDir/AppRun && \
    chmod +x AppDir/AppRun

# Install appimagetool
RUN wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-i686.AppImage \
    && chmod +x appimagetool-i686.AppImage \
    && ./appimagetool-i686.AppImage --appimage-extract \
    && mv squashfs-root/usr/bin/appimagetool /usr/local/bin/ \
    && rm -rf appimagetool-i686.AppImage squashfs-root

# Build the AppImage
# Install appimagetool
COPY appimagetool-i686.AppImage /app/
RUN chmod +x /app/appimagetool-i686.AppImage

# Build the AppImage (this step will bundle the app with the required libs)
#RUN /app/appimagetool-i686.AppImage AppDir

# Cleanup (optional)
# RUN rm -rf AppDir