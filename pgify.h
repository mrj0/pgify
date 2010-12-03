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

#ifndef _pgify_h
#define _pgify_h

#ifdef __cplusplus
extern "C" {
#endif

#include <glib.h>
#include <antlr3.h>
#include "mysqlLexer.h"
#include "mysqlParser.h"

#ifndef TRUE
#define TRUE    1
#endif

#ifndef FALSE
#define FALSE   0
#endif

struct walker_state_struct {
    pmysqlParser psr;
    gchar *schemaName;
    GString *postbuf;
    int *options;
};
typedef struct walker_state_struct *WalkerState;

struct _pgify_tree_struct {
    pANTLR3_COMMON_TOKEN_STREAM     tstream;
    pmysqlLexer                     lxr;
    pmysqlParser                    psr;
    mysqlParser_start_rule_return   langAST;
    pANTLR3_VECTOR                  tokens;
    WalkerState                     ws;
    int                             error_count;
};
typedef struct _pgify_tree_struct PgifyTree, *pPgifyTree;

void pgifytree_free(pPgifyTree);

pPgifyTree pgify(pANTLR3_INPUT_STREAM, int options);
gchar* pgify_string(pANTLR3_INPUT_STREAM, int options);
gchar* pgify_string_s(const char *, int options);
gchar* pgify_string_tree(pPgifyTree);


/**
 * Enable debug tree print to stderr
 *
 */
#define PGIFY_DEBUG 1
/**
 * Prefix all quoted strings with E, postgres' way of handling mysql string escapes.
 *
 */
#define PGIFY_ESCAPE 2

#define PGIFY_IS_DEBUG(options)  (*(int *) options) & PGIFY_DEBUG
#define PGIFY_IS_ESCAPE(options) (*(int *) options) & PGIFY_ESCAPE

#ifdef __cplusplus
}
#endif
#endif  /* sentinel */
