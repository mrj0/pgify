#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SHOW DATABASES;
EOF

cat > "$expected" <<EOF
select schema_name as database from information_schema.schemata order by 1 ;
EOF

pgify
