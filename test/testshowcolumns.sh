#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
show full columns from wp_posts from wp like 'posts%';
EOF

cat > "$expected" <<EOF
SELECT * FROM (
SELECT c.column_name AS field,
       udt_name || COALESCE ( '(' || character_maximum_length || ')', '' ) AS TYPE,
       current_setting ( 'LC_COLLATE' ) AS collation,
       is_nullable AS NULL,
       ( SELECT CASE WHEN count ( * ) > 0 THEN 'PRI'
		     ELSE ''
		END
           FROM information_schema.key_column_usage u
          WHERE c.table_catalog = u.table_catalog
            AND c.table_schema = u.table_schema
            AND c.column_name = u.column_name ) AS KEY,
       column_default AS DEFAULT,
       '' AS extra,
       ( SELECT array_to_string ( array_agg ( cp.privilege_type::text ), ',' )
           FROM information_schema.column_privileges cp
          WHERE c.table_catalog = cp.table_catalog
            AND c.table_schema = cp.table_schema
            AND c.column_name = cp.column_name ) AS priv,
       '' AS comment
  FROM information_schema.COLUMNS c
 WHERE c.table_catalog = current_database ( )
   AND c.table_name = 'wp_posts'
   AND c.table_schema = 'wp'
 ORDER BY c.ordinal_position ) SUB
WHERE sub.field 
       like E'posts%';
EOF

pgify
