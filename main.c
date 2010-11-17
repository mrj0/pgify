/* 
   pgify - A C library to transform MySQL SQL dialect to PostgreSQL.

   Copyright (C) 2010 Mike Johnson

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  
*/


#include <stdio.h>
#include <sys/types.h>
#include <glib.h>
#include <glib/gregex.h>

#include "system.h"
#include <antlr3.h>

#include "pgify.h"

#include <getopt.h>

#define EXIT_FAILURE 1

static void usage(int status);

/* The name the program was run with, stripped of any leading path. */
char *program_name;

/* getopt_long return codes */
enum {
    DUMMY_CODE=129
};

static struct option const long_options[] = {
    {"help", no_argument, 0, 'h'},
    {"version", no_argument, 0, 'V'},
    {"debug", no_argument, 0, 'd'},
    {"escape", no_argument, 0, 'e'},
    {NULL, 0, NULL, 0}
};

static int decode_switches(int, char **, int *options);

static pANTLR3_UINT8 fName = NULL;

static gchar* read_stdin(void);

int ANTLR3_CDECL main(int argc, char **argv) {
    program_name = argv[0];

    int pgoptions = 0;
    decode_switches(argc, argv, &pgoptions);

    pANTLR3_INPUT_STREAM input = antlr3AsciiFileStreamNew(fName);
    if(input == NULL) {
        gchar *sql = read_stdin();
        int len = 0;
        if(sql == NULL || (len = strlen(sql)) < 1)
            return EXIT_SUCCESS;

        input = antlr3NewAsciiStringCopyStream((pANTLR3_UINT8) sql, len, NULL);
    }

    gchar *pg = pgify_string(input, pgoptions);
    if(pg) {
        printf("%s", pg);
        g_free(pg);
    }

    input->close(input);
    input = NULL;
    exit(0);
}

/* Set all the option flags according to the switches specified.
   Return the index of the first non-option argument.  */

static int decode_switches(int argc, char **argv, int *pgoptions) {
    int c;

    int debug = FALSE;
    int escape = TRUE;

    while((c = getopt_long(
               argc,
               argv,
               "f:"             /* file */
               "h"              /* help */
               "d"              /* debug */
               "e"              /* escape */
               "V",             /* version */
               long_options,
               (int *) 0)) != EOF) {
        switch(c) {
        case 'V':
            printf("pgify %s\n", VERSION);
            exit(0);

        case 'h':
            usage(0);

        case 'f':
            fName = (pANTLR3_UINT8) optarg;
            break;

        case 'd':
            debug = TRUE;
            break;

        case 'e':
            escape = FALSE;
            break;

        default:
            usage(EXIT_FAILURE);
        }
    }

    if(debug)
        *pgoptions |= PGIFY_DEBUG;
    if(escape)
        *pgoptions |= PGIFY_ESCAPE;

    return 0;
}


static void usage(int status) {
    printf(_("%s - \
A C library to transform MySQL SQL dialect to PostgreSQL.\n"), program_name);
    printf(_("Usage: %s [OPTION]... [FILE]...\n"), program_name);
    printf(_("\
Options:\n\
  -f [file],                 use [file] for input instead of stdin\n\
  -h, --help                 display this help and exit\n\
  -V, --version              output version information and exit\n\
  -d, --debug                print debug statement structure to stderr\n\
  -e, --escape               convert backslash escapes to ANSI standards(default true)\n\
"));
    exit(status);
}

#define BUF_SIZE 2048

static gchar* read_stdin() {
    GString *buffer = g_string_new("");

    char cbuf[BUF_SIZE];

    while(fgets(cbuf, BUF_SIZE, stdin))
        g_string_append(buffer, cbuf);

    if(ferror(stdin)) {
        g_string_free(buffer, TRUE);
        perror("Error reading from stdin.");
        exit(EXIT_FAILURE);
    }

    return buffer->str;
}

