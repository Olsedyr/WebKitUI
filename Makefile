all:
	gcc -m32 main.c -o minimal-ui \
	$(shell pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.0) \
	-I/usr/include/gtk-3.0 \
	-I/usr/include/webkitgtk-4.0 \
	-L/usr/lib/i386-linux-gnu