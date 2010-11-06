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
