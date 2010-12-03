#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select (1 = 1) and 2 = 2 or 2 =2
EOF

cat > "$expected" <<EOF
select (1 = 1) and 2 = 2 or 2 =2
EOF

pgify
