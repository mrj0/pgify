#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
DROP database \`import\`;
EOF

cat > "$expected" <<EOF
DROP SCHEMA  "import";
EOF

pgify
