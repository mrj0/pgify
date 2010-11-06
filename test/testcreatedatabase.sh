#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE database xnorth default character set = utf8;
EOF

cat > "$expected" <<EOF
CREATE SCHEMA   xnorth                             ;
EOF

pgify
