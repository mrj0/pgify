#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select concat_ws(',', \`asdf\`, 'w00t', somecolumn) from mysql.db;
EOF

cat > "$expected" <<EOF
select ARRAY_TO_STRING(ARRAY[  "asdf", E'w00t', somecolumn], E',') from mysql.db;
EOF

pgify
