#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE \`jos_banner\` (
  \`bid\` int(11) NOT NULL AUTO_INCREMENT,
  \`cid\` int(11) NOT NULL DEFAULT '0',
  \`type\` varchar(30) NOT NULL DEFAULT 'banner',
  \`name\` varchar(255) NOT NULL DEFAULT '',
  \`alias\` varchar(255) NOT NULL DEFAULT '',
  \`imptotal\` int(11) NOT NULL DEFAULT '0',
  \`impmade\` int(11) NOT NULL DEFAULT '0',
  \`clicks\` int(11) NOT NULL DEFAULT '0',
  \`imageurl\` varchar(100) NOT NULL DEFAULT '',
  \`clickurl\` varchar(200) NOT NULL DEFAULT '',
  \`date\` datetime DEFAULT NULL,
  \`showBanner\` tinyint(1) NOT NULL DEFAULT '0',
  \`checked_out\` tinyint(1) NOT NULL DEFAULT '0',
  \`checked_out_time\` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  \`editor\` varchar(50) DEFAULT NULL,
  \`custombannercode\` text,
  \`catid\` int(10) unsigned NOT NULL DEFAULT '0',
  \`description\` text NOT NULL,
  \`sticky\` tinyint(1) unsigned NOT NULL DEFAULT '0',
  \`ordering\` int(11) NOT NULL DEFAULT '0',
  \`publish_up\` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  \`publish_down\` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  \`tags\` text NOT NULL,
  \`params\` text NOT NULL,
  PRIMARY KEY (\`bid\`),
  KEY \`viewbanner\` (\`showBanner\`),
  KEY \`idx_banner_catid\` (\`catid\`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
EOF

cat > "$expected" <<EOF
CREATE TABLE jos_banner (
  bid int NOT NULL ,
  cid int NOT NULL DEFAULT E'0',
  type varchar(30) NOT NULL DEFAULT E'banner',
  name varchar(255) NOT NULL DEFAULT E'',
  alias varchar(255) NOT NULL DEFAULT E'',
  imptotal int NOT NULL DEFAULT E'0',
  impmade int NOT NULL DEFAULT E'0',
  clicks int NOT NULL DEFAULT E'0',
  imageurl varchar(100) NOT NULL DEFAULT E'',
  clickurl varchar(200) NOT NULL DEFAULT E'',
  date TIMESTAMP  DEFAULT NULL,
  showBanner SMALLINT NOT NULL DEFAULT E'0',
  checked_out SMALLINT NOT NULL DEFAULT E'0',
  checked_out_time TIMESTAMP    DEFAULT NULL,
  editor varchar(50) DEFAULT NULL,
  custombannercode text,
  catid int  NOT NULL DEFAULT E'0',
  description text NOT NULL,
  sticky SMALLINT  NOT NULL DEFAULT E'0',
  ordering int NOT NULL DEFAULT E'0',
  publish_up TIMESTAMP    DEFAULT NULL,
  publish_down TIMESTAMP    DEFAULT NULL,
  tags text NOT NULL,
  params text NOT NULL,
  PRIMARY KEY (bid)
    
    
)   ;

CREATE INDEX jos_banner_viewbanner_index ON jos_banner  ( showBanner ) ;
CREATE INDEX jos_banner_idx_banner_catid_index ON jos_banner  ( catid ) ;
CREATE SEQUENCE jos_banner_bid_seq START 1 ;
ALTER TABLE jos_banner ALTER COLUMN bid SET DEFAULT NEXTVAL ( 'jos_banner_bid_seq' ) ;
EOF

pgify
