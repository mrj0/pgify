#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
CREATE TABLE \`jos_components\` (
  \`id\` int(11) NOT NULL AUTO_INCREMENT,
  \`name\` varchar(50) NOT NULL DEFAULT '',
  \`link\` varchar(255) NOT NULL DEFAULT '',
  \`menuid\` int(11) unsigned NOT NULL DEFAULT '0',
  \`parent\` int(11) unsigned NOT NULL DEFAULT '0',
  \`admin_menu_link\` varchar(255) NOT NULL DEFAULT '',
  \`admin_menu_alt\` varchar(255) NOT NULL DEFAULT '',
  \`option\` varchar(50) NOT NULL DEFAULT '',
  \`ordering\` int(11) NOT NULL DEFAULT '0',
  \`admin_menu_img\` varchar(255) NOT NULL DEFAULT '',
  \`iscore\` tinyint(4) NOT NULL DEFAULT '0',
  \`params\` text NOT NULL,
  \`enabled\` tinyint(4) NOT NULL DEFAULT '1',
  PRIMARY KEY (\`id\`),
  KEY \`parent_option\` (\`parent\` asc,\`option\`(32) desc)
) ENGINE=MyISAM AUTO_INCREMENT=34 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
EOF

cat > "$expected" <<EOF
CREATE TABLE jos_components (
  id int NOT NULL ,
  name varchar(50) NOT NULL DEFAULT E'',
  link varchar(255) NOT NULL DEFAULT E'',
  menuid int  NOT NULL DEFAULT E'0',
  parent int  NOT NULL DEFAULT E'0',
  admin_menu_link varchar(255) NOT NULL DEFAULT E'',
  admin_menu_alt varchar(255) NOT NULL DEFAULT E'',
  option varchar(50) NOT NULL DEFAULT E'',
  ordering int NOT NULL DEFAULT E'0',
  admin_menu_img varchar(255) NOT NULL DEFAULT E'',
  iscore SMALLINT NOT NULL DEFAULT E'0',
  params text NOT NULL,
  enabled SMALLINT NOT NULL DEFAULT E'1',
  PRIMARY KEY (id)
    
)    ;
/*!40101 SET character_set_client = @saved_cs_client */;

CREATE INDEX jos_components_parent_option_index ON jos_components  ( parent asc, option desc ) ;
CREATE SEQUENCE jos_components_id_seq START 34 ;
ALTER TABLE jos_components ALTER COLUMN id SET DEFAULT NEXTVAL ( 'jos_components_id_seq' ) ;
EOF

pgify
