#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE \`serendipity_suppress\` (
  \`ip\` varchar(64) DEFAULT NULL,
  \`scheme\` varchar(5) DEFAULT NULL,
  \`host\` varchar(128) DEFAULT NULL,
  \`port\` varchar(5) DEFAULT NULL,
  \`path\` varchar(255) DEFAULT NULL,
  \`query\` varchar(255) DEFAULT NULL,
  \`last\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY \`url_idx\` (\`host\`,\`ip\`),
  KEY \`urllast_idx\` (\`last\`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
EOF

cat > "$expected" <<EOF
CREATE TABLE serendipity_suppress (
  ip varchar(64) DEFAULT NULL,
  scheme varchar(5) DEFAULT NULL,
  host varchar(128) DEFAULT NULL,
  port varchar(5) DEFAULT NULL,
  path varchar(255) DEFAULT NULL,
  query varchar(255) DEFAULT NULL,
  last timestamp NOT NULL DEFAULT NOW ( )   
    
    
)   ;

CREATE OR REPLACE FUNCTION serendipity_suppress_update_last()
RETURNS TRIGGER AS \$\$
BEGIN
   NEW.last =  NOW ( ) ; 
   RETURN NEW;
END;
\$\$ language 'plpgsql';
CREATE TRIGGER serendipity_suppress_update_last_trigger BEFORE UPDATE
   ON serendipity_suppress FOR EACH ROW EXECUTE PROCEDURE serendipity_suppress_update_last();
CREATE INDEX serendipity_suppress_url_idx_index ON serendipity_suppress  ( host, ip ) ;
CREATE INDEX serendipity_suppress_urllast_idx_index ON serendipity_suppress  ( last ) ;
EOF

pgify
