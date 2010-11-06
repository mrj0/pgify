#ifndef _pgify_h
#define _pgify_h

#ifndef TRUE
#define TRUE    1
#endif

#ifndef FALSE
#define FALSE   0
#endif

extern int pgify_debug;
extern int pgify_schema;
extern int pgify_escape;

/* meant to be added to user1 to identify keyword tokens */
//#define PGKEYWORD 1

#endif
