CC := gcc
CFLAGS := -m32 -Os -pipe -s \
	 $(shell pkg-config --cflags gtk+-3.0 webkit2gtk-4.0) \
	 -Wl,-rpath='$$ORIGIN/libs' \
	 -DGDK_DISABLE_DEPRECATED
LDFLAGS := $(shell pkg-config --libs gtk+-3.0 webkit2gtk-4.0)

.PHONY: all clean bundle

all: minimal-ui

minimal-ui: main.c
	$(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)

REAL_XORG      := /usr/lib/xorg/Xorg
XORG_MODULES   := /usr/lib/xorg/modules
LD_SO          := /lib/i386-linux-gnu/ld-linux.so.2
FONT_PATH      := /usr/share/fonts/truetype/dejavu

bundle: all
	@echo "🧹 Cleaning dist/..."
	rm -rf dist
	mkdir -p dist/libs \
		 dist/xserver/modules/drivers \
		 dist/xserver/modules/input \
		 dist/xserver/modules/extensions \
		 dist/fonts \
		 dist/tmp

	@echo "📦 Copying core binary and loader..."
	cp -v minimal-ui dist/minimal-ui.bin
	cp -v $(LD_SO) dist/libs/

	@echo "📦 Copying dependencies..."
	ldd minimal-ui $(REAL_XORG) /usr/lib/xorg/modules/*.so \
	  | awk '/=>/ && $$3 ~ /^\// {print $$3}' \
	  | sort -u \
	  | xargs -r cp -v -t dist/libs

	@echo "📦 Copying Xorg..."
	if [ -f $(REAL_XORG) ]; then \
	  cp -v $(REAL_XORG) dist/xserver/ && \
	  chmod +x dist/xserver/Xorg; \
	else \
	  echo "❌ Xorg not found at $(REAL_XORG)"; \
	  exit 1; \
	fi

	@echo "📦 Input driver..."
	cp -v $(XORG_MODULES)/input/evdev_drv.so \
	   dist/xserver/modules/input/

	@echo "📦 Copying Xorg module dependencies..."
	cp -v /usr/lib/xorg/modules/libfb.so dist/xserver/modules/
	cp -v /usr/lib/xorg/modules/libshadow.so dist/xserver/modules/
	find $(XORG_MODULES) -name '*.so' -exec ldd {} \; \
	| awk '/=>/ && $$3 ~ /^\// {print $$3}' \
	| sort -u \
	| xargs -r cp -v -t dist/libs

	@echo "🔧 Patching Xorg binary..."
	patchelf \
	  --set-rpath '$ORIGIN/../libs' \
	  --set-interpreter '$ORIGIN/../libs/ld-linux.so.2' \
	  --force-rpath \
	  dist/xserver/Xorg

	@echo "🔧 Patching Xorg modules..."
	find dist/xserver/modules -name '*.so' -exec \
	  patchelf --set-rpath '$$ORIGIN/../../libs' {} \;

	@echo "📦 GLX extension..."
	cp -v $(XORG_MODULES)/extensions/libglx.so \
	   dist/xserver/modules/extensions/

	@echo "📦 Copying fonts..."
	cp -v $(FONT_PATH)/DejaVuSans.ttf      dist/fonts/
	cp -v $(FONT_PATH)/DejaVuSans-Bold.ttf dist/fonts/

	@echo "🛠 Creating xorg.conf..."
	echo 'Section "ServerFlags"'                          >  dist/xserver/xorg.conf
	echo '    Option "AutoAddDevices" "false"'            >> dist/xserver/xorg.conf
	echo '    Option "AutoEnableDevices" "false"'         >> dist/xserver/xorg.conf
	echo '    Option "Usevt" "false"'                     >> dist/xserver/xorg.conf
	echo '    Option "DontVTSwitch" "true"'               >> dist/xserver/xorg.conf
	echo '    Option "DontZoom" "true"'                   >> dist/xserver/xorg.conf
	echo 'EndSection'                                     >> dist/xserver/xorg.conf
	echo 'Section "Device"'                               >> dist/xserver/xorg.conf
	echo '    Identifier  "DummyCard"'                    >> dist/xserver/xorg.conf
	echo '    Driver      "dummy"'                        >> dist/xserver/xorg.conf
	echo '    VideoRam    32768'                          >> dist/xserver/xorg.conf
	echo 'EndSection'                                     >> dist/xserver/xorg.conf
	echo 'Section "Monitor"'                              >> dist/xserver/xorg.conf
	echo '    Identifier  "DummyMonitor"'                 >> dist/xserver/xorg.conf
	echo '    HorizSync   28.0-80.0'                      >> dist/xserver/xorg.conf
	echo '    VertRefresh 48.0-75.0'                      >> dist/xserver/xorg.conf
	echo '    Modeline "800x600" 38.25 800 832 912 1024 600 603 607 624' >> dist/xserver/xorg.conf
	echo 'EndSection'                                     >> dist/xserver/xorg.conf
	echo 'Section "Screen"'                               >> dist/xserver/xorg.conf
	echo '    Identifier  "DummyScreen"'                  >> dist/xserver/xorg.conf
	echo '    Device      "DummyCard"'                    >> dist/xserver/xorg.conf
	echo '    Monitor     "DummyMonitor"'                 >> dist/xserver/xorg.conf
	echo '    DefaultDepth 24'                            >> dist/xserver/xorg.conf
	echo '    SubSection "Display"'                       >> dist/xserver/xorg.conf
	echo '        Depth   24'                             >> dist/xserver/xorg.conf
	echo '        Modes   "800x600"'                      >> dist/xserver/xorg.conf
	echo '    EndSubSection'                              >> dist/xserver/xorg.conf
	echo 'EndSection'                                     >> dist/xserver/xorg.conf

	@echo "🔧 Patching Xorg binary..."
	patchelf \
	  --set-rpath '$$ORIGIN/../libs' \
	  --set-interpreter '$$ORIGIN/../libs/ld-linux.so.2' \
	  dist/xserver/Xorg

	@echo "🚀 Creating launcher script..."
	echo '#!/bin/sh'                                              >  dist/minimal-ui
	echo 'set -e'                                                 >> dist/minimal-ui
	echo 'SCRIPT_DIR="$$(cd "$$(dirname "$$0")" && pwd)"'         >> dist/minimal-ui
	echo 'XORG_BIN="$$SCRIPT_DIR/xserver/Xorg"'                   >> dist/minimal-ui
	echo 'XORG_MODULES_PATH="$$SCRIPT_DIR/xserver/modules"'       >> dist/minimal-ui
	echo 'export XDG_RUNTIME_DIR="$$SCRIPT_DIR/tmp"'              >> dist/minimal-ui
	echo 'export XAUTHORITY="$$SCRIPT_DIR/tmp/.Xauthority"'       >> dist/minimal-ui
	echo 'mkdir -p "$$SCRIPT_DIR/tmp"'                            >> dist/minimal-ui
	echo 'touch "$$XAUTHORITY"'                                   >> dist/minimal-ui
	echo 'chmod 600 "$$XAUTHORITY"'                               >> dist/minimal-ui
	echo 'if [ ! -f "$$XORG_BIN" ]; then'                         >> dist/minimal-ui
	echo '  echo "Xorg binary missing at: $$XORG_BIN" >&2'        >> dist/minimal-ui
	echo '  exit 1'                                               >> dist/minimal-ui
	echo 'fi'                                                     >> dist/minimal-ui
	echo '"$$XORG_BIN" :0 \'                                      >> dist/minimal-ui
	echo '  -config "$$SCRIPT_DIR/xserver/xorg.conf" \'           >> dist/minimal-ui
	echo '  -modulepath "$$XORG_MODULES_PATH" \'                  >> dist/minimal-ui
	echo '  -logfile "$$SCRIPT_DIR/tmp/xorg.log" \'               >> dist/minimal-ui
	echo '  -noreset -nolisten tcp 2> "$$SCRIPT_DIR/tmp/xorg.err" &' >> dist/minimal-ui
	echo 'X_PID=$$!'                                              >> dist/minimal-ui
	echo 'sleep 2'                                                >> dist/minimal-ui
	echo 'if ! kill -0 $$X_PID 2>/dev/null; then'                 >> dist/minimal-ui
	echo '  echo "Xorg failed to start:" >&2'                     >> dist/minimal-ui
	echo '  cat "$$SCRIPT_DIR/tmp/xorg.err" >&2'                  >> dist/minimal-ui
	echo '  exit 1'                                               >> dist/minimal-ui
	echo 'fi'                                                     >> dist/minimal-ui
	echo 'exec "$$SCRIPT_DIR/libs/ld-linux.so.2" --library-path "$$SCRIPT_DIR/libs" "$$SCRIPT_DIR/minimal-ui.bin"' >> dist/minimal-ui
	echo 'kill $$X_PID 2>/dev/null || true'                       >> dist/minimal-ui
	chmod +x dist/minimal-ui

clean:
	rm -f minimal-ui
	rm -rf dist
