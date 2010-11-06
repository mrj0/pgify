#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT \`test\` from \`somedb\`.\`testtable\`;
EOF

cat > "$expected" <<EOF
SELECT "test" from "somedb"."testtable";
EOF

pgify
