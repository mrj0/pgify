#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
show tables;
EOF

cat > "$expected" <<EOF
SELECT sub.tables
  FROM ( SELECT table_name AS tables,
                'BASE TABLE' AS table_type
           FROM information_schema.tables
          WHERE table_schema = current_schema()
          UNION SELECT table_name,
                'VIEW'
           FROM information_schema.views
          WHERE table_schema = current_schema()
          ORDER BY 1 ) sub

 ;
EOF

pgify
