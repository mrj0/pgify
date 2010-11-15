#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SHOW DATABASES;
EOF

cat > "$expected" <<EOF
SELECT nspname AS UserName FROM pg_namespace ORDER BY nspname;
EOF

pgify
