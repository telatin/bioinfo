#include <stdio.h>
/* For "exit". */
#include <stdlib.h>
/* For "strerror". */
#include <string.h>
/* For "errno". */
#include <errno.h>
#include <zlib.h>

/* CHUNK is the size of the memory chunk used by the zlib routines. */

#define CHUNK 0x4000

/* The following macro calls a zlib routine and checks the return
   value. If the return value ("status") is not OK, it prints an error
   message and exits the program. Zlib's error statuses are all less
   than zero. */

#define CALL_ZLIB(x) {                                                  \
        int status;                                                     \
        status = x;                                                     \
        if (status < 0) {                                               \
            fprintf (stderr,                                            \
                     "%s:%d: %s returned a bad status of %d.\n",        \
                     __FILE__, __LINE__, #x, status);                   \
            exit (EXIT_FAILURE);                                        \
        }                                                               \
    }

/* if "test" is true, print an error message and halt execution. */

#define FAIL(test,message) {                             \
        if (test) {                                      \
            inflateEnd (& strm);                         \
            fprintf (stderr, "%s:%d: " message           \
                     " file '%s' failed: %s\n",          \
                     __FILE__, __LINE__, file_name,      \
                     strerror (errno));                  \
            exit (EXIT_FAILURE);                         \
        }                                                \
    }

/* These are parameters to inflateInit2. See
   http://zlib.net/manual.html for the exact meanings. */

#define windowBits 15
#define ENABLE_ZLIB_GZIP 32

int main ()
{
    const char * file_name = "test_4.fq.gz";
    FILE * file;
    z_stream strm = {0};
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];

    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.next_in = in;
    strm.avail_in = 0;
    CALL_ZLIB (inflateInit2 (& strm, windowBits | ENABLE_ZLIB_GZIP));

    /* Open the file. */

    file = fopen (file_name, "rb");
    FAIL (! file, "open");
    while (1) {
        int bytes_read;
    int zlib_status;

        bytes_read = fread (in, sizeof (char), sizeof (in), file);
        FAIL (ferror (file), "read");
        strm.avail_in = bytes_read;
    strm.next_in = in;
        do {
        unsigned have;
            strm.avail_out = CHUNK;
        strm.next_out = out;
        zlib_status = inflate (& strm, Z_NO_FLUSH);
        switch (zlib_status) {
        case Z_OK:
        case Z_STREAM_END:
        case Z_BUF_ERROR:
        break;

        default:
        inflateEnd (& strm);
        fprintf (stderr, "Gzip error %d in '%s'.\n",
             zlib_status, file_name);
        return -1;
        }
        have = CHUNK - strm.avail_out;
        fwrite (out, sizeof (unsigned char), have, stdout);
        }
        while (strm.avail_out == 0);
        if (feof (file)) {
            inflateEnd (& strm);
            break;
        }
    }
    FAIL (fclose (file), "close");
    return 0;
}
