#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
select @@\`version_comment\` ;
EOF

cat > "$expected" <<EOF
select  ( select character_value from information_schema.sql_implementation_info where implementation_info_name = 'DBMS VERSION')  ;
EOF

pgify
