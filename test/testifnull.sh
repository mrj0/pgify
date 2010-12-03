#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT IFNULL(\`meta_value\`, FALSE) FROM wp_usermeta WHERE meta_key = 'wp_capabilities';
EOF

cat > "$expected" <<EOF
SELECT COALESCE  ("meta_value"::text , FALSE::text ) FROM wp_usermeta WHERE meta_key = E'wp_capabilities';
EOF

pgify
