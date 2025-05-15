CC = gcc
CFLAGS = -m32 -Os -pipe -s `pkg-config --cflags gtk+-3.0 webkit2gtk-4.0`
LDLIBS = `pkg-config --libs gtk+-3.0 webkit2gtk-4.0`
LDFLAGS = -Wl,-rpath='$$ORIGIN/libs'

# Explicit list of core required libraries (to reduce bundle size)
CORE_LIBS = \
    libgtk-3.so.0 \
    libwebkit2gtk-4.0.so.37 \
    libcairo.so.2 \
    libgdk-3.so.0 \
    libpango-1.0.so.0 \
    libpangocairo-1.0.so.0 \
    libgio-2.0.so.0 \
    libgobject-2.0.so.0 \
    libglib-2.0.so.0 \
    libgmodule-2.0.so.0

.PHONY: all clean bundle installer

all: minimal-ui

minimal-ui: main.c
	$(CC) $(CFLAGS) $< -o $@ $(LDLIBS) $(LDFLAGS)

bundle: all
	rm -rf dist
	mkdir -p dist/libs \
	         dist/share/glib-2.0/schemas \
	         dist/etc/fonts \
	         dist/etc/ssl/certs

	# Copy binary and HTML
	cp minimal-ui index.html dist/

	# Copy core libs from ldconfig
	for lib in $$(echo $(CORE_LIBS)); do \
		path=$$(ldconfig -p | grep -F $$lib | awk 'NR==1 {print $$NF}'); \
		cp --parents $$path dist/libs/; \
	done

	# Copy remaining dependencies
	ldd minimal-ui | awk '/=>/ {print $$3}' \
	  | xargs -I{} cp -v --parents {} dist/libs/

	# Remove unwanted sound/video libraries
	find dist/libs -type f \( -name '*gst*' -o -name '*pulse*' -o -name '*asound*' \) -delete

	# Strip binary and libs
	strip -s dist/minimal-ui
	find dist/libs -type f -name "*.so*" -exec strip -s {} +

	# Patch interpreter
	patchelf --set-interpreter ./libs/ld-linux.so.2 dist/minimal-ui

	# GLib schemas
	cp /usr/share/glib-2.0/schemas/gschemas.compiled dist/share/glib-2.0/schemas/

	# Font config
	echo '<?xml version="1.0"?><fontconfig><dir>./fonts</dir></fontconfig>' \
	  > dist/etc/fonts/fonts.conf

	@echo "\n✅ Bundle complete. Size: $$(du -sh dist | cut -f1)"

installer: bundle
	mkdir -p installer
	tar cfJ installer/bundle.tar.xz -C dist .
	# Generate self-extracting installer script
	echo '#!/bin/sh' > installer/install.sh
	# Use escaped backticks and proper quoting to avoid unbalanced quotes
	echo "ARCHIVE=\`awk '/^__ARCHIVE__/ {print NR + 1; exit 0;}' \"\$$0\"\`" >> installer/install.sh
	echo "tail -n+\$$ARCHIVE \"\$$0\" | tar xJ -C ~/minimal-ui-app" >> installer/install.sh
	echo "echo \"Installed to ~/minimal-ui-app\"" >> installer/install.sh
	echo exit >> installer/install.sh
	echo __ARCHIVE__ >> installer/install.sh
	cat installer/bundle.tar.xz >> installer/install.sh
	chmod +x installer/install.sh
	@echo "📦 Installer created: installer/install.sh"
    @echo "   Size: $$(du -sh installer/install.sh | cut -f1)"
clean:
	rm -rf minimal-ui dist installer