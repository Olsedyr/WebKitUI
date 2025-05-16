CC = gcc
CFLAGS = -m32 -Os -pipe -s \
         $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0) \
         -Wl,-rpath='$$ORIGIN/libs'

LDFLAGS = $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)

.PHONY: all clean bundle

all: minimal-ui

minimal-ui: main.c
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)

bundle: all
	@mkdir -p dist/libs
	@echo "📦 Bundling dependencies..."
	@ldd minimal-ui | grep "=> /" | awk '{print $$3}' | xargs -I '{}' cp -v '{}' dist/libs
	@cp minimal-ui index.html dist/
	@echo "🔧 Fixing library paths..."
	@patchelf --set-rpath '$$ORIGIN/libs' dist/minimal-ui
	@echo "✅ Bundle created in dist/ with all dependencies!"

clean:
	rm -f minimal-ui
	rm -rf dist