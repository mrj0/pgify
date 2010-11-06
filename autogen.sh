#!/bin/sh

me=$0

err() {
    echo "$me: $1"
    exit 1
}

rm -f config.cache
rm -f config.log
rm -f configure
rm -f aclocal.m4

echo "execute: aclocal ..."
aclocal
if test "$?" != "0"; then
   err "aclocal failed. exit."
fi

echo "execute: autoheader ..."
autoheader --force
if test "$?" != "0"; then
   err "autoheader failed. exit."
fi

libtoolize --force --copy --automake
if test "$?" != "0"; then
   err "libtoolize failed. exit."
fi

automake --add-missing --copy --force-missing
if test "$?" != "0"; then
   err "automake failed. exit."
fi

autoconf --force
if test "$?" != "0"; then
   err "autoconf failed. exit."
fi


