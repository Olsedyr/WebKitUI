#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <glib.h>

#define FB_DISPLAY ":0"

static void start_xorg() {
    pid_t pid = fork();
    if (pid == 0) {
        // In child: launch our bundled Xorg
        execl("./xserver/Xorg", "Xorg", FB_DISPLAY,
              "-config", "./xserver/xorg.conf",
              "-nolisten", "tcp",
              NULL);
        // If exec fails:
        _exit(EXIT_FAILURE);
    } else if (pid > 0) {
        // In parent: wait a moment for X to spin up
        sleep(1);
    } else {
        perror("fork");
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char *argv[]) {
    // Ensure our libs are used
    setenv("LD_LIBRARY_PATH", "./libs", 1);
    // If DISPLAY not already set, start our Xorg
    if (!g_getenv("DISPLAY")) {
        start_xorg();
        setenv("DISPLAY", FB_DISPLAY, 1);
    }

    // Force GTK to use the X11 backend
    setenv("GDK_BACKEND", "x11", 1);

    gtk_init(&argc, &argv);

    // Build your GTK + WebKit window as before
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(window), "Minimal WebKit UI");
    gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);

    WebKitWebView *web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    gchar *path = g_get_current_dir();
    gchar *uri = g_strdup_printf("file://%s/index.html", path);
    webkit_web_view_load_uri(web_view, uri);

    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    gtk_widget_show_all(window);
    gtk_main();

    // Shut down Xorg when GTK quits
    system("pkill -P 1 Xorg");  // kills the child Xorg
    g_free(uri);
    g_free(path);
    return 0;
}
