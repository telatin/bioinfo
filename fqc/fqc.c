#include <stdio.h>
#include <string.h>
#include <fcntl.h>

#define BUFFER_SIZE (1024 * 16)
char BUFFER[BUFFER_SIZE];

int main(int argc, char** argv) {
    unsigned int lines = 0;
    unsigned int tot = 0;
    int fd, r;

    if (argc <= 1) {
        fd = fileno(stdin);

        while ((r = read(fd, BUFFER, BUFFER_SIZE)) > 0) {
            char* p = BUFFER;

            while ((p = memchr(p, '\n', (BUFFER + r) - p))) {
                ++p;
                ++lines;

            }
        }
        close(fd);

        if (r == -1) {
            fprintf(stderr, "Read error.\n");
            return 1;
        }
        printf("%d\n", lines / 4);

  
    } else {

        for (char **pargv = argv+1; *pargv != argv[argc]; pargv++) {
            if ((fd = open(*pargv, O_RDONLY)) == -1) {
                        fprintf(stderr, "Unable to open file \"%s\".\n", *pargv);
                        return 1;
            }
            lines = 0;

            while ((r = read(fd, BUFFER, BUFFER_SIZE)) > 0) {
                char* p = BUFFER;

                while ((p = memchr(p, '\n', (BUFFER + r) - p))) {
                    ++p;
                    ++lines;
                }
            }
            close(fd);
            tot += lines;
            if (r == -1) {
                fprintf(stderr, "Read error.\n");
                return 1;
            }
            printf("%s,%d\n", *pargv, lines / 4);
        }

        fprintf(stderr, "%d total reads.\n", tot/4);
    }

    

    
    return 0;

}

