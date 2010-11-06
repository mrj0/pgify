#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE test (like asdf);
EOF

cat > "$expected" <<EOF
CREATE TABLE test (like asdf);
EOF

pgify
