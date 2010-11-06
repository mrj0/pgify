#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
DROP TABLE IF EXISTS \`serendipity_access\`;
EOF

cat > "$expected" <<EOF
DROP TABLE IF EXISTS serendipity_access;
EOF

pgify
