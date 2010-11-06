#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE \`serendipity_entries\` (
  \`id\` int(11) NOT NULL AUTO_INCREMENT,
  \`title\` varchar(200) DEFAULT NULL,
  \`timestamp\` int(10) unsigned DEFAULT NULL,
  \`body\` text,
  \`comments\` int(4) unsigned DEFAULT '0',
  \`trackbacks\` int(4) unsigned DEFAULT '0',
  \`extended\` text,
  \`exflag\` int(1) DEFAULT NULL,
  \`author\` varchar(20) DEFAULT NULL,
  \`authorid\` int(11) DEFAULT NULL,
  \`isdraft\` enum('true','false') NOT NULL DEFAULT 'true',
  \`allow_comments\` enum('true','false') NOT NULL DEFAULT 'true',
  \`last_modified\` int(10) unsigned DEFAULT NULL,
  \`moderate_comments\` enum('true','false') NOT NULL DEFAULT 'true',
  PRIMARY KEY (\`id\`),
  KEY \`date_idx\` (\`timestamp\`),
  KEY \`mod_idx\` (\`last_modified\`),
  KEY \`edraft_idx\` (\`isdraft\`),
  KEY \`eauthor_idx\` (\`authorid\`),
  FULLTEXT KEY \`entry_idx\` (\`title\`,\`body\`,\`extended\`)
) ENGINE=MyISAM AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;
EOF

cat > "$expected" <<EOF
CREATE TABLE serendipity_entries (
  id int NOT NULL ,
  title varchar(200) DEFAULT NULL,
  timestamp int  DEFAULT NULL,
  body text,
  comments int  DEFAULT E'0',
  trackbacks int  DEFAULT E'0',
  extended text,
  exflag int DEFAULT NULL,
  author varchar(20) DEFAULT NULL,
  authorid int DEFAULT NULL,
  isdraft text CHECK ( isdraft IN (E'true',E'false')) NOT NULL DEFAULT E'true',
  allow_comments text CHECK ( allow_comments IN (E'true',E'false')) NOT NULL DEFAULT E'true',
  last_modified int  DEFAULT NULL,
  moderate_comments text CHECK ( moderate_comments IN (E'true',E'false')) NOT NULL DEFAULT E'true',
  PRIMARY KEY (id)
    
    
    
    
     
)    ;

CREATE INDEX serendipity_entries_date_idx_index ON serendipity_entries  ( timestamp ) ;
CREATE INDEX serendipity_entries_mod_idx_index ON serendipity_entries  ( last_modified ) ;
CREATE INDEX serendipity_entries_edraft_idx_index ON serendipity_entries  ( isdraft ) ;
CREATE INDEX serendipity_entries_eauthor_idx_index ON serendipity_entries  ( authorid ) ;
CREATE SEQUENCE serendipity_entries_id_seq START 16 ;
ALTER TABLE serendipity_entries ALTER COLUMN id SET DEFAULT NEXTVAL ( 'serendipity_entries_id_seq' ) ;
EOF

pgify
