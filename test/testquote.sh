#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
INSERT INTO \`tbl_TMarineModelDetails_EngAdj\` VALUES ('A & L FIBERGLASS','0001','2001','','LAGOON CLASSIC 160/FO','6600000003','','16\'','Outboard Boats','Fiberglass','6\'','1<br>50 HP<br>Gasoline','800','0.0000',76,NULL,NULL,NULL);
EOF

cat > "$expected" <<EOF
INSERT INTO "tbl_tmarinemodeldetails_engadj" VALUES (E'A & L FIBERGLASS',E'0001',E'2001',E'',E'LAGOON CLASSIC 160/FO',E'6600000003',E'',E'16\'',E'Outboard Boats',E'Fiberglass',E'6\'',E'1<br>50 HP<br>Gasoline',E'800',E'0.0000',76,NULL,NULL,NULL);
EOF

pgify
