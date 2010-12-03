#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT t.*, tt.* FROM wp_terms AS t INNER JOIN wp_term_taxonomy AS tt ON t.term_id = tt.term_id WHERE tt.taxonomy IN ('category')  ORDER BY t.name ASC
EOF

cat > "$expected" <<EOF
SELECT t.*, tt.* FROM wp_terms AS t INNER JOIN wp_term_taxonomy AS tt ON t.term_id = tt.term_id WHERE tt.taxonomy IN (E'category')  ORDER BY t.name ASC
EOF

pgify
