#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT comment_id FROM wp_comments WHERE date_sub('2010-12-05 17:52:11', INTERVAL 15 DAY) > comment_date_gmt AND comment_approved = 'spam';
EOF

cat > "$expected" <<EOF
SELECT comment_id FROM wp_comments WHERE date_sub(E'2010-12-05 17:52:11', INTERVAL' 15 DAY') > comment_date_gmt AND comment_approved = E'spam';
EOF

pgify
