#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT SQL_CALC_FOUND_ROWS  wp_posts.* FROM wp_posts  WHERE 1=1  AND wp_posts.post_type = 'post' AND (wp_posts.post_status = 'publish')  ORDER BY wp_posts.post_date DESC LIMIT 0, 10
EOF

cat > "$expected" <<EOF
SELECT   wp_posts.* FROM wp_posts  WHERE 1=1  AND wp_posts.post_type = E'post' AND (wp_posts.post_status = E'publish')  ORDER BY wp_posts.post_date DESC LIMIT  10 OFFSET 0
EOF

pgify
