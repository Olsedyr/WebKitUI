minimal-ui: main.c
	gcc -o minimal-ui main.c `pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.0`
