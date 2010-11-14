#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE \`wp_sabre_table\` (
  \`user_id\` bigint(20) NOT NULL DEFAULT '-1',
  \`user\` tinytext,
  PRIMARY KEY (\`user\`)
) ENGINE=MyISAM AUTO_INCREMENT=493 DEFAULT CHARSET=latin1;
EOF

cat > "$expected" <<EOF
CREATE TABLE "wp_sabre_table" (
  "user_id" bigint NOT NULL DEFAULT E'-1',
  "user" TEXT,
  PRIMARY KEY ("user")
)    ;
EOF

pgify
