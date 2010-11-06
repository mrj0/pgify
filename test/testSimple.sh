#!/bin/bash

. test/testcommon.sh

cat > "$input" <<EOF
SELECT distinctrow
	HIGH_PRIORITY
	STRAIGHT_JOIN
	SQL_SMALL_RESULT
	SQL_BIG_RESULT
	SQL_BUFFER_RESULT
	SQL_CACHE
	SQL_NO_CACHE
	SQL_CALC_FOUND_ROWS 
1 as "Ernleȝe",
2 two,
o.*
into outfile 'asdf'
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
from tableone o,
tabletwo t,
( select all * from dual t ) dualtest,
test
where o.one = 2
union select 2
order by 1
limit 2,1 
PROCEDURE analyze ( 1, 'asdf', woot, "woot" )
into outfile 'asdf'
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
for update
--lock in share mode
;
EOF

cat > "$expected" <<EOF
SELECT DISTINCT
	
	
	
	
	
	
	
	 
1 as "Ernleȝe",
2 two,
o.*
  
         
     
from tableone o,
tabletwo t,
( select all * from dual t ) dualtest,
test
where o.one = 2
union select 2
order by 1
limit 2,1 
       
  
         
     
for update
--lock in share mode
;
EOF

pgify
