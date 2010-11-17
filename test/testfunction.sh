#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select database();
EOF

cat > "$expected" <<EOF
select current_schema();
EOF

pgify
