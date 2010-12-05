#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
use test;
EOF

cat > "$expected" <<EOF
SET search_path TO test,public;
EOF

pgify
