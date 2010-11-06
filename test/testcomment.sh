#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
INSERT INTO \`serendipity_comments\` VALUES (1,3,0,1228270686,'','Mike','someemail@miketec.org','http://www.miketec.org/serendipity/','76.174.157.177','I\'ve managed to fix some of these problems, mostly by abusing the floating property. Will post an update.','NORMAL','false','approved','http://www.miketec.org/serendipity/serendipity_admin.php');
EOF

cat > "$expected" <<EOF
INSERT INTO "serendipity_comments" VALUES (1,3,0,1228270686,E'',E'Mike',E'someemail@miketec.org',E'http://www.miketec.org/serendipity/',E'76.174.157.177',E'I\'ve managed to fix some of these problems, mostly by abusing the floating property. Will post an update.',E'NORMAL',E'false',E'approved',E'http://www.miketec.org/serendipity/serendipity_admin.php');
EOF

pgify
