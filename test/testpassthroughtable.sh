#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
create table test (one varchar(2));
drop table test;
EOF

cat > "$expected" <<EOF
create table test (one varchar(2));
drop table test;
EOF

pgify
