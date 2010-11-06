#!/bin/bash

. test/testcommon.sh

# --
# -- Table structure for table \`wp_terms\`
# --

# DROP TABLE IF EXISTS \`wp_terms\`;
# /*!40101 SET @saved_cs_client     = @@character_set_client */;
# /*!40101 SET character_set_client = utf8 */;
# CREATE TABLE \`wp_terms\` (
#   \`term_id\` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
#   \`name\` varchar(200) NOT NULL DEFAULT '',
#   \`slug\` varchar(200) NOT NULL DEFAULT '',
#   \`term_group\` bigint(10) NOT NULL DEFAULT '0',
#   PRIMARY KEY (\`term_id\`),
#   UNIQUE KEY \`slug\` (\`slug\`),
#   KEY \`name\` (\`name\`)
# ) ENGINE=MyISAM AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;
# /*!40101 SET character_set_client = @saved_cs_client */;

# --
# -- Dumping data for table \`wp_terms\`
# --

# LOCK TABLES \`wp_terms\` WRITE;
# /*!40000 ALTER TABLE \`wp_terms\` DISABLE KEYS */;
# INSERT INTO \`wp_terms\` VALUES (1,'Posts','posts',0),(2,'Blogroll','blogroll',0),(3,'Java','java',0),(4,'TOra','tora',0),(5,'Life','life',0),(6,'Work','work',0),(7,'JEPP','jepp',0),(8,'Get some source','source-links',0);
# /*!40000 ALTER TABLE \`wp_terms\` ENABLE KEYS */;
# UNLOCK TABLES;

cat > "$input" <<EOF
DROP TABLE \`wp_terms\`;
CREATE TABLE \`wp_terms\` (
  \`term_id\` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  \`name\` varchar(200) NOT NULL DEFAULT '',
  \`slug\` varchar(200) NOT NULL DEFAULT '',
  \`term_group\` bigint(10) NOT NULL DEFAULT '0',
  PRIMARY KEY (\`term_id\`),
  UNIQUE KEY \`slug\` (\`slug\`),
  KEY \`name\` (\`name\`) USING HASH /* my addition */
) ENGINE=MyISAM AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;
EOF

cat > "$expected" <<EOF
DROP TABLE wp_terms;
CREATE TABLE wp_terms (
  term_id bigint  NOT NULL ,
  name varchar(200) NOT NULL DEFAULT E'',
  slug varchar(200) NOT NULL DEFAULT E'',
  term_group bigint NOT NULL DEFAULT E'0',
  PRIMARY KEY (term_id),
  UNIQUE   (slug)
       /* my addition */
)    ;

CREATE INDEX wp_terms_name_index ON wp_terms  USING HASH  ( name ) ;
CREATE SEQUENCE wp_terms_term_id_seq START 9 ;
ALTER TABLE wp_terms ALTER COLUMN term_id SET DEFAULT NEXTVAL ( 'wp_terms_term_id_seq' ) ;
EOF

pgify
