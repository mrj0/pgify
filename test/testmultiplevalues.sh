#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
INSERT INTO \`serendipity_access\` VALUES (0,1,'category','read',''),(0,1,'category','write',''),(0,2,'category','read',''),(0,2,'category','write',''),(0,3,'category','read',''),(0,3,'category','write',''),(0,4,'category','read',''),(0,4,'category','write',''),(0,5,'category','read',''),(0,5,'category','write',''),(0,0,'directory','read','tora/'),(0,0,'directory','write','tora/');
EOF

cat > "$expected" <<EOF
INSERT INTO "serendipity_access" VALUES (0,1,E'category',E'read',E''),(0,1,E'category',E'write',E''),(0,2,E'category',E'read',E''),(0,2,E'category',E'write',E''),(0,3,E'category',E'read',E''),(0,3,E'category',E'write',E''),(0,4,E'category',E'read',E''),(0,4,E'category',E'write',E''),(0,5,E'category',E'read',E''),(0,5,E'category',E'write',E''),(0,0,E'directory',E'read',E'tora/'),(0,0,E'directory',E'write',E'tora/');
EOF

pgify
