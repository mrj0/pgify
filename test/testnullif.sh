#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT COUNT(NULLIF(\`meta_value\` LIKE '%administrator%', FALSE)), COUNT(NULLIF(\`meta_value\` LIKE '%editor%', FALSE)), COUNT(NULLIF(\`meta_value\` LIKE '%author%', FALSE)), COUNT(NULLIF(\`meta_value\` LIKE '%contributor%', FALSE)), COUNT(NULLIF(\`meta_value\` LIKE '%subscriber%', FALSE)), COUNT(*) FROM wp_usermeta WHERE meta_key = 'wp_capabilities'
EOF

cat > "$expected" <<EOF
SELECT COUNT(NULLIF("meta_value" LIKE E'%administrator%', FALSE)), COUNT(NULLIF("meta_value" LIKE E'%editor%', FALSE)), COUNT(NULLIF("meta_value" LIKE E'%author%', FALSE)), COUNT(NULLIF("meta_value" LIKE E'%contributor%', FALSE)), COUNT(NULLIF("meta_value" LIKE E'%subscriber%', FALSE)), COUNT(*) FROM wp_usermeta WHERE meta_key = E'wp_capabilities'
EOF

pgify
