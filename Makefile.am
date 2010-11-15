BUILT_SOURCES = mysqlLexer.c mysqlParser.c 

bin_PROGRAMS=pgify
lib_LTLIBRARIES=libpgify.la
pgify_SOURCES=main.c

libpgify_la_SOURCES=pgify.c pgify.1 xmalloc.c system.h aclocal.m4 getopt.c getopt1.c getopt.h $(BUILT_SOURCES)

# these are installed
include_HEADERS=pgify.h mysqlLexer.h mysqlParser.h

mysqlParser.c: mysql.g
	@java -jar antlr-3.2.jar -make -Xmultithreaded -Xconversiontimeout 10000 mysql.g

# http://www.gnu.org/software/automake/manual/html_node/Libtool-Libraries.html#Libtool-Libraries

libpgify_la_LIBADD=$(glib_LIBS)
pgify_LDADD=libpgify.la

EXTRA_DIST=pgify.lsm.in pgify.spec.in pgify.texinfo autogen.sh \
	$(TESTS) test/testcommon.sh antlr-3.2.jar mysql.g

#  if you write a self-test script named `chk', uncomment the
#  following and add `chk' to the EXTRA_DIST list
TESTS=test/testSimple.sh \
	test/testbackquote.sh \
	test/testsimpledrop.sh \
	test/testschema.sh \
	test/testcomment.sh \
	test/testpassthroughtable.sh \
	test/testwpterms.sh \
	test/testcreatetablelike.sh \
	test/testcreatedatabase.sh \
	test/testuse.sh \
	test/testquote.sh \
	test/testlock.sh \
	test/testmultiplevalues.sh \
	test/testlock.sh \
	test/testcreatetablefulltextindex.sh \
	test/testonupdate.sh \
	test/testcreatetableindex.sh \
	test/teststupiddate.sh \
	test/testreserved.sh \
	test/testvariable.sh \
	test/testshowdatabases.sh

#  build and install the .info pages
info_TEXINFOS = pgify.texinfo
pgify_TEXINFOS = gpl.texinfo

#  install the man pages
man_MANS=pgify.1

test: check
