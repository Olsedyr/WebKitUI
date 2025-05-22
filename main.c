#include <unistd.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
    char *argv_netsurf[] = {"./minimal-ui", "file:///index.html", NULL};
    execv("./minimal-ui", argv_netsurf);
    // If execv fails
    perror("execv");
    return 1;
}
