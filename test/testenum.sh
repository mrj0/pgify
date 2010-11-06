#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
create table foo (
   id     int not null auto_increment primary key,
   state  enum('enabled', 'disabled'));
EOF

cat > "$expected" <<EOF
create table foo (
   id     int not null  primary key,
   state  text CHECK ( state IN (E'enabled', E'disabled')));


CREATE SEQUENCE foo_id_seq START 1 ;
ALTER TABLE foo ALTER COLUMN id SET DEFAULT NEXTVAL ( 'foo_id_seq' ) ;
EOF

pgify
