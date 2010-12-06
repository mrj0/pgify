#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT DISTINCT YEAR(post_date) AS yyear, MONTH(post_date) AS mmonth FROM wp_posts WHERE post_type = 'post' ORDER BY post_date DESC
EOF

cat > "$expected" <<EOF
SELECT DISTINCT EXTRACT  (YEAR FROM post_date) AS yyear, EXTRACT  (MONTH FROM post_date) AS mmonth FROM wp_posts WHERE post_type = E'post' ORDER BY post_date DESC
EOF

pgify
