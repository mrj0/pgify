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
#include "mysqlLexer.h"
#include "mysqlParser.h"


static void TreeWalkWorker(WalkerState, pANTLR3_BASE_TREE, int);
static void TreeWalkPrinter(GString *, pANTLR3_BASE_TREE, pANTLR3_VECTOR, int *);
static void advance_all(GString *, pANTLR3_VECTOR, int *);


static void print_postbuf(GString *output, WalkerState ws) {
    if(ws->postbuf->len > 0) {
        g_string_append_printf(output, "\n%s", ws->postbuf->str);
        g_string_erase(ws->postbuf, 0, -1); /* empty */
    }
}


pPgifyTree pgify(pANTLR3_INPUT_STREAM input, int pgoptions) {
    pANTLR3_VECTOR                  tokens;
    pANTLR3_COMMON_TOKEN_STREAM     tstream;
    pmysqlLexer                     lxr;
    pmysqlParser                    psr;
    mysqlParser_start_rule_return   langAST;
    GString                        *postbuf;
    int i;

    tokens = NULL;

    lxr = mysqlLexerNew(input);      // generated by ANTLR
    if(lxr == NULL) {
        ANTLR3_FPRINTF(stderr, "Unable to create the lexer due to malloc() failure\n");
        goto cleanup;
    }
    lxr->pLexer->rec->state->userp = &pgoptions;
 
    tstream = antlr3CommonTokenStreamSourceNew(ANTLR3_SIZE_HINT, TOKENSOURCE(lxr));
    if (tstream == NULL) {
        ANTLR3_FPRINTF(stderr, "Out of memory trying to allocate token stream\n");
        goto cleanup;
    }
    tstream->discardOffChannel = ANTLR3_FALSE;

    /* printf("---------------------------------------- tokens:\n"); */
    tokens = tstream->getTokens(tstream);

    psr = mysqlParserNew(tstream);  // generated by ANTLR3
    if (psr == NULL) {
        ANTLR3_FPRINTF(stderr, "Out of memory trying to allocate parser\n");
        goto cleanup;
    }
    psr->pParser->rec->state->userp = &pgoptions;
 
    langAST = psr->start_rule(psr);

    // If the parser ran correctly, we will have a tree to parse. In general I recommend
    // keeping your own flags as part of the error trapping, but here is how you can
    // work out if there were errors if you are using the generic error messages
    //
    /* if (psr->pParser->rec->state->errorCount > 0) { */
    /*     ANTLR3_FPRINTF(stderr, "The parser returned %d errors, tree walking aborted.\n", psr->pParser->rec->errorCount); */
    /*     exit(EXIT_FAILURE); */
    /* } */

    postbuf = g_string_new(""); /* new generated statements to add to the end of the output */

    WalkerState state = (WalkerState) malloc(sizeof(struct walker_state_struct));
    if(state == NULL) {
        ANTLR3_FPRINTF(stderr, "Unable to create WalkerState due to malloc() failure\n");
        goto cleanup;
    }

    state->psr = psr;
    state->schemaName = g_strdup("");
    state->postbuf = postbuf;
    state->options = &pgoptions;

    if(langAST.tree != NULL)
        TreeWalkWorker(state, langAST.tree, 0);

    // We did not return anything from this parser rule, so we can finish. It only remains
    // to close down our open objects, in the reverse order we created them
    //

    if(state->schemaName)
        g_free(state->schemaName);

    pPgifyTree pt = (pPgifyTree) malloc(sizeof(PgifyTree));
    if(pt == NULL) {
        ANTLR3_FPRINTF(stderr, "Unable to create pPgifyTree due to malloc() failure\n");
        goto cleanup;
    }

    pt->psr     = psr;
    pt->tstream = tstream;
    pt->lxr     = lxr;
    pt->langAST = langAST;
    pt->tokens  = tokens;
    pt->ws      = state;

    return pt;

cleanup:                        /* error */
    if(psr)
        psr->free(psr);
    if(tstream)
        tstream->free(tstream);
    if(lxr)
        lxr->free(lxr);

    if(state)
        free(state);
    if(pt)
        free(pt);
    if(postbuf)
        g_string_free(postbuf, TRUE);

    return NULL;
}


gchar* pgify_string(pANTLR3_INPUT_STREAM input, int pgoptions) {
    int tokenIndex = 0;
    GString *output = g_string_new("");
    input->setUcaseLA(input, ANTLR3_TRUE);
    pPgifyTree pt = pgify(input, pgoptions);
    if(!pt)
        return NULL;

    TreeWalkPrinter(output, pt->langAST.tree, pt->tokens, &tokenIndex);
    advance_all(output, pt->tokens, &tokenIndex);

    print_postbuf(output, pt->ws);

    pgifytree_free(pt);
    return g_string_free(output, FALSE);
}


gchar* pgify_string_s(const char *sql, int pgoptions) {
    pANTLR3_INPUT_STREAM input = antlr3NewAsciiStringCopyStream((pANTLR3_UINT8) sql, strlen(sql), NULL);

    gchar *ret = pgify_string(input, pgoptions);

    input->close(input);
    input = NULL;
    return ret;
}


void pgifytree_free(pPgifyTree pt) {
    if(!pt)
        return;

    pt->psr     ->free  (pt->psr);      pt->psr     = NULL;
    pt->tstream ->free  (pt->tstream);  pt->tstream = NULL;
    pt->lxr     ->free  (pt->lxr);      pt->lxr     = NULL;

    if(pt->ws->postbuf)
        g_string_free(pt->ws->postbuf, TRUE);

    free(pt->ws);
    pt->ws = NULL;

    free(pt);
}


extern pANTLR3_UINT8  mysqlParserTokenNames[];

/**
 * search the tree for the specified token and return the position.
 *
 * does not descend
 *
 */
static int look_ahead_index(pANTLR3_BASE_TREE tree, ANTLR3_UINT32 from, ANTLR3_UINT32 lookfor) {
    ANTLR3_UINT32 n, c;
    n = tree->getChildCount(tree);
    for(c = from; c < n ; c++) {
        pANTLR3_BASE_TREE child;
        ANTLR3_UINT32 childType;
        
        child = tree->getChild(tree, c);
        childType = child->getType(child);
        if(childType == lookfor)
            return c;
    }

    return -1;
}


/**
 * search the tree for the specified token and return the index.
 *
 */
static int look_ahead_down(pANTLR3_BASE_TREE tree, ANTLR3_UINT32 from, ANTLR3_UINT32 lookfor) {
    ANTLR3_UINT32 n, c;
    n = tree->getChildCount(tree);
    for(c = from; c < n ; c++) {
        pANTLR3_BASE_TREE child;
        ANTLR3_UINT32 childType;
        
        child = tree->getChild(tree, c);
        childType = child->getType(child);
        if(childType == lookfor)
            return c;
        else if(child->getChildCount(child) > 0) {
            int down = look_ahead_down(child, 0, lookfor);
            if(down > -1)
                return down;
        }
    }

    return -1;
}


/**
 * Remove quotes from a string. Returned string must be released with g_free().
 *
 */
static gchar* unquote(const gchar *string) {
    static GRegex *pattern = NULL;
    static gsize initialized = 0;

    if(g_once_init_enter (&initialized)) {
        pattern = g_regex_new("[\"']", (GRegexCompileFlags) 0, (GRegexMatchFlags) 0, NULL);
        g_once_init_leave (&initialized, 1);
    }

    return g_regex_replace_literal(pattern, string, strlen(string), 0, "", (GRegexMatchFlags) 0, NULL);
}


static void create_table_remove_table_options(pANTLR3_BASE_TREE base) {
    int pos = 0;

    while((pos = look_ahead_index(base, pos, T_CREATE_TABLE_OPTIONS)) > -1)
        base->deleteChild(base, pos);
}


static gchar* create_table_tablename(pANTLR3_BASE_TREE base) {
    ANTLR3_UINT32 n, c;
    n = base->getChildCount(base);

    for(c = 0; c < n ; c++) {
        pANTLR3_BASE_TREE child;
        ANTLR3_UINT32 childType;
        
        child = base->getChild(base, c);
        childType = child->getType(child);
        if(childType == ID)
            return child->toString(child)->chars;
    }

    return 0;
}


static create_table_fulltext_index(WalkerState ws, pANTLR3_BASE_TREE base) {
    int pos = 0;
    while((pos = look_ahead_index(base, pos, T_CREATE_TABLE_FULLTEXT_INDEX)) > -1) {
        base->deleteChild(base, pos);

        // remove previous comma, if present
        if(pos - 1 > 0) {
            pANTLR3_BASE_TREE comma = base->getChild(base, pos - 1);
            if(comma->getType(comma) == COMMA)
                base->deleteChild(base, pos - 1);
        }
    }
}


static void create_table_index(WalkerState ws, pANTLR3_BASE_TREE base) {
    int pos = 0;

    gchar *tablename = create_table_tablename(base);
    gchar *utablename = unquote(tablename);

    while((pos = look_ahead_index(base, 0, T_CREATE_TABLE_INDEX)) > -1) {
        int p;
        pANTLR3_BASE_TREE child;
        ANTLR3_UINT32 childType;
        gchar *name = 0, *indexType = 0;

        child = base->getChild(base, pos);

        p = look_ahead_index(child, 0, K_USING);
        if(p > -1) {
            pANTLR3_BASE_TREE indexChild = child->getChild(child, p + 1);
            indexType = indexChild->toString(indexChild)->chars;
        }

        //   T_CREATE_TABLE_INDEX (5, T_CREATE_TABLE_INDEX) [9,6] (4)
        //      "name" (39, ID) [9,6] (0)
        //      ( (17, LPAREN) [9,13] (0)
        //      "name" (39, ID) [9,14] (0)
        //      ) (18, RPAREN) [9,20] (0)

        GString *columns = g_string_new("");
        gchar *firstcolumn = 0;
        ANTLR3_UINT32 n, c;
        n = child->getChildCount(child);
        for(c = 0; c < n ; c++) {
            pANTLR3_BASE_TREE index;
            ANTLR3_UINT32 t;
        
            index = child->getChild(child, c);
            t = index->getType(index);
            if(t == ID) {
                /* found an ID. If we haven't already started building
                 * columns, then this must be the index name */
                if(!name && columns->len < 1)
                    name = index->toString(index)->chars;
                else {
                    if(columns->len > 0)
                        g_string_append(columns, ", ");
                    g_string_append(columns, index->toString(index)->chars);
                    if(firstcolumn == 0)
                        firstcolumn = index->toString(index)->chars;
                }
            }
            else if(t == K_ASC || t == K_DESC) {
                g_string_append_printf(columns, " %s", index->getText(index)->chars);
            }
        }

        g_string_append(ws->postbuf, "CREATE INDEX ");

        if(name == 0)
            name = firstcolumn;
        name = unquote(name);
        g_string_append_printf(ws->postbuf,
                               "%s_%s_index ON %s%s ",
                               utablename,
                               name,
                               ws->schemaName,
                               tablename);
        g_free(name);

        if(indexType != 0)
            g_string_append_printf(ws->postbuf, " USING %s ", indexType);

        g_string_append_printf(ws->postbuf, " ( %s ) ;\n", columns->str);

        g_string_free(columns, TRUE);
        base->deleteChild(base, pos);

        child = base->getChild(base, pos - 1);
        if(child->getType(child) == COMMA)
            base->deleteChild(base, pos - 1);
    }

    g_free(utablename);
}


static void create_table_rewrite_auto_inc(WalkerState ws, pANTLR3_BASE_TREE basetree, pANTLR3_BASE_TREE tree) {
    // rewrite AUTO_INCREMENT
    ANTLR3_UINT32 n, c;
    pANTLR3_BASE_TREE id;
    id = NULL;

    gchar *tablename = create_table_tablename(tree);
    gchar *utablename = unquote(tablename);

    n = tree->getChildCount(tree);

    int pos = 0;
    for(; (pos = look_ahead_index(tree, pos, T_CREATE_TABLE_COLUMN_DEF)) > -1; pos++) {
        pANTLR3_BASE_TREE child = tree->getChild(tree, pos);
        int incpos = look_ahead_index(child, 0, K_AUTO_INCREMENT);
        if(incpos < 0)
            continue;

        id = child->getChild(child, 0);

        int lastpos = 0;
        int optpos = 0;
        char *autoincstart = "1";
        for( ; (optpos = look_ahead_index(tree, lastpos, T_CREATE_TABLE_OPTIONS)) > 0; lastpos = ++optpos) {
            pANTLR3_BASE_TREE options;
            int children;

            options = tree->getChild(tree, optpos);
            children = options->getChildCount(options);

            if(children >= 2) {
                pANTLR3_BASE_TREE autoinc, eq, number;
            
                autoinc = options->getChild(options, 0);
                eq = options->getChild(options, 1);
                number = options->getChild(options, 2);

                if(autoinc->getType(autoinc) == K_AUTO_INCREMENT &&
                   eq->getType(eq) == EQ &&
                   number->getType(number) == NUMBER) {
                    autoincstart = number->getText(number)->chars;
                    break;
                }
            }
        }

        // next, need to append two statements like:
        //   create sequence wp_terms_term_id_seq;
        //   alter table "wp_terms" alter column "term_id" set default nextval('wp_terms_term_id_seq');

        gchar *uid = unquote(id->toString(id)->chars);
        gchar *sequence = g_strdup_printf(
            "%s_%s_seq",
            utablename,
            uid);
        g_free(uid);

        g_string_append_printf(ws->postbuf, "CREATE SEQUENCE %s%s START %s ;\n", ws->schemaName, sequence, autoincstart);

        g_string_append_printf(ws->postbuf,
                               "ALTER TABLE %s%s ALTER COLUMN %s SET DEFAULT NEXTVAL ( '%s%s' ) ;\n",
                               ws->schemaName,
                               tablename,
                               id->toString(id)->chars,
                               ws->schemaName,
                               sequence);

        g_free(sequence);

        child->deleteChild(child, incpos);
    }

    g_free(utablename);
}


static void create_table_rewrite_fkey(WalkerState ws, pANTLR3_BASE_TREE tree) {
    int pos;
    gchar *tablename = create_table_tablename(tree);

    while((pos = look_ahead_index(tree, 0, T_CREATE_TABLE_FKEY)) > -1) {
        pANTLR3_BASE_TREE fkey;

        fkey = tree->getChild(tree, pos);

        g_string_append_printf(ws->postbuf, "ALTER TABLE %s ADD", tablename);

        ANTLR3_UINT32 n, c;
        n = fkey->getChildCount(fkey);
        for(c = 0; c < n ; c++) {
            pANTLR3_BASE_TREE tokenTree = fkey->getChild(fkey, c);
            pANTLR3_COMMON_TOKEN token = tokenTree->getToken(tokenTree);
            ANTLR3_UINT32 childType = token->getType(token);

            g_string_append_printf(ws->postbuf, " %s", token->getText(token)->chars);


            /* if(childType == K_CONSTRAINT && c + 1 < n) { */
            /*     pANTLR3_BASE_TREE nameTree = fkey->getChild(fkey, ++c); */
            /*     pANTLR3_COMMON_TOKEN name = nameTree->getToken(nameTree); */
            /*     ANTLR3_UINT32 nameType = name->getType(name); */
            /*     if(nameType != ID) */
            /*         continue; */

            /*     g_string_append_printf(ws->postbuf, " CONSTRAINT %s", name->getText(name)->chars); */
            /* } */
            /* else if(childType == K_FOREIGN) */
            /*     g_string_append_printf(postbuf, " FOREIGN"); */
            /* else if(childType == K_KEY) */
            /*     g_string_append_printf(postbuf, " KEY"); */
        }

        g_string_append(ws->postbuf, ";\n");
        tree->deleteChild(tree, pos);

        pANTLR3_BASE_TREE child = tree->getChild(tree, pos - 1);
        if(child->getType(child) == COMMA)
            tree->deleteChild(tree, pos - 1);
    }
}


static void create_rewrite_datatypes(WalkerState ws, pANTLR3_BASE_TREE tree) {
    ANTLR3_UINT32 n, c;
    n = tree->getChildCount(tree);

    for(c = 0; c < n ; c++) {
        pANTLR3_BASE_TREE child;
        ANTLR3_UINT32 childType;
        
        child = tree->getChild(tree, c);
        childType = child->getType(child);

        if(childType == K_DOUBLE && c + 1 < n) {
            pANTLR3_BASE_TREE next = tree->getChild(tree, c + 1);
            if(next->getType(next) != K_PRECISION) {
                pANTLR3_COMMON_TOKEN token = child->getToken(child);
                pANTLR3_STRING str = token->getText(token);
                str->append(str, " PRECISION ");
                token->setText(token, str);
            }
        }
    }
}


static void create_rewrite_stupid_date(WalkerState ws, pANTLR3_BASE_TREE base) {
    int defpos = 0;
    for(; (defpos = look_ahead_index(base, defpos, T_CREATE_TABLE_COLUMN_DEF)) > -1; defpos++) {
        pANTLR3_BASE_TREE def = base->getChild(base, defpos);

        int pos1 = look_ahead_down(def, 0, STUPID_MYSQL_DATE);
        int pos2 = look_ahead_down(def, 0, STUPID_MYSQL_TIMESTAMP);

        if(pos1 < 0 && pos2 < 0)
            continue;

        ANTLR3_UINT32 n, c;
        n = def->getChildCount(def);
        for(c = 0; c < n ; c++) {
            pANTLR3_BASE_TREE child = def->getChild(def, c);
            if(child->getType(child) == K_NOT && c + 1 < n) {
                pANTLR3_BASE_TREE nextt = def->getChild(def, c + 1);
                if(nextt->getType(nextt) == K_NULL) {
                    def->deleteChild(def, c + 1);
                    def->deleteChild(def, c);
                    break;
                }
            }
        }
    }
}


static void create_rewrite_enum(WalkerState ws, pANTLR3_BASE_TREE base) {
    int defpos = 0;
    for(; (defpos = look_ahead_index(base, defpos, T_CREATE_TABLE_COLUMN_DEF)) > -1; defpos++) {
        pANTLR3_BASE_TREE def = base->getChild(base, defpos);
        int pos = 0;
        for(; (pos = look_ahead_index(def, pos, T_CREATE_TABLE_ENUM)) > -1; pos++) {
            pANTLR3_STRING name = 0;
            pANTLR3_BASE_TREE ntree = def->getChild(def, 0);
            name = ntree->getText(ntree);

            pANTLR3_BASE_TREE tree = def->getChild(def, pos);

            int enumpos = look_ahead_index(tree, 0, K_ENUM);
            if(enumpos < 0)
                enumpos = look_ahead_index(tree, 0, K_SET);

            pANTLR3_BASE_TREE enumtree = tree->getChild(tree, enumpos);
            pANTLR3_COMMON_TOKEN token = enumtree->getToken(enumtree);
            gchar *enumtext = g_strdup_printf("text CHECK ( %s IN ", name->chars);
            pANTLR3_STRING str = enumtree->strFactory->newRaw(enumtree->strFactory);
            str->set(str, enumtext);
            token->setText(token, str);
            g_free(enumtext);

            int rparen = look_ahead_index(tree, 0, RPAREN);
            pANTLR3_BASE_TREE rtree = tree->getChild(tree, rparen);
            pANTLR3_BASE_TREE rr = rtree->dupTree(rtree);
            tree->addChild(tree, rr);
        }
    }
}


static void create_table_rewrite_onupdate(WalkerState ws, pANTLR3_BASE_TREE base) {
    gchar *tablename = create_table_tablename(base);
    gchar *utablename = unquote(tablename);

    static const char *tfunction = 
        "CREATE OR REPLACE FUNCTION %s%s_update_%s()\n"
        "RETURNS TRIGGER AS $$\n"
        "BEGIN\n"
        "   NEW.%s = %s; \n"
        "   RETURN NEW;\n"
        "END;\n"
        "$$ language 'plpgsql';\n";

    static const char *ttrigger =
        "CREATE TRIGGER %s_update_%s_trigger BEFORE UPDATE\n"
        "   ON %s%s FOR EACH ROW EXECUTE PROCEDURE %s%s_update_%s();\n";

    int defpos = 0;
    for(; (defpos = look_ahead_index(base, defpos, T_CREATE_TABLE_COLUMN_DEF)) > -1; defpos++) {
        pANTLR3_BASE_TREE def = base->getChild(base, defpos);

        int pos = 0;
        for(; (pos = look_ahead_index(def, pos, T_CREATE_TABLE_ONUPDATE)) > -1; pos++) {
            ANTLR3_UINT32 n, c;
            pANTLR3_BASE_TREE ntree = def->getChild(def, 0);
            pANTLR3_STRING name = ntree->getText(ntree);

            pANTLR3_BASE_TREE tree = def->getChild(def, pos);

            n = tree->getChildCount(tree);
            GString *expr = g_string_new("");
            for(c = 0; c < n; c++) {
                pANTLR3_BASE_TREE child = tree->getChild(tree, c);
                ANTLR3_UINT32 childType = child->getType(child);

                if(childType != K_ON && childType != K_UPDATE)
                    g_string_append_printf(expr, " %s ", child->getText(child)->chars);
            }

            gchar *uname = unquote(name->chars);

            g_string_append_printf(ws->postbuf, tfunction, ws->schemaName, utablename, uname, name->chars, expr->str);
            g_string_append_printf(ws->postbuf, ttrigger, utablename, uname, ws->schemaName, tablename, ws->schemaName, utablename, uname);
            g_string_free(expr, TRUE);

            g_free(uname);
            def->deleteChild(def, pos);
        }
    }

    g_free(utablename);
}


static void create_table_worker(WalkerState ws, pANTLR3_BASE_TREE basetree, pANTLR3_BASE_TREE tree) {
    create_rewrite_enum(ws, tree);
    create_rewrite_datatypes(ws, tree);
    create_table_rewrite_onupdate(ws, tree);
    create_rewrite_stupid_date(ws, tree);
    create_table_index(ws, tree);
    create_table_rewrite_auto_inc(ws, basetree, tree);
    create_table_fulltext_index(ws, tree);
    create_table_rewrite_fkey(ws, tree);
    create_table_remove_table_options(tree);
}


static void use_database_worker(WalkerState ws, pANTLR3_BASE_TREE basetree, pANTLR3_BASE_TREE tree) {
    int pos = look_ahead_index(tree, 0, K_USE);
    if(pos < 0)
        return;

    pANTLR3_BASE_TREE kuse = tree->getChild(tree, pos);
    pANTLR3_COMMON_TOKEN token = kuse->getToken(kuse);
    pANTLR3_STRING str = kuse->getText(kuse);
    str->set(str, "SET search_path TO");
    token->setText(token, str);

    pos = look_ahead_index(tree, 0, ID);
    if(pos > -1) {
        pANTLR3_BASE_TREE schema = tree->getChild(tree, pos);
        if(ws->schemaName)
            g_free(ws->schemaName);
        ws->schemaName = g_strdup_printf("%s.", schema->getText(schema)->chars);
    }
}


static void delete_tree_children(pANTLR3_BASE_TREE tree) {
    ANTLR3_UINT32 n, c;
    n = tree->getChildCount(tree);

    for(c = 0; c < n ; c++)
        tree->deleteChild(tree, 0);
}


static void lock_tables_worker(WalkerState ws, pANTLR3_BASE_TREE basetree, pANTLR3_BASE_TREE tree) {
    pANTLR3_STRING str = tree->getText(tree);
    str->set(str, "");
    pANTLR3_COMMON_TOKEN token = tree->getToken(tree);
    token->setText(token, str);
    delete_tree_children(tree);
}


static void rewrite_server_variables(WalkerState ws, pANTLR3_BASE_TREE basetree, pANTLR3_BASE_TREE tree) {
    static const char *VERSION_SQL =
        " ( select character_value from information_schema.sql_implementation_info where implementation_info_name = 'DBMS VERSION') ";

    int pos = look_ahead_down(tree, pos, ID);
    if(pos < 0)
        return;

    pANTLR3_BASE_TREE child = tree->getChild(tree, pos);
    pANTLR3_STRING str = child->getText(child);
    gchar *ustr = unquote(str->chars);

    gint cmp = g_ascii_strcasecmp("version", ustr);
    gint cmp2 = g_ascii_strcasecmp("version_comment", ustr);

    if(cmp == 0 || cmp2 == 0) {
        str->set(str, VERSION_SQL);
        pANTLR3_COMMON_TOKEN token = child->getToken(child);
        token->setText(token, str);
    }

    g_free(ustr);
}


static void indent(int level) {
    int i;
    level += 2;
    for(i = 0; i < level; i++)
        fprintf(stderr, "   ");
};


static void TreeWalkWorker(WalkerState ws, pANTLR3_BASE_TREE p, int level) {
    ANTLR3_UINT32 n = 0, c = 0;
    
    if(PGIFY_IS_DEBUG(ws->options) && p->isNilNode(p) == ANTLR3_TRUE)
        fprintf(stderr, "nil-node\n");

    for(c = 0; c < p->getChildCount(p); c++) {
        pANTLR3_COMMON_TOKEN token;
        pANTLR3_BASE_TREE child;

        child = p->getChild(p, c);
        if(child->getToken == NULL) {
            fprintf(stderr, "   getToken null\n");
            token = 0;
        }
        else
            token = child->getToken(child);

        ANTLR3_UINT32 tokenType = child->getType(child);

        /* if(postbuf->len > 0 && tokenType == T_TRANSFORM) { */
        /*     // take this as a hint to flush the postbuf */
        /*     // we have to add it to the tree, though... */

        /*     g_string_insert(postbuf, 0, "\n"); */

        /*     pANTLR3_COMMON_TOKEN newtoken = psr->adaptor->createToken(psr->adaptor, T_TRANSFORM, postbuf->str); */
        /*     pANTLR3_STRING str = child->strFactory->newStr(child->strFactory, postbuf->str); */
        /*     newtoken->setText(newtoken, str); */
        /*     g_string_erase(postbuf, 0, -1); /\* empty *\/ */
        /*     pANTLR3_BASE_TREE newtree = psr->adaptor->create(psr->adaptor, newtoken); */

        /*     child->addChild(child, newtree); */
        /* } */

        if(PGIFY_IS_DEBUG(ws->options)) {
            if(tokenType != ANTLR3_TOKEN_EOF) {
                fprintf(stderr, "  ");
                indent(level);

                fprintf(stderr, "%s (%d, %s) [%d,%d] (%d)\n",
                        child->toString(child)->chars,
                        tokenType,
                        mysqlParserTokenNames[tokenType],
                        child->getLine(child),
                        child->getCharPositionInLine(child),
                        child->getChildCount(child));
            }
        }

        if(child->getChildCount(child) > 0)
            TreeWalkWorker(ws, child, level + 1);

        if(tokenType == T_CREATE_TABLE)
            create_table_worker(ws, p, child);
        else if(tokenType == T_USE_DATABASE)
            use_database_worker(ws, p, child);
        else if(tokenType == T_LOCK_TABLE)
            lock_tables_worker(ws, p, child);
        else if(tokenType == T_SERVER_VARIABLE)
            rewrite_server_variables(ws, p, child);
    }
}


static void advance(GString *output, pANTLR3_BASE_TREE child, pANTLR3_VECTOR tokens, int *tokenIndex) {
    int line = child->getLine(child);
    int position = child->getCharPositionInLine(child);

    for(; *tokenIndex < tokens->count; (*tokenIndex)++) {
        pANTLR3_COMMON_TOKEN token = tokens->get(tokens, *tokenIndex);

        if(token->channel != HIDDEN)
            continue;

        if(token->getLine(token) < line ||
           token->getCharPositionInLine(token) <= position) {
            g_string_append_printf(output, "%s", token->getText(token)->chars);
        }
        else
            break;
    }

    g_string_append_printf(output, "%s", child->getText(child)->chars);
}


static void advance_all(GString *output, pANTLR3_VECTOR tokens, int *tokenIndex) {
    for(; *tokenIndex < tokens->count; (*tokenIndex)++) {
        pANTLR3_COMMON_TOKEN token = tokens->get(tokens, *tokenIndex);

        if(token->channel != HIDDEN)
            continue;

        g_string_append_printf(output, "%s", token->getText(token)->chars);
    }
}


static void TreeWalkPrinter(GString *output, pANTLR3_BASE_TREE p, pANTLR3_VECTOR tokens, int *tokenIndex) {
    ANTLR3_UINT32 n, c, max = 0;

    if(!p)
        return;

    n = p->getChildCount(p);

    // first, walk tree at the current level and get the max first token size
    for(c = 0; c < n; c++) {
        pANTLR3_BASE_TREE child = p->getChild(p, c);
        int size = child->getText(child)->len;
        if(size > max)
            max = size;
    }

    for(c = 0; c < n; c++) {
        pANTLR3_BASE_TREE child;
        child = p->getChild(p, c);
        int ChildCount = child->getChildCount(child);

        ANTLR3_UINT32 TokenType = child->getType(child);
        if(ChildCount > 0) {
            TreeWalkPrinter(output, child, tokens, tokenIndex);
        }
        else {
            if(TokenType != ANTLR3_TOKEN_EOF)
                advance(output, child, tokens, tokenIndex);
        }
    }
}

gchar* pgify_string_tree(pPgifyTree pt) {
    int tokenIndex = 0;
    GString *output = g_string_new("");

    TreeWalkPrinter(output, pt->langAST.tree, pt->tokens, &tokenIndex);
    advance_all(output, pt->tokens, &tokenIndex);
    print_postbuf(output, pt->ws);

    return g_string_free(output, FALSE);
}
