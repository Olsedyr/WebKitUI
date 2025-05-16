#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <glib.h>

int main(int argc, char *argv[]) {
    // Force X11 backend and default display
    g_setenv("GDK_BACKEND", "x11", TRUE);
    g_setenv("DISPLAY", ":0", TRUE);  // Fallback to default display

    gtk_init(&argc, &argv);

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

    g_free(uri);
    g_free(path);
    return 0;
}