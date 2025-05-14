#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <unistd.h>
#include <limits.h>
#include <stdio.h>
#include <libgen.h> // Add this include

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_default_size(GTK_WINDOW(window), 800, 600);
    gtk_window_set_title(GTK_WINDOW(window), "Minimal WebKitGTK UI");

    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    WebKitWebView *web_view = WEBKIT_WEB_VIEW(webkit_web_view_new());
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(web_view));

    // Get executable path
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path)-1);
    if (len == -1) {
        fprintf(stderr, "Failed to get executable path.\n");
        return 1;
    }
    exe_path[len] = '\0';

    // Get directory of executable
    char *exe_dir = dirname(exe_path);

    // Build path to index.html relative to executable
    char index_path[PATH_MAX];
    snprintf(index_path, sizeof(index_path), "%s/../share/minimal-ui/index.html", exe_dir);

    // Build file:// URI
    char uri[PATH_MAX + 7]; // Extra space for "file://"
    snprintf(uri, sizeof(uri), "file://%s", index_path);

    webkit_web_view_load_uri(web_view, uri);

    gtk_widget_show_all(window);
    gtk_main();

    return 0;
}