#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
LOCK TABLES \`maint\` WRITE;
EOF

cat > "$expected" <<EOF
   
EOF

pgify
