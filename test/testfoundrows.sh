#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select found_rows()
EOF

cat > "$expected" <<EOF
select 1 AS "found_rows()"
EOF

pgify
