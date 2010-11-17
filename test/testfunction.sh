#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select database();
EOF

cat > "$expected" <<EOF
select database();
EOF

pgify
