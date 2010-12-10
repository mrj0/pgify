/*******************************************************************************

DESCRIPTION:
		Grammar for Oracle's SELECT statement for ANTLR v3, target any language
AUTHOR:
		Ivan.Brezina (ibre5041@ibrezina.net)

DATE:
		AUG 2010
BASED ON:
		PLSQL3.g Andrey Kharitonkin (thikone@gmail.com)
		PLSQLGrammar.g for ANTLR v2
		Qazi Firdous Ahmed (qazif_ahmed@infosys.com) 
		Krupa Benhur (krupa_bg@infosys.com)
		Manojaba Banerjee (manojaba_banerjee@infosys.com)
		Infosys Technologies Ltd., Bangalore, India
		Sept 18, 2002
		This grammar is for PL/SQL.
COMMENT:
		This grammar file is based on freely downloadable
		file PLSQL3.g. I extracted only those rules that
		are mandatory for SELECT statement. Column list was
		partialy rewritten, support for analytic queries added,
		list of reserved words and keywords added.
ORIGINAL COMMENT:
		The grammar has been mostly re-written for ANTLR v3,
		using Oracle 10g Release 2 documentation and ANTLR book.
		New SQL and PL/SQL expression rules, SQL statments
		SELECT, INSERT, UPDATE, DELETE are fully supported.
		Generated parser can parse most of valid PL/SQL and 
		it was tested with over 10 Mb of test source code.
		Let me know if something cannot be parsed by this grammar.
KNOWN ISSUES:
		XQUERIES are unsupported. List of reserved words/keywords
		needs to be amended. PL/SQL support was removed.

*******************************************************************************/

grammar mysql;

options {
	language=C;
	backtrack=true;
	memoize=true;
	output=AST;
	ASTLabelType=pANTLR3_BASE_TREE;
}

tokens {
	T_USE_DATABASE;
	T_SHOW_DATABASES;
	T_CREATE_TABLE;
	T_CREATE_TABLE_INDEX;
	T_CREATE_TABLE_OPTIONS;
	T_CREATE_TABLE_FKEY;
	T_CREATE_TABLE_ENUM;
	T_CREATE_TABLE_FULLTEXT_INDEX;
	T_CREATE_TABLE_ONUPDATE;
	T_CREATE_TABLE_COLUMN_DEFAULT;
	T_CREATE_TABLE_COLUMN_DEF;
	T_SERVER_VARIABLE;
	T_LOCK_TABLE;
	
	T_SELECT_STATEMENT;
	T_SHOW_LIKE;
	T_SHOW_FROM;
	T_SHOW_COLUMNS;
	
	T_SHOW_TABLES;

	T_CALL_PARAMETER;
	T_FUNCTION_NAME;
	T_FUNCTION_NULLIF;
	T_FUNCTION_IFNULL;
	T_FUNCTION_IF;
	
	T_WHERE;
	T_LIMIT;
	
	T_TRANSFORM; /* used when adding new statements during tree walk */
}

@lexer::header {
#include "pgify.h"
#include <glib.h>
}
@parser::header {
#include "pgify.h"
}

start_rule
	: (
        (   select_statement
        |	update_statement
        |	insert_statement
        |	merge_statement
        |	delete_statement
        |   drop_statement
        |   create_table_statement
        |   create_database_statement
        |   use_database_statement
        |	show_databases_statement
        |	show_tables_statement
        |	show_columns_statement
        |	lock_tables_statement
        |	unlock_tables_statement
        |	SEMI
        )
        EOF? 
      )*
	;

unlock_tables_statement
	: 'UNLOCK' K_TABLES
	SEMI?
	->
	;
	
/* ================================================================================
   LOCK TABLES statement
   ================================================================================ */
lock_tables_statement
	: K_LOCK K_TABLES
	lock_tables_tablename
	( ',' lock_tables_tablename )*
	table_lock_type
	SEMI?
	-> ^(T_LOCK_TABLE
	K_LOCK K_TABLES
	lock_tables_tablename
	( ',' lock_tables_tablename )*
	table_lock_type
	SEMI?
	)
	;
	
lock_tables_tablename
	: (schema_name DOT)? identifier ( K_AS? identifier )?
	;

table_lock_type
	: ( K_READ K_LOCAL? )
	| ( K_LOW_PRIORITY? K_WRITE )
	;
   
/* ================================================================================
   USE DATABASE statement
   ================================================================================ */
use_database_statement
	: K_USE identifier
	SEMI?
	-> T_TRANSFORM[""] ^( T_USE_DATABASE K_USE identifier SEMI? )
	;
	
/* ================================================================================
   SHOW DATABASES statement
   ================================================================================ */
show_databases_statement
	: K_SHOW 'DATABASES'
	SEMI?
	-> T_TRANSFORM["select schema_name as database from information_schema.schemata order by 1"] SEMI?
	;
	
/* ================================================================================
   SHOW TABLES statement
   ================================================================================ */
show_tables_statement
	: K_SHOW K_FULL? 'TABLES'
	show_from?
	( show_tables_like | show_where )?
	SEMI?
	-> ^(T_SHOW_TABLES
	K_SHOW K_FULL? 'TABLES'
	show_from?
	show_tables_like?
	show_where?
	SEMI? )
	;

show_from
	: ( K_FROM | K_IN ) sql_identifier
	-> ^(T_SHOW_FROM sql_identifier)
	;
	
show_tables_like
	: K_LIKE quoted_string
	-> ^(T_SHOW_LIKE K_LIKE quoted_string)
	;
	
show_where
	: where_clause
	;

/* ================================================================================
   SHOW COLUMNS statement
   ================================================================================ */
show_columns_statement
	: K_SHOW K_FULL? ( 'COLUMNS' | 'FIELDS' )
	show_from /* table */
	show_from? /* db */
	( show_tables_like | show_where )?
	SEMI?
	-> ^(T_SHOW_COLUMNS
	K_SHOW K_FULL?
	show_from /* table */
	show_from? /* db */
	show_tables_like?
	show_where?
	SEMI? )
	;
	
/* ================================================================================
   CREATE DATABASE statement
   ================================================================================ */
create_database_statement
	: K_CREATE K_DATABASE identifier
	create_database_options*
	SEMI?
	-> K_CREATE K_DATABASE[" SCHEMA"] identifier SEMI?
	/* todo charset options */
	;
	
create_database_options
	: ( K_DEFAULT? ( ( K_CHARACTER K_SET ) | K_CHARSET ) '=' ID )
	| ( K_DEFAULT? K_COLLATE '=' ID )
	;

        
/* ================================================================================
   CREATE TABLE statement
   ================================================================================ */
create_table_statement
	: K_CREATE K_TEMPORARY? K_TABLE
	( K_IF K_NOT K_EXISTS )?
	(schema_name DOT)? identifier
	( table_create_like | create_definition )
	table_options*
	( K_AS? select_statement )?
	SEMI?
	->
	^(T_CREATE_TABLE
	K_CREATE K_TEMPORARY? K_TABLE
	( K_IF K_NOT K_EXISTS )?
	(schema_name DOT)? identifier
	table_create_like
	create_definition
	^(T_CREATE_TABLE_OPTIONS table_options)*
	K_AS? select_statement?
	SEMI?
	)
	;

table_create_like
	: ( K_LIKE identifier ) | ( LPAREN K_LIKE identifier RPAREN )
	;

create_definition
	: LPAREN column_definition ( ',' column_definition )* ( ',' column_constraint_definition )* RPAREN
	;

column_definition
	: identifier datatype column_definition_options*
	-> ^(T_CREATE_TABLE_COLUMN_DEF
	identifier datatype column_definition_options* )
	;
	
column_definition_options
	: 
	( K_NOT K_NULL )
	| K_NULL
	| column_definition_default
	| column_definition_onupdate
	| K_AUTO_INCREMENT
	| ( K_UNIQUE )
	| ( K_PRIMARY? K_KEY )
	| ( K_COMMENT QUOTED_STRING )
	| ( K_COLUMN_FORMAT (K_FIXED | K_DYNAMIC | K_DEFAULT) )
	| ( K_STORAGE ( 'DISK' | 'MEMORY' | K_DEFAULT ) )
	| column_definition_collate
	| column_definition_charset
	;
	
column_definition_collate
	: K_COLLATE identifier
	->
	;
	
column_definition_charset
	: ( ( K_CHARACTER K_SET ) | K_CHARSET ) identifier
	->
	;
	
column_definition_default
	: K_DEFAULT sql_expression
	-> ^(T_CREATE_TABLE_COLUMN_DEFAULT
	K_DEFAULT sql_expression )
	;
	
column_definition_onupdate
	: K_ON K_UPDATE sql_expression
	-> ^(T_CREATE_TABLE_ONUPDATE
	K_ON K_UPDATE sql_expression )
	;

column_constraint_definition
	: constraint_primary_key
	| constraint_unique_key
	| constraint_index_key
	| constraint_table_key
	| constraint_fulltext_index_key
	;
	
constraint_primary_key
	: constraint_name? K_PRIMARY K_KEY index_type? LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN index_option?
	-> K_PRIMARY K_KEY LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN
	;
	
constraint_unique_key
	: constraint_name? K_UNIQUE ( K_INDEX | K_KEY )?
	constraint_unique_key_name? index_type? LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN index_option?
	-> K_UNIQUE LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN
	;
	
constraint_unique_key_name
	: identifier
	;

constraint_index_key
	: ( K_INDEX | K_KEY ) constraint_unique_key_name? index_type? LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN index_option?
	/* rewrite to tree because we're going to have to remove this whole thing */
	-> ^(T_CREATE_TABLE_INDEX
		constraint_unique_key_name? index_type? LPAREN constraint_index_colname ( ',' constraint_index_colname )* RPAREN index_option?
	)
	;
	
constraint_index_colname
	: identifier ( LPAREN NUMBER RPAREN )? ( K_ASC | K_DESC )?
	-> identifier K_ASC? K_DESC?
	;
	
constraint_fulltext_index_key
	: K_FULLTEXT K_KEY identifier? LPAREN identifier ( ',' identifier )* RPAREN
	-> ^(T_CREATE_TABLE_FULLTEXT_INDEX
	K_FULLTEXT K_KEY identifier? LPAREN identifier ( ',' identifier )* RPAREN )
	;
	
constraint_table_key
	: constraint_name? K_FOREIGN K_KEY
	LPAREN identifier ( ',' identifier) * RPAREN
	constraint_reference_definition
	-> ^(T_CREATE_TABLE_FKEY
	constraint_name? K_FOREIGN K_KEY
	LPAREN identifier ( ',' identifier) * RPAREN
	constraint_reference_definition
	);
	
constraint_reference_definition
	: K_REFERENCES (schema_name DOT)? identifier LPAREN identifier ( ',' identifier)* RPAREN
	( ( 'MATCH' 'FULL' ) | ( 'MATCH' 'PARTIAL' ) | ( 'MATCH' 'SIMPLE' ) )?
	( K_ON K_DELETE constraint_reference_option )?
	( K_ON K_UPDATE constraint_reference_option )?
	;
	
constraint_reference_option
	: K_RESTRICT | K_CASCADE | ( K_SET K_NULL ) | ( 'NO' 'ACTION' )
	;
	
constraint_name
	: K_CONSTRAINT identifier
	;
	
index_type
	: K_USING ( 'BTREE' | 'HASH' )
	;
	
index_option
	: ( 'KEY_BLOCK_SIZE' '=' NUMBER )?
	  index_type?
	  ( 'WITH PARSER' identifier )?
	  -> index_type?
	;
	
table_options
	: ( K_ENGINE '=' ( K_MYISAM | K_INNODB | identifier ) )
	| ( K_AUTO_INCREMENT '=' NUMBER )
	| ( 'AVG_ROW_LENGTH' '=' NUMBER )
	| ( K_DEFAULT? ( ( K_CHARACTER K_SET ) | K_CHARSET ) '=' ID )
	| ( 'CHECKSUM' '=' NUMBER )
	| ( K_DEFAULT? K_COLLATE '=' ID )
	| ( K_COMMENT '=' QUOTED_STRING )
	| ( 'CONNECTION' '=' QUOTED_STRING )
	| ( 'DATA' 'DIRECTORY' '=' QUOTED_STRING )
	| ( 'DELAY_KEY_WRITE' '=' NUMBER )
	| ( K_INDEX 'DIRECTORY' '=' QUOTED_STRING )
	| ( 'INSERT_METHOD' '=' ( 'NO' | 'FIRST' | 'LAST' ) )
	| ( 'KEY_BLOCK_SIZE' '=' NUMBER )
	| ( 'MAX_ROWS' '=' NUMBER )
	| ( 'MIN_ROWS' '=' NUMBER )
	| ( 'PACK_KEYS' '=' ( NUMBER | K_DEFAULT ) )
	| ( 'PASSWORD' '=' QUOTED_STRING )
	| ( 'ROW_FORMAT' '=' ( 'DEFAULT'|'DYNAMIC'|'FIXED'|'COMPRESSED'|'REDUNDANT'|'COMPACT' ))
	| ( 'TABLESPACE' ID ( 'STORAGE' ('DISK'|'MEMORY'|'DEFAULT')))
	// todo UNION not supported
/*	-> ^(T_CREATE_TABLE_OPTIONS
	K_ENGINE? '='? identifier?
	K_AUTO_INCREMENT '=' NUMBER
	'AVG_ROW_LENGTH' '=' NUMBER
	K_DEFAULT? K_CHARACTER K_SET K_CHARSET '=' ID
	'CHECKSUM' '=' NUMBER
	K_DEFAULT? K_COLLATE '=' ID
	K_COMMENT '=' QUOTED_STRING 
	'CONNECTION' '=' QUOTED_STRING 
	'DATA' 'DIRECTORY' '=' QUOTED_STRING 
	'DELAY_KEY_WRITE' '=' NUMBER 
	K_INDEX 'DIRECTORY' '=' QUOTED_STRING
	'INSERT_METHOD' '=' 'NO' 'FIRST' 'LAST'
	'KEY_BLOCK_SIZE' '=' NUMBER 
	'MAX_ROWS' '=' NUMBER 
	'MIN_ROWS' '=' NUMBER 
	'PACK_KEYS' '=' NUMBER K_DEFAULT
	'PASSWORD' '=' QUOTED_STRING 
	'ROW_FORMAT' '=' 'DEFAULT' 'DYNAMIC' 'FIXED' 'COMPRESSED' 'REDUNDANT' 'COMPACT'
	'TABLESPACE' ID 'STORAGE' 'DISK' 'MEMORY' 'DEFAULT'
	)*/
	;
	
/* ================================================================================
   DROP statement
   ================================================================================ */
drop_statement
	: K_DROP K_TEMPORARY? ( K_TABLE | K_DATABASE )
	( K_IF K_EXISTS )?
	table_list
    ( K_RESTRICT | K_CASCADE )?
    SEMI?
    -> K_DROP K_TEMPORARY? K_TABLE? K_DATABASE[" SCHEMA"]?
    K_IF? K_EXISTS?
    table_list
    SEMI?
	;
/* ================================================================================
   DELETE Statement
   ================================================================================ */
delete_statement
    : K_DELETE K_FROM?
        (
            dml_table_expression_clause
        |      K_ONLY LPAREN dml_table_expression_clause RPAREN
        )
        t_alias? where_clause? returning_clause? error_logging_clause?
        SEMI?
    ;

/* ================================================================================
   MERGE Statement
   ================================================================================ */
merge_statement
	: K_MERGE K_INTO (schema_name DOT)? table_name t_alias?
        K_USING
        (
            subquery
        |	(schema_name DOT)? table_name
        )
        t_alias? K_ON LPAREN sql_condition RPAREN
        merge_update_clause? merge_insert_clause? error_logging_clause?
        SEMI?
    ;

merge_update_clause
	: K_WHEN K_MATCHED K_THEN K_UPDATE K_SET column_spec EQ (K_DEFAULT | sql_expression)
        (COMMA column_spec EQ (K_DEFAULT | sql_expression))*
        where_clause? (K_DELETE where_clause)?
    ;

merge_insert_clause
	: K_WHEN K_NOT K_MATCHED K_THEN K_INSERT LPAREN column_spec (COMMA column_spec)* RPAREN
        K_VALUES LPAREN (K_DEFAULT | sql_expression) (COMMA (K_DEFAULT | sql_expression))* RPAREN
        where_clause? 
    ;

/* ================================================================================
   INSERT Statement
   ================================================================================ */
insert_statement
	: K_INSERT (single_table_insert | multi_table_insert)
	SEMI?
    ;
single_table_insert
	: insert_into_clause ( values_clause returning_clause? | subquery ) error_logging_clause?
    ;
insert_into_clause
	: K_INTO dml_table_expression_clause t_alias? ( LPAREN column_name ( COMMA column_name)* RPAREN )?
	;
values_clause
	: K_VALUES LPAREN ( K_DEFAULT | sql_expression) ( COMMA (K_DEFAULT | sql_expression))* RPAREN
	( COMMA LPAREN ( K_DEFAULT | sql_expression) ( COMMA (K_DEFAULT | sql_expression))* RPAREN )*
    ;
returning_clause
    : ( K_RETURN | K_RETURNING ) sql_expression (COMMA sql_expression)* K_INTO data_item (COMMA data_item)*
    ;
multi_table_insert
	: (
            K_ALL ( insert_into_clause values_clause? error_logging_clause? )+
        |   conditional_insert_clause
        )
        subquery
    ;
conditional_insert_clause
	: ( K_ALL | K_FIRST )?
        ( K_WHEN sql_condition K_THEN ( insert_into_clause values_clause? )+ )+
        K_ELSE ( insert_into_clause values_clause? )+
    ;
dml_table_expression_clause
	:	
		( schema_name DOT)? table_name ( partition_extension_clause | AT_SIGN sql_identifier/*TODO dblink*/)?
	|	subquery subquery_restricrion_clause? (pivot_clause|unpivot_clause)?
	|	LPAREN subquery subquery_restricrion_clause? RPAREN
	|	table_collection_clause
	;
error_logging_clause
	: K_LOG K_ERRORS ( K_INTO (schema_name DOT)? table_name)? (LPAREN simple_expression RPAREN)? (K_REJECT K_LIMIT (NUMBER | K_UNLIMITED))?
    ;
data_item
	: sql_identifier
    ;

/* ================================================================================
   UPDATE Statement
   ================================================================================ */
update_statement
	: K_UPDATE ( K_ONLY LPAREN dml_table_expression_clause RPAREN | dml_table_expression_clause) t_alias?
		K_SET update_set_clause ( ',' update_set_clause )* where_clause? returning_clause? error_logging_clause?
		SEMI?
	;

update_set_clause
	: 
        (
            K_VALUE LPAREN t_alias RPAREN EQ ( simple_expression | LPAREN subquery RPAREN)
        |	(
                column_name EQ ( K_DEFAULT | LPAREN subquery RPAREN | simple_expression)
            |	LPAREN column_name (COMMA column_name)* RPAREN EQ LPAREN subquery RPAREN
                (COMMA LPAREN column_name (COMMA column_name)* RPAREN EQ LPAREN subquery RPAREN)*
            )
        )
    ;
/* ================================================================================
   SELECT Statement
   ================================================================================ */
select_statement
	:
	subquery_factoring_clause?
	K_SELECT ( K_DISTINCT | K_DISTINCTROW | K_UNION | K_ALL )? select_hint select_list
	( into_file_clause )?
	( K_FROM table_reference_list )?
//        ( table_reference_list | join_clause | LPAREN join_clause RPAREN )
	( where_clause )?
	( hierarchical_query_clause )?
	( group_by_clause )?
	( K_HAVING sql_condition )?
//	( model_clause )?
	( union_clause )?
	( order_by_clause )?
	( limit_clause )?
	( procedure_clause )?
	( into_file_clause )?
	( for_update_clause | lock_in_share_mode )?
	SEMI?
	-> ^(T_SELECT_STATEMENT subquery_factoring_clause?
	K_SELECT
	K_DISTINCT? K_DISTINCTROW? K_UNION? K_ALL?
	select_list
//	into_file_clause?
	( K_FROM table_reference_list )?
	where_clause?
//	( hierarchical_query_clause )?
	group_by_clause?
	( K_HAVING sql_condition )?
//	( model_clause )?
	union_clause?
	order_by_clause?
	limit_clause?
//	( procedure_clause )?
//	( into_file_clause )?
	for_update_clause?
//	lock_in_share_mode?
	SEMI? ) /* tree */
	;
	
/* ================================================================================
   subquery factoring
   ================================================================================ */
subquery_factoring_clause
	:
	with=K_WITH
// NOTE: these two lines were commented out just to preserve COMMAs in parse tree        
//	si1=sql_identifier (lp1=LPAREN sl1=select_list rp1=RPAREN)? as1=k_as sq1=subquery  
//	(COMMA si2=sql_identifier (lp2=LPAREN sl2=select_list rp2=RPAREN)? as2=k_as sq2=subquery)*
	subquery_factoring_clause_part_first subquery_factoring_clause_part_next*
	search_clause?
	cycle_clause?
//		->^('t_with' $with subquery_factoring_clause_part_first subquery_factoring_clause_part_next* search_clause? cycle_clause?)
    ;
subquery_factoring_clause_part_first
	:	sql_identifier (LPAREN select_list RPAREN)? K_AS subquery
    ;
subquery_factoring_clause_part_next
	:	COMMA sql_identifier (LPAREN select_list RPAREN)? K_AS subquery
    ;

search_clause
	: K_SEARCH ( K_DEPTH | K_BREADTH ) K_FIRST K_BY
 	( c_alias K_ASC ? K_DESC ? (K_NULLS K_FIRST)? (K_NULLS K_LAST)? )
 	( COMMA c_alias K_ASC ? K_DESC ? (K_NULLS K_FIRST)? (K_NULLS K_LAST)? )*
	K_SET sql_identifier
	;

cycle_clause
	: K_CYCLE c_alias ( COMMA c_alias)* K_SET sql_identifier K_TO literal K_DEFAULT literal
	;

/* ================================================================================
   Query column list specs (ie. everything between "SELECT" ... "FROM"
   ================================================================================ */

select_hint
	: K_HIGH_PRIORITY? K_STRAIGHT_JOIN? K_SQL_SMALL_RESULT? K_SQL_BIG_RESULT? K_SQL_BUFFER_RESULT? K_SQL_CACHE? K_SQL_NO_CACHE? K_SQL_CALC_FOUND_ROWS?
	;

select_list
//	: displayed_column (COMMA displayed_column)*
	: displayed_column_part_first displayed_column_part_next*
//		-> ^('t_column_list' displayed_column_part_first displayed_column_part_next*)
	;
displayed_column_part_first
	: displayed_column
    ;
displayed_column_part_next options { backtrack=false; }
	: COMMA displayed_column
    ;        
displayed_column
	: (
        asterisk1=ASTERISK
		| schema=sql_identifier DOT asterisk2=ASTERISK
		| sql_condition
		)   
		(alias|alias_name=sql_identifier)?
//        -> ^('t_select_column' $asterisk1? $schema? DOT? $asterisk2? sql_expression? alias? $alias_name? )
    ;
mysql_server_variable
	: '@' '@' ( ID | BACKQUOTED_STRING )
	-> ^(T_SERVER_VARIABLE ID? BACKQUOTED_STRING? )
	;

sql_expression
	:	expr_add
	;
expr_add
	:	expr_mul ( ( PLUS | MINUS | DOUBLEVERTBAR ) expr_mul )*
	;
expr_mul
	:	expr_sign ( ( ASTERISK | DIVIDE ) expr_sign )*
	;
expr_sign // in fact this is not "sign" but unary operator
	:	( PLUS | MINUS | K_PRIOR | K_CONNECT_BY_ROOT )? expr_pow
	;
expr_pow
	:	expr_like ( EXPONENT expr_like )*
	;
expr_like
	:	expr_expr( K_LIKE QUOTED_STRING ) ?
	;
expr_expr
	:	datetime_expression
	|	STUPID_MYSQL_DATE
	|	STUPID_MYSQL_TIMESTAMP
	|	interval_expression        
	|	( expr_paren ) => expr_paren
	|	( cast_expression) => cast_expression
	|	( special_expression ) => special_expression
	|	( analytic_function ) => analytic_function
	|	( function_expression ) => function_expression
//	|	( compound_expression ) => compound_expression
	|	( case_expression ) => case_expression
//	|	( cursor_expression ) => cursor_expression
	|	( simple_expression ) => simple_expression
//	|	( select_expression ) => select_expression replaced with subquery
//	|	object_access_expression
//	|	scalar_subquery_expression
//	|	model_expression
//	|	type_constructor_expression
//	|	variable_expression
//	:	K_NULL | NUMBER | QUOTED_STRING | IDENTIFIER
	| mysql_server_variable
	|	( subquery ) => subquery
	;
expr_paren
	:	LPAREN nested_expression RPAREN
	;
nested_expression
	:	sql_expression
	;
function_expression
	:	function_year
	|	function_month
	|	function_expression_concat_ws
	|	function_expression_concat
	|	function_expression_nullif
	|	function_expression_ifnull
	|	function_expression_if
	|	function_expression_found_rows
	|	function_expression_normal
	;
	
function_year
	: K_YEAR LPAREN call_parameter RPAREN
	-> T_TRANSFORM[" EXTRACT "] LPAREN K_YEAR T_TRANSFORM[" FROM "] call_parameter RPAREN
	;
	
function_month
	: K_MONTH LPAREN call_parameter RPAREN
	-> T_TRANSFORM[" EXTRACT "] LPAREN K_MONTH T_TRANSFORM[" FROM "] call_parameter RPAREN
	;
	
function_expression_found_rows
	: K_FOUND_ROWS LPAREN RPAREN
	-> K_FOUND_ROWS
	;
	
function_expression_nullif
	: K_NULLIF LPAREN call_parameter COMMA call_parameter RPAREN
	-> ^( T_FUNCTION_NULLIF K_NULLIF LPAREN call_parameter COMMA call_parameter RPAREN )
	;

function_expression_ifnull
	: K_IFNULL LPAREN call_parameter COMMA call_parameter RPAREN
	-> ^( T_FUNCTION_IFNULL T_TRANSFORM[" COALESCE "] LPAREN call_parameter T_TRANSFORM["::text "] COMMA call_parameter T_TRANSFORM["::text "] RPAREN )
	;

function_expression_if
	: K_IF LPAREN call_parameter COMMA call_parameter COMMA call_parameter RPAREN
	-> ^( T_FUNCTION_IF call_parameter call_parameter call_parameter )
	;

function_expression_concat
	: K_CONCAT LPAREN call_parameters RPAREN
	-> LPAREN[" ARRAY_TO_STRING(ARRAY["] call_parameters RPAREN["], '')"]
	;
	
function_expression_concat_ws
	: K_CONCAT_WS LPAREN sql_identifier COMMA function_expression_parameters RPAREN
	-> LPAREN[" ARRAY_TO_STRING(ARRAY["] function_expression_parameters T_TRANSFORM["], "] sql_identifier RPAREN
	;
	
function_expression_parameters
	: call_parameter ( COMMA call_parameter )*
	;
	
function_expression_normal
 	:	(database_function_name|function_name|analytic_function_name) LPAREN call_parameters? RPAREN
 	->	^(T_FUNCTION_NAME function_name? analytic_function_name? database_function_name? LPAREN call_parameters? RPAREN )
	;

call_parameters
	: ASTERISK
	| call_parameter ( COMMA call_parameter )*
	;
call_parameter //options { backtrack=false; }
	:	 nested_expression
	-> ^(T_CALL_PARAMETER nested_expression)
	;
parameter_name
	:	identifier
	;
case_expression
	:	K_CASE ( simple_case_expression | searched_case_expression ) ( else_case_expression )? K_END
	;
simple_case_expression
	:	nested_expression ( K_WHEN nested_expression K_THEN nested_expression )+
	;
searched_case_expression
	:	( K_WHEN sql_condition K_THEN nested_expression )+
	;
else_case_expression
	:	K_ELSE nested_expression
	;

simple_expression
	:	boolean_literal
	|	K_SQL 
	|	( cell_assignment ) => cell_assignment // this is used only in model_clause s[PROD= K_A ] = S[ 'a' ] + 1
	|	( column_spec ) => column_spec
	|	quoted_string
	|	NUMBER
	;        
/*
query_block
	:	K_SELECT / *( hint )?* / ( K_DISTINCT | K_DISTINCTROW | K_UNIQUE | K_ALL )? select_list
		K_FROM table_reference_list
		( where_clause )?
		( hierarchical_query_clause )?
		( group_by_clause )?
		( K_HAVING sql_condition )?
		( model_clause )?
	;
*/

subquery
	:	LPAREN select_statement RPAREN
	|	LPAREN subquery RPAREN
	;

datetime_expression
	:
        ( function_expression | cast_expression | simple_expression )
        K_AT (K_LOCAL | K_TIME K_ZONE ( quoted_string | K_DBTIMEZONE | K_SESSIONTIMEZONE | sql_expression ));

interval_expression
	:	K_INTERVAL NUMBER interval_expr_num_unit
		-> K_INTERVAL T_TRANSFORM["'"] NUMBER interval_expr_num_unit T_TRANSFORM["'"]
	;
	
interval_expr_num_unit
	:	'MICROSECOND'
	|	'SECOND'
	|	'MINUTE'
	|	'HOUR'
	|	'DAY'
	|	'WEEK'
	|	'MONTH'
	|	'QUARTER'
	|	'YEAR'
	;
	
/* ================================================================================
   Special expressions
   ================================================================================ */
special_expression
	:	cluster_set_clause
	;        
cluster_set_clause
	: K_CLUSTER_SET LPAREN column_spec (COMMA column_spec)? (COMMA NUMBER)? K_USING (column_specs|ASTERISK) RPAREN
	;

cast_expression
	:	K_CAST LPAREN (sql_expression | K_MULTISET subquery) K_AS (datatype|sql_identifier) RPAREN
	;	
datatype
	:	K_BINARY_INTEGER 
	|	K_BINARY_FLOAT
	|	K_BINARY_DOUBLE
	|	K_NATURAL
	|	K_POSITIVE
	|	( K_NUMBER | K_NUMERIC | K_DECIMAL | K_DEC ) ( LPAREN NUMBER ( COMMA NUMBER )? RPAREN )?
	|	K_LONG ( K_RAW)? ( LPAREN NUMBER RPAREN )?
	|	K_RAW ( LPAREN NUMBER RPAREN )?
	|	K_BOOLEAN
	|	K_DATE
	|   K_DATETIME
	|	K_INTERVAL K_DAY ( LPAREN NUMBER RPAREN )? K_TO K_SECOND ( LPAREN NUMBER RPAREN )?
	|	K_INTERVAL K_YEAR ( LPAREN NUMBER RPAREN )? K_TO K_MONTH
	|	( K_TIME | K_TIMESTAMP ) ( LPAREN NUMBER RPAREN )? ( K_WITH ( K_LOCAL )? K_TIME K_ZONE )?
	|	r_int
	|	r_tinyint
	|	r_smallint
	|   bigint
	|	K_FLOAT ( LPAREN NUMBER RPAREN )? r_unsigned?
	|	K_REAL r_unsigned?
	|	K_DOUBLE K_PRECISION? r_unsigned?
	|	r_enum
	|   K_TEXT
	|	K_TINYTEXT
	|	K_MEDIUMTEXT
	|	K_LONGTEXT
	|	K_CHAR      ( K_VARYING )? ( LPAREN NUMBER ( K_BYTE | K_CHAR )? RPAREN )?
	|	K_VARCHAR                  ( LPAREN NUMBER ( K_BYTE | K_CHAR )? RPAREN )?
	|	K_VARCHAR2                 ( LPAREN NUMBER ( K_BYTE | K_CHAR )? RPAREN )?
	|	K_CHARACTER ( K_VARYING )? ( LPAREN NUMBER RPAREN )?
	|	K_NCHAR     ( K_VARYING )? ( LPAREN NUMBER RPAREN )?
	|	K_NVARCHAR  ( LPAREN NUMBER RPAREN )?
	|	K_NVARCHAR2 ( LPAREN NUMBER RPAREN )?
	|	K_NATIONAL  ( K_CHARACTER | K_CHAR ) ( K_VARYING )? ( LPAREN NUMBER RPAREN )?
	|	K_MLSLABEL
	|	K_PLS_INTEGER
	|	K_TINYBLOB
	|	K_MEDIUMBLOB
	|	K_LONGBLOB
	|	K_BLOB
	|	K_CLOB
	|	K_NCLOB
	|	K_BFILE
	|	K_ROWID 
	|	K_UROWID ( LPAREN NUMBER RPAREN )?
	|	STUPID_MYSQL_DATE
	|	STUPID_MYSQL_TIMESTAMP
	;

r_enum
	: ( K_ENUM | K_SET ) LPAREN QUOTED_STRING ( ',' QUOTED_STRING )* RPAREN
	-> ^(T_CREATE_TABLE_ENUM
	K_ENUM? K_SET? LPAREN QUOTED_STRING ( ',' QUOTED_STRING )* RPAREN
	);

r_int
	: ( K_INT | K_INTEGER | K_MEDIUMINT ) ( LPAREN NUMBER RPAREN )? r_unsigned?
	-> K_INT? K_INTEGER? K_MEDIUMINT?
	;

r_tinyint
	: K_TINYINT ( LPAREN NUMBER RPAREN )? r_unsigned?
	-> K_TINYINT
	;

r_smallint
	: K_SMALLINT ( LPAREN NUMBER RPAREN )? r_unsigned?
	-> K_SMALLINT
	;

bigint
	: K_BIGINT ( LPAREN NUMBER RPAREN )? r_unsigned?
	-> K_BIGINT
	;

r_unsigned
	: K_UNSIGNED ->
	;

boolean_literal
	:	K_TRUE | K_FALSE
	;

c_alias
	: K_AS sql_identifier
	| K_AS
	| t_alias
	;

t_alias
	: //sql_identifier
	/* have to be more restrictive because this is matching 'limit' */
	ID | BACKQUOTED_STRING | QUOTED_STRING
	;

alias
	:	K_AS sql_identifier?
	;

column_spec
	: sql_identifier DOT sql_identifier DOT sql_identifier
	| sql_identifier DOT sql_identifier
	| sql_identifier
	| pseudo_column
	;
//TODO more pseudocolumns here - especially those who are reserved words
pseudo_column
	: K_NULL
    | K_SYSDATE
	| K_ROWID
	| K_ROWNUM
	| K_LEVEL				// hierarchical query
	| K_CONNECT_BY_ISLEAF
	| K_CONNECT_BY_ISCYCLE
	| K_VERSIONS_STARTTIME	// flashback query
	| K_VERSIONS_STARSCN
	| K_VERSIONS_ENDTIME
	| K_VERSIONS_ENDSCN 
	| K_VERSIONS_XID 
	| K_VERSIONS_OPERATION
	| K_COLUMN_VALUE	// XMLTABLE query
	| K_OBJECT_ID		// 
	| K_OBJECT_VALUE	//
	| K_ORA_ROWSCN		//
	| K_XMLDATA
	;

function_name
	: sql_identifier DOT sql_identifier DOT sql_identifier
	| sql_identifier DOT sql_identifier
	| sql_identifier
	;

database_function_name
	: K_DATABASE
	-> K_DATABASE[" current_schema "]
	;

identifier
	:	ID
	|	DOUBLEQUOTED_STRING 
	|   BACKQUOTED_STRING
   	;

sql_identifier
	:	identifier
	|   QUOTED_STRING
    |	keyword
	|	K_ROWID
	|	K_ROWNUM
	;

/* ================================================================================
   Query tables specs (ie. everything between "FROM" ... "WHERE"
   ================================================================================ */
table_reference_list
	:	(
			(join_clause|(LPAREN join_clause RPAREN)|table_reference)
			(COMMA? (join_clause|(LPAREN join_clause RPAREN)|table_reference))*
		)
//	->('t_from' join_clause? LPAREN? join_clause? RPAREN? table_reference?
//                (COMMA (join_clause|(LPAREN join_clause RPAREN)|table_reference))*
//	)   
	;            
table_reference
	:	((K_ONLY LPAREN query_table_expression RPAREN)
	|	query_table_expression /*( pivot_clause | unpivot_clause )?*/) flashback_query_clause? c_alias?
	;
query_table_expression
	:	//query_name
		( schema_name DOT)? table_name ( partition_extension_clause | AT_SIGN sql_identifier/*TODO dblink*/)? sample_clause? (pivot_clause|unpivot_clause)?
	|	subquery subquery_restricrion_clause? (pivot_clause|unpivot_clause)?
	|	LPAREN subquery subquery_restricrion_clause? (pivot_clause|unpivot_clause)? RPAREN
//TODO add subquery_restricrion_clause into subquery
	|	table_collection_clause (pivot_clause|unpivot_clause)?
	;
flashback_query_clause
	:	( K_VERSIONS K_BETWEEN ( K_SCN |K_TIMESTAMP) (sql_expression| K_MIVALUE ) K_AND (sql_expression| K_MAXVALUE ))?
		K_AS K_OF ( K_SCN |K_TIMESTAMP) sql_expression
	;
sample_clause
	:	K_SAMPLE K_BLOCK ? LPAREN sample_percent RPAREN ( K_SEED LPAREN seed_value RPAREN)?
	;
partition_extension_clause
	:	K_PARTITION (( LPAREN partition RPAREN ) | ( K_FOR LPAREN partition_key_value (COMMA partition_key_value)* RPAREN))
    |	K_SUBPARTITION (( LPAREN partition RPAREN ) | ( K_FOR LPAREN subpartition_key_value (COMMA subpartition_key_value)* RPAREN))
	;
subquery_restricrion_clause
	:	K_WITH ((K_READ K_ONLY) | (K_CHECK K_OPTION ( K_CONSTRAINT constraint)?))
	;
table_collection_clause
	:	K_TABLE /*LPAREN*/ collection_expression /*RPAREN*/ 
    ;
table_list
	: table_name ( ',' table_name )*
	;
join_clause
	:	table_reference (inner_cross_join_clause|outer_join_clause)+
	;
inner_cross_join_clause
	:	K_INNER? K_JOIN table_reference c_alias? ((join_clause_on)|(K_USING LPAREN column_specs RPAREN))?
    |	(K_CROSS | K_NATURAL K_INNER?) (K_JOIN table_reference)
	;        
outer_join_clause
	:	( query_partition_clause )?
		(	outer_join_type K_JOIN
		|	K_NATURAL ( outer_join_type )? K_JOIN
		)
		table_reference ( query_partition_clause )? ( join_clause_on | K_USING LPAREN column_specs RPAREN )?
	;
join_clause_on
	: K_ON sql_condition
	where_clause?
	;
query_partition_clause
	:	K_PARTITION K_BY expression_list
	;
outer_join_type
 	:	( K_FULL | K_LEFT | K_RIGHT ) ( K_OUTER )?
	;        

sample_percent
	:	NUMBER
	;
seed_value
	:	NUMBER
	;
table_name
	:	sql_identifier
	;
schema_name
	:	sql_identifier
	;
column_specs
	:	column_spec ( COMMA column_spec )*
	;
partition
	:	identifier        
	;
partition_key_value
	: identifier | NUMBER
	;
subpartition_key_value
	: identifier | NUMBER
	;
constraint
	:	sql_identifier
	;
collection_expression
	: subquery | LPAREN (cast_expression|function_expression) RPAREN | LPAREN column_spec RPAREN
	;

/* ================================================================================
   where clause
   ================================================================================ */
where_clause
	:	K_WHERE sql_condition
        -> ^( T_WHERE K_WHERE sql_condition)
	;
/* ================================================================================
   hierarchical query clause
   ================================================================================ */
hierarchical_query_clause
	:	K_CONNECT K_BY ( K_NOCYCLE )? connect1=sql_condition ( K_START K_WITH start1=sql_condition )?
//	-> ^('t_hierarchical' K_CONNECT K_BY K_NOCYCLE? $connect1 K_START? K_WITH? $start1?)
	|	( K_START K_WITH start2=sql_condition ) K_CONNECT K_BY ( K_NOCYCLE )? connect2=sql_condition
//	-> ^('t_hierarchical' K_START K_WITH $start2 K_CONNECT K_BY K_NOCYCLE? $connect2)
	;

/* ================================================================================
   group by clause
   ================================================================================ */
group_by_clause
	:	K_GROUP K_BY group_by_exprs
//	-> ^('t_group_by' K_GROUP K_BY group_by_exprs)
	;
group_by_exprs
	:	group_by_expr ( COMMA group_by_expr )*
	;
group_by_expr
	:	rollup_cube_clause
	|	grouping_sets_clause
	|	grouping_expression_list
	;
rollup_cube_clause
	:	( K_ROLLUP | K_CUBE ) LPAREN grouping_expression_list RPAREN
	;
grouping_sets_clause
	:	K_GROUPING K_SETS LPAREN grouping_expression_list RPAREN
	;
grouping_sets_exprs
	:	grouping_sets_expr ( COMMA grouping_sets_expr )*
	;
grouping_sets_expr
	:	rollup_cube_clause | grouping_expression_list
	;
sql_condition
	:	condition_or
	;
condition_or
	:	condition_and ( K_OR condition_and )*
	;
// condition_or_part_first
// 	:	condition_and
//     ;
// condition_or_part_next
// 	:	k_or condition_and //-> ^(T_COND_OR k_or condition_and)
//     ;
condition_and
	:	condition_not ( K_AND condition_not )*
	;
// condition_and_part_first
// 	:	condition_not
//     ;
// condition_and_part_next
// 	:	K_AND condition_not //-> ^(T_COND_AND K_AND condition_not)
//     ;
condition_not
	:	(K_NOT condition_expr /*-> ^(T_COND_NOT K_NOT condition_expr)*/ )
	|	condition_expr
	;
condition_expr
	:	condition_exists
	|	condition_is
	|	condition_comparison
	|	condition_group_comparison
	|	condition_in
	|	condition_is_a_set
	|	condition_is_any
	|	condition_is_empty
	|	condition_is_of_type
	|	condition_is_present
	|	condition_like
	|	condition_memeber
	|	condition_between
	|	condition_regexp_like
	|	condition_submultiset
	|	condition_equals_path
	|	condition_under_path
	|	condition_paren
	|	sql_expression
	;

condition_exists
	:	K_EXISTS subquery
	;
condition_is
	:	sql_expression K_IS ( K_NOT )? ( K_NAN | K_INFINITE | K_NULL )
	;
condition_comparison
	:	LPAREN sql_expressions RPAREN ( EQ | NOT_EQ ) subquery 
	|	( K_PRIOR )? sql_expression ( EQ | NOT_EQ | GTH | GEQ | LTH | LEQ ) ( K_PRIOR )? ( sql_expression | LPAREN select_statement RPAREN )
	;
condition_group_comparison
	:	LPAREN sql_expressions RPAREN ( EQ | NOT_EQ ) ( K_ANY | K_SOME | K_ALL ) LPAREN ( grouping_expression_list | select_statement ) RPAREN
	|	sql_expression ( EQ | NOT_EQ | GTH | GEQ | LTH | LEQ ) ( K_ANY | K_SOME | K_ALL ) LPAREN ( sql_expressions | select_statement ) RPAREN
	;
condition_in
	:	LPAREN sql_expressions RPAREN ( K_NOT )? K_IN LPAREN ( grouping_expression_list | select_statement ) RPAREN
	|	sql_expression ( K_NOT )? K_IN LPAREN ( expression_list | select_statement ) RPAREN
	;
condition_is_a_set
	:	nested_table_column_name K_IS ( K_NOT )? K_A K_SET
	;
condition_is_any
	:	( column_name K_IS )? K_ANY
	;
condition_is_empty
	:	nested_table_column_name K_IS ( K_NOT )? K_EMPTY
	;
condition_is_of_type
	:	sql_expression K_IS (K_NOT)? K_OF ( K_TYPE )? LPAREN type_name RPAREN
	;
condition_is_of_type_names
	:	condition_is_of_type_name ( COMMA condition_is_of_type_name )*
	;
condition_is_of_type_name
	:	( K_ONLY )? type_name
	;
condition_is_present
	:	cell_reference K_IS K_PRESENT
	;
condition_like
	:	sql_expression ( K_NOT )? ( K_LIKE | K_LIKEC | K_LIKE2 | K_LIKE4 ) sql_expression ( K_ESCAPE sql_expression )?
	;
condition_memeber
	:	sql_expression ( K_NOT )? K_MEMBER ( K_OF )? nested_table_column_name
	;
condition_between
	:	sql_expression ( K_NOT )? K_BETWEEN sql_expression K_AND sql_expression
	;
condition_regexp_like
	:	K_REGEXP_LIKE LPAREN call_parameters RPAREN
	;
condition_submultiset
	:	nested_table_column_name ( K_NOT )? K_SUBMULTISET ( K_OF )? nested_table_column_name
	;
condition_equals_path
	:	K_EQUALS_PATH LPAREN column_name COMMA path_string ( COMMA correlation_integer )? RPAREN
	;
condition_under_path
	:	K_UNDER_PATH LPAREN column_name ( COMMA levels )? COMMA path_string ( COMMA correlation_integer )? RPAREN
	;
levels
	:	integer
	;
correlation_integer
	:	integer
	;
path_string
	:	quoted_string
	;
type_name
	:	identifier ( DOT identifier )*
	;
integer
	:	NUMBER
	;
column_name
	:	sql_identifier
	;
nested_table
	:	sql_identifier
	;
nested_table_column_name
	:	( schema_name DOT )? (table_name DOT)? (nested_table DOT)? column_name
	;
sql_expressions
	:	sql_expression ( COMMA sql_expression )*
	;
grouping_expression_list
	:	expression_list ( COMMA expression_list )*
	;
expression_list
	:	LPAREN sql_expressions RPAREN
	|	sql_expressions
	;
cell_reference
	:	sql_identifier
	;

condition_paren
	:	LPAREN sql_condition RPAREN
	;

/* ================================================================================
   MODEL clause
   ================================================================================ */
model_clause
	:	K_MODEL main_model
        ( cell_reference_options )?
		( return_rows_clause )?
		( reference_model )* //main_model
//	-> ^( 't_model' K_MODEL main_model cell_reference_options? return_rows_clause? reference_model* )
	;
cell_reference_options
	:	( ( K_IGNORE | K_KEEP ) K_NAV )?
		( K_UNIQUE ( K_DIMENSION | K_SINGLE K_REFERENCE ) )?
	;
return_rows_clause
	:	K_RETURN ( K_UPDATED | K_ALL ) K_ROWS
	;
reference_model
	:	K_REFERENCE reference_model_name K_ON LPAREN subquery RPAREN
		model_column_clauses ( cell_reference_options )
	;
reference_model_name
	:	identifier
	;
main_model
	:	( K_MAIN main_model_name )? model_column_clauses
		( cell_reference_options ) model_rules_clause
	;
main_model_name
	:	identifier
	;
model_column_clauses
	:	( query_partition_clause ( column_spec )? )?
		K_DIMENSION K_BY LPAREN model_columns RPAREN
		K_MEASURES LPAREN model_columns RPAREN
	;
model_columns
	:	model_column ( COMMA model_column )*
	;
model_column
	:	sql_expression ( ( K_AS )? column_spec )?
	;
model_rules_clause
	:	( K_RULES ( K_UPDATE | K_UPSERT ( K_ALL )? )? ( ( K_AUTOMATIC | K_SEQUENTIAL ) K_ORDER )? )?
		( K_ITERATE LPAREN NUMBER RPAREN ( K_UNTIL LPAREN sql_condition RPAREN )? )?
		LPAREN model_rules_exprs RPAREN
	;
model_rules_exprs
	:	model_rules_expr ( COMMA model_rules_expr )*
	;
model_rules_expr
	:	( K_UPDATE | K_UPSERT ( K_ALL )? )? cell_assignment ( order_by_clause )? EQ sql_expression
	;
cell_assignment
	:	measure_column LBRACK ( multi_column_for_loop | cell_assignment_exprs ) RBRACK
	;
cell_assignment_exprs
	:	cell_assignment_expr ( COMMA cell_assignment_expr )*
	;
cell_assignment_expr
	:	sql_condition | sql_expression | single_column_for_loop
	;
measure_column
	:	column_name
	;
single_column_for_loop
	:	K_FOR column_name
		(	K_IN LPAREN ( literals | subquery ) RPAREN
		|	( K_LIKE pattern )? K_FROM literal K_TO literal ( K_INCREMENT | K_DECREMENT ) literal
		)
	;
pattern
	:	quoted_string
	;
literal
	:	( PLUS | MINUS )? NUMBER
	|	quoted_string
	;
literals
	:	literal ( COMMA literal )*
	;
multi_column_for_loop
	:	K_FOR LPAREN column_specs RPAREN K_IN LPAREN ( bracket_literals_list | subquery ) RPAREN
	;
bracket_literals
	:	LPAREN literals RPAREN
	;
bracket_literals_list
	:	bracket_literals ( COMMA bracket_literals )*
	;

/* ================================================================================
   UNION clause
   ================================================================================ */
union_clause
    :
	(	K_UNION ( K_ALL )?
 	|	K_INTERSECT
 	|	K_MINUS
 	)
 	(	select_statement |	subquery )
//	-> ^('t_union' K_UNION? K_ALL? K_INTERSECT? K_MINUS? select_statement? subquery?)
	;
	
/* ================================================================================
   ORDER BY clause
   ================================================================================ */
order_by_clause
//TODO use search_clause here
	:	K_ORDER K_SIBLINGS ? K_BY order_by_clause_part_first order_by_clause_part_next*
//	-> ^('t_order_by' K_ORDER K_SIBLINGS ? K_BY order_by_clause_part_first order_by_clause_part_next*)
	;
// NOTE: these two here here only to preserve COMMAs in parse tree
order_by_clause_part_first
	:	sql_expression K_ASC ? K_DESC ? (K_NULLS K_FIRST)? (K_NULLS K_LAST)?
	;        
order_by_clause_part_next
	:	COMMA sql_expression K_ASC ? K_DESC ? (K_NULLS K_FIRST)? (K_NULLS K_LAST)?
	;

/* ================================================================================
   Limit clause
   ================================================================================ */
limit_clause
	: // [LIMIT {[offset,] row_count | row_count OFFSET offset}]
	( limit_num_num_clause | K_LIMIT NUMBER K_OFFSET NUMBER )
	-> ^( T_LIMIT limit_num_num_clause? K_LIMIT NUMBER K_OFFSET NUMBER? )
	;
	
// not supported as-is
limit_num_num_clause
	:
	K_LIMIT limit_num_num_offset? NUMBER
	-> K_LIMIT NUMBER limit_num_num_offset?
	;

limit_num_num_offset
	: NUMBER COMMA
	-> T_TRANSFORM[" OFFSET "] NUMBER
	;

/* ================================================================================
   Analytic query part
   ================================================================================ */
analytic_function_name
	:
	| K_AVG	| K_CORR	| K_COVAR_POP	| K_COVAR_SAMP	| K_COUNT	| K_CUME_DIST	| K_DENSE_RANK
	| K_FIRST	| K_FIRST_VALUE	| K_LAG	| K_LAST	| K_LAST_VALUE	| K_LEAD	| K_MAX	| K_MIN
	| K_NTILE	| K_PERCENT_RANK	| K_PERCENTILE_CONT	| K_PERCENTILE_DISC	| K_RANK	| K_RATIO_TO_REPORT
	| K_REGR_SLOPE	| K_REGR_INTERCEPT	| K_REGR_COUNT	| K_REGR_R2	| K_REGR_AVGX	| K_REGR_AVGY
	| K_REGR_SXX	| K_REGR_SYY	| K_REGR_SXY	| K_ROW_NUMBER	| K_STDDEV	| K_STDDEV_POP
	| K_STDDEV_SAMP	| K_SUM	| K_VAR_POP	| K_VAR_SAMP	| K_VARIANCE 	;

analytic_function_call
	: analytic_function_name 
	LPAREN ( K_DISTINCT | K_DISTINCTROW | K_ALL)? sql_expression? (COMMA sql_expression)* ( ( K_RESPECT | K_IGNORE) K_NULLS )? RPAREN
	;
	
analytic_function
	: analytic_function_call ( ( K_RESPECT | K_IGNORE) K_NULLS )?  K_OVER LPAREN analytic_clause RPAREN
	;
	
analytic_clause
	: query_partition_clause? (order_by_clause windowing_clause?)?
	;

windowing_clause_part
	: ( K_UNBOUNDED ( K_PRECEDING | K_FOLLOWING ))
    | ( K_CURRENT K_ROW )
    | ( sql_expression ( K_PRECEDING | K_FOLLOWING ) )
	;
			
windowing_clause
	: (K_ROWS | K_RANGE )
	  ( windowing_clause_part | ( K_BETWEEN windowing_clause_part K_AND windowing_clause_part) )
	;

/* ================================================================================
    FOR UPDATE CLAUSE
   ================================================================================ */
for_update_clause
	: K_FOR K_UPDATE ( K_OF for_update_clause_part_first for_update_clause_part_next* )? (K_NOWAIT | K_WAIT NUMBER | K_SKIP K_LOCKED)?
//	-> ^('t_for_update' K_FOR K_UPDATE K_OF? for_update_clause_part_first? for_update_clause_part_next* K_NOWAIT? K_WAIT? NUMBER? K_SKIP? K_LOCKED?)
	;
for_update_clause_part_first
	: (sch1=schema_name dot1a=DOT)? (tbl1=table_name dot1b=DOT)? col1=column_name
	;
for_update_clause_part_next
	: COMMA (sch1=schema_name dot1a=DOT)? (tbl1=table_name dot1b=DOT)? col1=column_name
	;
	
/* ================================================================================
    LOCK IN SHARE MODE
   ================================================================================ */
lock_in_share_mode
	: K_LOCK K_IN K_SHARE K_MODE
	;
	
/* ================================================================================
    PROCEDURE
   ================================================================================ */
procedure_clause
	: K_PROCEDURE sql_identifier LPAREN ( ( column_name | NUMBER | quoted_string )? ( ',' ( column_name | NUMBER | quoted_string ) )* ) RPAREN
	;
	
/* ================================================================================
    Mysql's into file craziness
    [INTO OUTFILE 'file_name'
        [CHARACTER SET charset_name]
        export_options
      | INTO DUMPFILE 'file_name'
      | INTO var_name [, var_name]]
      
SELECT a,b,a+b INTO OUTFILE '/tmp/result.txt'
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
  FROM test_table;
   ================================================================================ */
into_file_clause
	: K_INTO ( 'OUTFILE' quoted_string ( K_CHARACTER K_SET quoted_string )?
	'FIELDS' 'TERMINATED' 'BY' quoted_string 'OPTIONALLY' 'ENCLOSED' 'BY' quoted_string
	'LINES' 'TERMINATED' 'BY' quoted_string )?
	| 'DUMPFILE' quoted_string
	| quoted_string ( ',' quoted_string )?
	;
	
/* ================================================================================
    PIVOT CLAUSE
   ================================================================================ */
pivot_clause
	:	K_PIVOT K_XML? LPAREN function_expression c_alias? (COMMA function_expression c_alias?)*
		pivot_for_clause pivot_in_clause RPAREN
	;
pivot_for_clause
	:	K_FOR column_spec | ( LPAREN column_specs RPAREN )
	;
pivot_in_clause
	:	K_IN
        LPAREN
        (
            select_statement
        |	K_ANY (COMMA K_ANY)*
        |	expression_list c_alias? (COMMA expression_list c_alias?) /*!!!*/
        )
        RPAREN
	;
unpivot_clause
	:	K_UNPIVOT (( K_EXCLUDE | K_INCLUDE ) K_NULLS)?
		LPAREN (column_spec | (LPAREN column_specs RPAREN)) pivot_for_clause unpivot_in_clause RPAREN
	;
unpivot_in_clause
	:	K_IN
		LPAREN
		(column_spec | (LPAREN column_specs RPAREN)) (K_AS (constant | (LPAREN constant RPAREN)))?
		(COMMA (column_spec | (LPAREN column_specs RPAREN)) (K_AS (constant | (LPAREN constant RPAREN)))?)*
		RPAREN
	;
constant
	: NUMBER | quoted_string
	;	// TODO fixme        

/* ================================================================================
   Oracle reserved words
   cannot by used for name database objects such as columns, tables, or indexes.
   ================================================================================ */
K_ACCESS : 'ACCESS'   ;
K_ADD : 'ADD'   ;
K_ALL : 'ALL'   ;
K_ALTER : 'ALTER'   ;
K_AND : 'AND'   ;
K_ANY : 'ANY'   ;
K_ARRAYLEN : 'ARRAYLEN'   ;
K_AS : 'AS'   ;
K_ASC : 'ASC'   ;
K_AUDIT : 'AUDIT'   ;
K_BETWEEN : 'BETWEEN'   ;
K_BY : 'BY'   ;
K_CASE : 'CASE'   ; //PL/SQL
K_CHAR : 'CHAR'   ;
K_CHECK : 'CHECK'   ;
K_CLUSTER : 'CLUSTER'   ;
K_COLUMN : 'COLUMN'   ;
K_COMMENT : 'COMMENT'   ;
K_COMPRESS : 'COMPRESS'   ;
K_CONNECT : 'CONNECT'   ;
K_CREATE : 'CREATE'   ;
K_CURRENT : 'CURRENT'   ;
K_DATE : 'DATE'  ;
K_DATETIME : 'DATETIME'	 { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TIMESTAMP ")); } ;
K_DECIMAL : 'DECIMAL'   ;
K_DEFAULT : 'DEFAULT'   ;
K_DELETE : 'DELETE'   ;
K_DESC : 'DESC'   ;
K_DISTINCT : 'DISTINCT'   ;
K_DISTINCTROW : 'DISTINCTROW' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "DISTINCT")); } ;
K_DROP : 'DROP'   ;
K_ELSE : 'ELSE'   ;
K_EXCLUSIVE : 'EXCLUSIVE'   ;
K_EXISTS : 'EXISTS'   ;
K_FALSE : 'FALSE'   ; //PL/SQL
K_FILE : 'FILE'   ;
K_FLOAT : 'FLOAT'   ;
K_FOR : 'FOR'   ;
K_FROM : 'FROM'   ;
K_GRANT : 'GRANT'   ;
K_GROUP : 'GROUP'   ;
K_HAVING : 'HAVING'   ;
K_IDENTIFIED : 'IDENTIFIED'   ;
K_IMMEDIATE : 'IMMEDIATE'   ;
K_IN : 'IN'   ;
K_INCREMENT : 'INCREMENT'   ;
K_INDEX : 'INDEX'   ;
K_INITIAL : 'INITIAL'   ;
K_INSERT : 'INSERT'   ;
K_INTEGER : 'INTEGER'   ;
K_INTERSECT : 'INTERSECT'   ;
K_INTO : 'INTO'   ;
K_IF : 'IF';
K_IS : 'IS'   ;
K_LEVEL : 'LEVEL'   ;
K_LIKE : 'LIKE'   ;
K_LIKE2 : 'LIKE2'   ;
K_LIKE4 : 'LIKE4'   ;
K_LIKEC : 'LIKEC'   ;
K_LOCK : 'LOCK'   ;
K_LONG : 'LONG'   ;
K_MAXEXTENTS : 'MAXEXTENTS'   ;
K_MINUS : 'MINUS'   ;
K_MODE : 'MODE'   ;
K_MODIFY : 'MODIFY'   ;
K_NOAUDIT : 'NOAUDIT'   ;
K_NOCOMPRESS : 'NOCOMPRESS'   ;
K_NOT : 'NOT'   ;
K_NOTFOUND : 'NOTFOUND'   ;
K_NOWAIT : 'NOWAIT'   ;
K_NULL : 'NULL'   ;
K_NUMBER : 'NUMBER'   ;
K_OF : 'OF'   ;
K_OFFLINE : 'OFFLINE'   ;
K_ON : 'ON'   ;
K_ONLINE : 'ONLINE'   ;
K_OPTION : 'OPTION'   ;
K_OR : 'OR'   ;
K_ORDER : 'ORDER'   ;
K_PCTFREE : 'PCTFREE'   ;
K_PRIOR : 'PRIOR'   ;
K_PRIVILEGES : 'PRIVILEGES'   ;
K_PUBLIC : 'PUBLIC'   ;
K_RAW : 'RAW'   ;
K_RENAME : 'RENAME'   ;
K_RESOURCE : 'RESOURCE'   ;
K_REVOKE : 'REVOKE'   ;
K_ROW : 'ROW'   ;
K_ROWID : 'ROWID'   ;
K_ROWLABEL : 'ROWLABEL'   ;
K_ROWNUM : 'ROWNUM'   ;
K_ROWS : 'ROWS'   ;
K_SELECT : 'SELECT' ; //{ LTOKEN->user1 = PGKEYWORD } ;
K_SESSION : 'SESSION'   ;
K_SET : 'SET'   ;
K_SHARE : 'SHARE'   ;
K_SIZE : 'SIZE'   ;
K_SMALLINT : 'SMALLINT'   ;
K_SQLBUF : 'SQLBUF'   ;
K_START : 'START'   ;
K_SUCCESSFUL : 'SUCCESSFUL'   ;
K_SYNONYM : 'SYNONYM'   ;
K_SYSDATE : 'SYSDATE'   ;
K_TABLE : 'TABLE'   ;
K_THEN : 'THEN'   ;
K_TO : 'TO'   ;
K_TINYINT : 'TINYINT' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "SMALLINT")); } ;
K_MEDIUMINT : 'MEDIUMINT' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "INTEGER")); } ;
K_TRIGGER  : 'TRIGGER'   ;
K_TRUE  : 'TRUE'   ; // PL/SQL
K_UID : 'UID'   ;
K_UNION : 'UNION'   ;
K_UNIQUE : 'UNIQUE'   ;
K_UPDATE : 'UPDATE'   ;
K_USER  : 'USER'   ;
K_VALIDATE : 'VALIDATE'   ;
K_VALUES : 'VALUES'   ;
K_VARCHAR : 'VARCHAR'   ;
K_VARCHAR2 : 'VARCHAR2'   ;
K_VIEW : 'VIEW'   ;
K_WHENEVER : 'WHENEVER'   ;
K_WHERE : 'WHERE'   ;
K_WITH : 'WITH'   ;

K_TEXT : 'TEXT'	;
K_TINYTEXT : 'TINYTEXT' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); } ;
K_MEDIUMTEXT : 'MEDIUMTEXT' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); } ;
K_LONGTEXT : 'LONGTEXT' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); } ;
K_ENUM : 'ENUM' ;

K_SHOW : 'SHOW' ;

reserved_word options { backtrack=false; }
	: r=( 'ACCESS'	| 'ADD'	| 'ALL'	| 'ALTER'	| 'AND'	| 'ANY'	| 'ARRAYLEN'	| 'AS'	| 'ASC'	| 'AUDIT'
	| 'BETWEEN'	| 'BY'
	| 'CASE'
	| 'CHAR'	| 'CHECK'	| 'CLUSTER'	| 'COLUMN'	| 'COMMENT'	| 'COMPRESS'	| 'CONNECT'	| 'CREATE'	| 'CURRENT'	
	| 'DATE'	| 'DECIMAL'	| 'DEFAULT'	| 'DELETE'	| 'DESC'	| 'DISTINCT'	| 'DISTINCTROW'	| 'DROP'	
	| 'ELSE'	| 'EXCLUSIVE'	| 'EXISTS'	
	| 'FILE'	| 'FLOAT'	| 'FOR'	| 'FROM'	
	| 'GRANT'	| 'GROUP'	
	| 'HAVING'	
	| 'IDENTIFIED'	| 'IMMEDIATE'	| 'IN' | 'IF'	| 'INCREMENT'	| 'INDEX'	| 'INITIAL'	| 'INSERT'	| 'INTEGER'	
	| 'INTERSECT'	| 'INTO'	| 'IS'	
	| 'LEVEL'	| 'LIKE'	| 'LOCK'	| 'LONG'	
	| 'MAXEXTENTS'	| 'MINUS'	| 'MODE'	| 'MODIFY'	
	| 'NOAUDIT'	| 'NOCOMPRESS'	| 'NOT'	| 'NOTFOUND'	| 'NOWAIT'	| 'NULL'	| 'NUMBER'	
	| 'OF'	| 'OFFLINE'	| 'ON'	| 'ONLINE'	| 'OPTION'	| 'OR'	| 'ORDER'	
	| 'PCTFREE'	| 'PRIOR'	| 'PRIVILEGES'	| 'PUBLIC'	
	| 'RAW'	| 'RENAME'	| 'RESOURCE'	| 'REVOKE'	| 'ROW'	| 'ROWID'	| 'ROWLABEL'	| 'ROWNUM'	| 'ROWS'	
	| 'SELECT'	| 'SESSION'	| 'SET'	| 'SHARE'	| 'SIZE'	| 'SMALLINT'	| 'SQLBUF'	
	| 'START'	| 'SUCCESSFUL'	| 'SYNONYM'	| 'SYSDATE'	
	| 'TABLE'	| 'THEN'	| 'TO'	| 'TRIGGER'	| 'TINYINT'
	| 'UID'	| 'UNION'	| 'UNIQUE'	| 'UPDATE'
	| 'VALIDATE'	| 'VALUES'	| 'VARCHAR'	| 'VARCHAR2'	| 'VIEW'	
	| 'WHENEVER'	| 'WHERE'	| 'WITH'
	| 'TEXT' | 'MEDIUMTEXT' | 'SHOW'
	) //{ $r->setType($r, T_RESERVED); }
	  //{ $type = T_RESERVED; }
	// -> ^(T_RESERVED[$r])
	;

/* ================================================================================
   Oracle keywords
   can by used for name database objects such as columns, tables, or indexes.
   ================================================================================ */
K_A  : 'A'   ;
K_AT  : 'AT'   ;
K_ADMIN : 'ADMIN'   ;
K_AFTER : 'AFTER'   ;
K_ALLOCATE : 'ALLOCATE'   ;
K_ANALYZE : 'ANALYZE'   ;
K_ARCHIVE : 'ARCHIVE'   ;
K_ARCHIVELOG : 'ARCHIVELOG'   ;
K_AUTHORIZATION : 'AUTHORIZATION'   ;
K_AUTO_INCREMENT: 'AUTO_INCREMENT'	;
K_AVG	 : 'AVG'   ;
K_BACKUP : 'BACKUP'   ;
K_BECOME : 'BECOME'   ;
K_BEFORE : 'BEFORE'   ;
K_BEGIN : 'BEGIN'   ;
K_BIGINT : 'BIGINT'	;
K_BLOCK : 'BLOCK'   ;
K_BODY	 : 'BODY'   ;
K_CACHE : 'CACHE'   ;
K_CANCEL : 'CANCEL'   ;
K_CASCADE : 'CASCADE'   ;
K_CHANGE : 'CHANGE'   ;
K_CHARACTER : 'CHARACTER'   ;
K_CHARSET : 'CHARSET'   ;
K_CHECKPOINT : 'CHECKPOINT'   ;
K_CLOSE	 : 'CLOSE'   ;
K_COBOL : 'COBOL'   ;
K_COLLATE : 'COLLATE'	;
K_COMMIT : 'COMMIT'   ;
K_COMPILE : 'COMPILE'   ;
K_CONSTRAINT : 'CONSTRAINT'   ;
K_CONSTRAINTS : 'CONSTRAINTS'   ;
K_CONTENTS : 'CONTENTS'   ;
K_CONTINUE	 : 'CONTINUE'   ;
K_CONTROLFILE : 'CONTROLFILE'   ;
K_COLUMN_FORMAT : 'COLUMN_FORMAT'	;
K_COUNT : 'COUNT'   ;
K_CURSOR : 'CURSOR'   ;
K_CYCLE	 : 'CYCLE'   ;
K_DATABASE : 'DATABASE';
/*{
	if(PGIFY_IS_SCHEMA(LEXSTATE->userp)) {
		SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "SCHEMA"));
	}
}
 ;*/
K_DATAFILE : 'DATAFILE'   ;
K_DAY : 'DAY'   ;
K_DBA : 'DBA'   ;
K_DBTIMEZONE : 'DBTIMEZONE'   ;
K_DEC : 'DEC'   ;
K_DECLARE : 'DECLARE'   ;
K_DISABLE : 'DISABLE'   ;
K_DISMOUNT : 'DISMOUNT'   ;
K_DOUBLE : 'DOUBLE'   ;
K_DUMP	 : 'DUMP'   ;
K_DYNAMIC	: 'DYNAMIC'	;
K_EACH : 'EACH'   ;
K_ENABLE : 'ENABLE'   ;
K_END : 'END'   ;
K_ENGINE: 'ENGINE'	;
K_ESCAPE : 'ESCAPE'   ;
K_EVENTS : 'EVENTS'   ;
K_EXCEPT : 'EXCEPT'   ;
K_EXCEPTIONS : 'EXCEPTIONS'   ;
K_EXEC : 'EXEC'   ;
K_EXECUTE	 : 'EXECUTE'   ;
K_EXPLAIN : 'EXPLAIN'   ;
K_EXTENT : 'EXTENT'   ;
K_EXTERNALLY	 : 'EXTERNALLY'   ;
K_FETCH : 'FETCH'   ;
K_FIXED : 'FIXED'	;
K_FLUSH : 'FLUSH'   ;
K_FORCE : 'FORCE'   ;
K_FOREIGN : 'FOREIGN'   ;
K_FORTRAN : 'FORTRAN'   ;
K_FOUND : 'FOUND'   ;
K_FREELIST : 'FREELIST'   ;
K_FREELISTS : 'FREELISTS'   ;
K_FUNCTION	 : 'FUNCTION'   ;
K_GO : 'GO'   ;
K_GOTO : 'GOTO'   ;
K_GROUPS : 'GROUPS'   ;
K_INCLUDING : 'INCLUDING'   ;
K_INDICATOR : 'INDICATOR'   ;
K_INITRANS : 'INITRANS'   ;
K_INSTANCE : 'INSTANCE'   ;
K_INT	 : 'INT'   ;
K_KEY	 : 'KEY'   ;
K_LANGUAGE : 'LANGUAGE'   ;
K_LAYER : 'LAYER'   ;
K_LINK : 'LINK'   ;
K_LISTS : 'LISTS'   ;
K_LOGFILE	 : 'LOGFILE'   ;
K_LOCAL	 : 'LOCAL'   ;
K_LOCKED	 : 'LOCKED'   ;
K_MANAGE : 'MANAGE'   ;
K_MANUAL : 'MANUAL'   ;
K_MAX : 'MAX'   ;
K_MAXDATAFILES : 'MAXDATAFILES'   ;
K_MAXINSTANCES : 'MAXINSTANCES'   ;
K_MAXLOGFILES : 'MAXLOGFILES'   ;
K_MAXLOGHISTORY	 : 'MAXLOGHISTORY'   ;
K_MAXLOGMEMBERS : 'MAXLOGMEMBERS'   ;
K_MAXTRANS : 'MAXTRANS'   ;
K_MAXVALUE : 'MAXVALUE'   ;
K_MIN : 'MIN'   ;
K_MINEXTENTS : 'MINEXTENTS'   ;
K_MINVALUE : 'MINVALUE'   ;
K_MODULE : 'MODULE'   ;
K_MONTH	 : 'MONTH'   ;
K_MOUNT	 : 'MOUNT'   ;
K_NEW : 'NEW'   ;
K_NEXT : 'NEXT'   ;
K_NOARCHIVELOG : 'NOARCHIVELOG'   ;
K_NOCACHE : 'NOCACHE'   ;
K_NOCYCLE : 'NOCYCLE'   ;
K_NOMAXVALUE : 'NOMAXVALUE'   ;
K_NOMINVALUE : 'NOMINVALUE'   ;
K_NONE	 : 'NONE'   ;
K_NOORDER : 'NOORDER'   ;
K_NORESETLOGS : 'NORESETLOGS'   ;
K_NORMAL : 'NORMAL'   ;
K_NOSORT : 'NOSORT'   ;
K_NUMERIC	 : 'NUMERIC'   ;
K_OFF : 'OFF'   ;
K_OLD : 'OLD'   ;
K_ONLY : 'ONLY'   ;
K_OPEN : 'OPEN'   ;
K_OPTIMAL : 'OPTIMAL'   ;
K_OWN	 : 'OWN'   ;
K_PACKAGE : 'PACKAGE'   ;
K_PARALLEL : 'PARALLEL'   ;
K_PCTINCREASE : 'PCTINCREASE'   ;
K_PCTUSED : 'PCTUSED'   ;
K_PLAN : 'PLAN'   ;
K_PLI : 'PLI'   ;
K_PRECISION : 'PRECISION'   ;
K_PRIMARY : 'PRIMARY'   ;
K_PRIVATE : 'PRIVATE'   ;
K_PROCEDURE : 'PROCEDURE'   ;
K_PROFILE	 : 'PROFILE'   ;
K_QUOTA	 : 'QUOTA'   ;
K_READ : 'READ'   ;
K_REAL : 'REAL'   ;
K_RECOVER : 'RECOVER'   ;
K_REFERENCES : 'REFERENCES'   ;
K_REFERENCING : 'REFERENCING'   ;
K_RESETLOGS : 'RESETLOGS'   ;
K_RESTRICT : 'RESTRICT'		;
K_RESTRICTED : 'RESTRICTED'   ;
K_REUSE	 : 'REUSE'   ;
K_ROLE : 'ROLE'   ;
K_ROLES : 'ROLES'   ;
K_ROLLBACK	 : 'ROLLBACK'   ;
K_SAVEPOINT : 'SAVEPOINT'   ;
K_SCHEMA : 'SCHEMA'   ;
K_SCN : 'SCN'   ;
K_SECOND : 'SECOND'   ;
K_SECTION : 'SECTION'   ;
K_SEGMENT : 'SEGMENT'   ;
K_SEQUENCE : 'SEQUENCE'   ;
K_SESSIONTIMEZONE : 'SESSIONTIMEZONE'   ;
K_SHARED : 'SHARED'   ;
K_SNAPSHOT	 : 'SNAPSHOT'   ;
K_SKIP : 'SKIP'   ;
K_SOME : 'SOME'   ;
K_SORT : 'SORT'   ;
K_SQL : 'SQL'   ;
K_SQLCODE : 'SQLCODE'   ;
K_SQLERROR : 'SQLERROR'   ;
K_SQLSTATE : 'SQLSTATE'   ;
K_STATEMENT_ID : 'STATEMENT'   ;
K_STATISTICS : 'STATISTICS'   ;
K_STOP : 'STOP'   ;
K_STORAGE : 'STORAGE'   ;
K_SUM : 'SUM'   ;
K_SWITCH : 'SWITCH'   ;
K_SYSTEM	 : 'SYSTEM'   ;
K_TABLES : 'TABLES'   ;
K_TABLESPACE : 'TABLESPACE'   ;
K_TEMPORARY : 'TEMPORARY'   ;
K_THREAD : 'THREAD'   ;
K_TIME : 'TIME'   ;
K_TRACING : 'TRACING'   ;
K_TRANSACTION : 'TRANSACTION'   ;
K_TRIGGERS	 : 'TRIGGERS'   ;
K_TRUNCATE	 : 'TRUNCATE'   ;
K_UNDER : 'UNDER'   ;
K_UNLIMITED : 'UNLIMITED'   ;
K_UNTIL : 'UNTIL'   ;
K_USE : 'USE'   ;
K_USING	 : 'USING'   ;
K_WAIT : 'WAIT'   ;
K_WHEN : 'WHEN'   ;
K_WORK : 'WORK'   ;
K_WRITE	 : 'WRITE'   ;
K_YEAR	 : 'YEAR'   ;
K_ZONE	 : 'ZONE'   ;
K_AUTOMATIC : 'AUTOMATIC'   ;
K_BFILE : 'BFILE'   ;
K_BINARY_DOUBLE : 'BINARY_DOUBLE'   ;
K_BINARY_FLOAT : 'BINARY_FLOAT'   ;
K_BINARY_INTEGER : 'BINARY_INTEGER'   ;
K_BLOB : 'BLOB' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); };
K_LONGBLOB : 'LONGBLOB' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); };
K_MEDIUMBLOB : 'MEDIUMBLOB' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); };
K_TINYBLOB : 'TINYBLOB' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "TEXT")); };
K_BOOLEAN : 'BOOLEAN'   ;
K_BYTE : 'BYTE'   ;
K_CAST : 'CAST'   ;
K_CLOB : 'CLOB'   ;
K_CLUSTER_SET : 'CLUSTER_SET'   ;
K_COLUMN_VALUE : 'COLUMN_VALUE'   ;
K_CONNECT_BY_ISCYCLE : 'CONNECT_BY_ISCYCLE'   ;
K_CONNECT_BY_ISLEAF : 'CONNECT_BY_ISLEAF'   ;
K_CONNECT_BY_ROOT : 'CONNECT_BY_ROOT'   ;
K_CORR : 'CORR'   ;
K_COVAR_POP : 'COVAR_POP'   ;
K_COVAR_SAMP : 'COVAR_SAMP'   ;
K_CROSS : 'CROSS'   ;
K_CUBE : 'CUBE'   ;
K_CUME_DIST : 'CUME_DIST'   ;
K_DECREMENT : 'DECREMENT'   ;
K_DENSE_RANK : 'DENSE_RANK'   ;
K_DIMENSION : 'DIMENSION'   ;
K_EMPTY : 'EMPTY'   ;
K_EQUALS_PATH : 'EQUALS_PATH'   ;
K_FIRST_VALUE : 'FIRST_VALUE'   ;
K_FULL : 'FULL'   ;
K_GROUPING : 'GROUPING'   ;
K_IGNORE : 'IGNORE'   ;
K_INFINITE : 'INFINITE'   ;
K_INNER : 'INNER'   ;
K_INTERVAL : 'INTERVAL'   ;
K_ITERATE : 'ITERATE'   ;
K_JOIN : 'JOIN'   ;
K_KEEP : 'KEEP'   ;
K_LAG : 'LAG'   ;
K_LAST : 'LAST'   ;
K_LAST_VALUE : 'LAST_VALUE'   ;
K_LEAD : 'LEAD'   ;
K_LEFT : 'LEFT'   ;
K_MAIN : 'MAIN'   ;
K_MEASURES : 'MEASURES'   ;
K_MEMBER : 'MEMBER'   ;
K_MLSLABEL : 'MLSLABEL'   ;
K_MODEL : 'MODEL'   ;
K_MULTISET : 'MULTISET'   ;
K_NAN : 'NAN'   ;
K_NATIONAL : 'NATIONAL'   ;
K_NATURAL : 'NATURAL'   ;
K_NAV : 'NAV'   ;
K_NCHAR : 'NCHAR'   ;
K_NCLOB : 'NCLOB'   ;
K_NTILE : 'NTILE'   ;
K_NULLS : 'NULLS'   ;
K_NVARCHAR : 'NVARCHAR'   ;
K_NVARCHAR2 : 'NVARCHAR2'   ;
K_OBJECT_ID : 'OBJECT_ID'   ;
K_OBJECT_VALUE : 'OBJECT_VALUE'   ;
K_ORA_ROWSCN : 'ORA_ROWSCN'   ;
K_OUTER : 'OUTER'   ;
K_OVER : 'OVER'   ;
K_PARTITION : 'PARTITION'   ;
K_PERCENTILE_CONT : 'PERCENTILE_CONT'   ;
K_PERCENTILE_DISC : 'PERCENTILE_DISC'   ;
K_PERCENT_RANK : 'PERCENT_RANK'   ;
K_PIVOT : 'PIVOT'   ;
K_PLS_INTEGER : 'PLS_INTEGER'   ;
K_POSITIVE : 'POSITIVE'   ;
K_PRESENT : 'PRESENT'   ;
K_RANK : 'RANK'   ;
K_RATIO_TO_REPORT : 'RATIO_TO_REPORT'   ;
K_REFERENCE : 'REFERENCE'   ;
K_REGEXP_LIKE : 'REGEXP_LIKE'   ;
K_REGR_AVGX : 'REGR_AVGX'   ;
K_REGR_AVGY : 'REGR_AVGY'   ;
K_REGR_COUNT : 'REGR_COUNT'   ;
K_REGR_INTERCEPT : 'REGR_INTERCEPT'   ;
K_REGR_R2 : 'REGR_R2'   ;
K_REGR_SLOPE : 'REGR_SLOPE'   ;
K_REGR_SXX : 'REGR_SXX'   ;
K_REGR_SXY : 'REGR_SXY'   ;
K_REGR_SYY : 'REGR_SYY'   ;
K_RIGHT : 'RIGHT'   ;
K_ROLLUP : 'ROLLUP'   ;
K_ROW_NUMBER : 'ROW_NUMBER'   ;
K_RULES : 'RULES'   ;
K_SAMPLE : 'SAMPLE'   ;
K_SEARCH : 'SEARCH'   ;
K_SEQUENTIAL : 'SEQUENTIAL'   ;
K_SETS : 'SETS'   ;
K_SINGLE : 'SINGLE'   ;
K_STDDEV : 'STDDEV'   ;
K_STDDEV_POP : 'STDDEV_POP'   ;
K_STDDEV_SAMP : 'STDDEV_SAMP'   ;
K_SUBMULTISET : 'SUBMULTISET'   ;
K_SUBPARTITION : 'SUBPARTITION'   ;
K_THE : 'THE'   ;
K_TIMESTAMP : 'TIMESTAMP'   ;
K_TYPE : 'TYPE'   ;
K_UNBOUNDED : 'UNBOUNDED'   ;
K_UNDER_PATH : 'UNDER_PATH'   ;
K_UPDATED : 'UPDATED'   ;
K_UPSERT : 'UPSERT'   ;
K_UROWID : 'UROWID'   ;
K_VARIANCE : 'VARIANCE'   ;
K_VARYING : 'VARYING'   ;
K_VAR_POP : 'VAR_POP'   ;
K_VAR_SAMP : 'VAR_SAMP'   ;
K_VERSIONS_ENDSCN : 'VERSIONS_ENDSCN'   ;
K_VERSIONS_ENDTIME : 'VERSIONS_ENDTIME'   ;
K_VERSIONS_OPERATION : 'VERSIONS_OPERATION'   ;
K_VERSIONS_STARSCN : 'VERSIONS_STARSCN'   ;
K_VERSIONS_STARTTIME : 'VERSIONS_STARTTIME'   ;
K_VERSIONS_XID : 'VERSIONS_XID'   ;
K_XML : 'XML'   ;
K_XMLDATA : 'XMLDATA'   ;
K_ERRORS : 'ERRORS'   ;
K_FIRST : 'FIRST'   ;
K_LIMIT : 'LIMIT'   ;
K_OFFSET : 'OFFSET'   ;
K_LOG : 'LOG'   ;
K_REJECT : 'REJECT'   ;
K_RETURN : 'RETURN'   ;
K_RETURNING : 'RETURNING'   ;
K_MERGE : 'MERGE'   ;
K_MATCHED : 'MATCHED'   ;
K_FOLLOWING : 'FOLLOWING'   ;
K_RANGE : 'RANGE'   ;
K_SIBLINGS : 'SIBLINGS'   ;
K_UNPIVOT : 'UNPIVOT'   ;
K_UNSIGNED : 'UNSIGNED'	;
K_VALUE :  'VALUE'   ;
K_BREADTH : 'BREADTH'   ;
K_DEPTH : 'DEPTH'   ;
K_EXCLUDE : 'EXCLUDE'   ;
K_INCLUDE : 'INCLUDE'   ;
K_MIVALUE : 'MIVALUE'   ;
K_PRECEDING : 'PRECEDING'   ;
K_RESPECT : 'RESPECT'   ;
K_SEED : 'SEED'   ;
K_VERSIONS : 'VERSIONS'   ;
K_HIGH_PRIORITY : 'HIGH_PRIORITY'   ;
K_STRAIGHT_JOIN : 'STRAIGHT_JOIN'   ;
K_SQL_SMALL_RESULT : 'SQL_SMALL_RESULT'   ;
K_SQL_BIG_RESULT : 'SQL_BIG_RESULT'   ;
K_SQL_BUFFER_RESULT : 'SQL_BUFFER_RESULT'   ;
K_SQL_CACHE : 'SQL_CACHE'   ;
K_SQL_NO_CACHE : 'SQL_NO_CACHE'   ;
K_SQL_CALC_FOUND_ROWS : 'SQL_CALC_FOUND_ROWS'   ;

K_INNODB : 'INNODB'   ;
K_MYISAM : 'MYISAM'   ;
K_LOW_PRIORITY : 'LOW_PRIORITY'	;
K_FULLTEXT : 'FULLTEXT'	;

K_CURRENT_TIMESTAMP : 'CURRENT_TIMESTAMP' { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "NOW ( )")); };

STUPID_MYSQL_DATE : '\'0000-00-00\''  { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "NULL")); };
STUPID_MYSQL_TIMESTAMP : '\'0000-00-00 00:00:00\''  { SETTEXT(GETTEXT()->factory->newStr8(GETTEXT()->factory, (pANTLR3_UINT8) "NULL")); };

K_CONCAT: 'CONCAT' ;
K_CONCAT_WS: 'CONCAT_WS' ;
K_NULLIF: 'NULLIF'	;
K_IFNULL: 'IFNULL'	;
K_FOUND_ROWS: 'FOUND_ROWS'	;

keyword
	: 'A' // note: this one is not listed in the docs but is a part of "IS A SET" condition clause
	| 'ADMIN'	| 'AFTER'	| 'ALLOCATE'	| 'ANALYZE'	| 'ARCHIVE'	| 'ARCHIVELOG'	| 'AT'	| 'AUTHORIZATION'	| 'AUTO_INCREMENT'	| 'AVG'	
	| 'BACKUP'	| 'BECOME'	| 'BEFORE'	| 'BEGIN'	|	'BIGINT'	|	'BLOCK'	| 'BODY'	| 'BREADTH'
	| 'CACHE'	| 'CANCEL'	| 'CASCADE'	| 'CHANGE'	| 'CHARACTER'	|	'CHARSET'	| 'CHECKPOINT'	| 'CLOSE'	
	| 'COBOL'	| 'COMMIT'	| 'COMPILE'	| 'CONSTRAINT'	| 'CONSTRAINTS'	| 'CONTENTS'	| 'CONTINUE'	
	| 'CONTROLFILE'	| 'COUNT'	|	'COLUMN_FORMAT'	| 'CURSOR'	| 'CYCLE'	
	| 'DATABASE'	| 'DATAFILE'	| 'DAY'	| 'DBA'	| 'DBTIMEZONE'	| 'DEC'	| 'DECLARE'	| 'DISABLE'	| 'DISMOUNT'	| 'DOUBLE'	| 'DUMP'
    | 'DEPTH'	|	'DYNAMIC'
	| 'EACH'	| 'ENABLE'	| 'END'	| 'ENGINE'	| 'ESCAPE'	| 'EVENTS'	| 'ERRORS'	| 'EXCEPT'	| 'EXCEPTIONS'	| 'EXEC'	| 'EXECUTE'
    | 'EXCLUDE'
	| 'EXPLAIN'	| 'EXTENT'	| 'EXTERNALLY'	
	| 'FETCH'	| 'FIRST'	|	'FIXED'	| 'FLUSH'	| 'FORCE'	| 'FOREIGN'	| 'FORTRAN'	| 'FOUND'
	| 'FOLLOWING'    | 'FREELIST'
	| 'FREELISTS'	| 'FUNCTION'	
	| 'GO'	| 'GOTO'	| 'GROUPS'
	| 'INCLUDE'	| 'INCLUDING'	| 'INDICATOR'	| 'INITRANS'	| 'INSTANCE'	| 'INT'	
	| 'KEY'	
	| 'LANGUAGE'	| 'LAYER'	| 'LIMIT'	| 'OFFSET'	| 'LINK'	| 'LISTS'	| 'LOCAL'	| 'LOCKED'	| 'LOG'	| 'LOGFILE'
	| 'MANAGE'	| 'MANUAL'	| 'MATCHED'	| 'MAX'	| 'MAXDATAFILES'	| 'MAXINSTANCES'	| 'MAXLOGFILES'	| 'MAXLOGHISTORY'	
	| 'MAXLOGMEMBERS'	| 'MAXTRANS'	| 'MAXVALUE'	| 'MERGE'	| 'MIN'	| 'MINEXTENTS'	| 'MINVALUE'	| 'MODULE'	| 'MONTH'	| 'MOUNT'
	| 'NEW'	| 'NEXT'	| 'NOARCHIVELOG'	| 'NOCACHE'	| 'NOCYCLE'	| 'NOMAXVALUE'	| 'NOMINVALUE'	| 'NONE' 
	| 'NOORDER'	| 'NORESETLOGS'	| 'NORMAL'	| 'NOSORT'	| 'NUMERIC'	
	| 'OFF'	| 'OLD'	| 'ONLY'	| 'OPEN'	| 'OPTIMAL'	| 'OWN'	
	| 'PACKAGE'	| 'PARALLEL'	| 'PCTINCREASE'	| 'PCTUSED'	| 'PLAN'	| 'PLI'	| 'PRECISION'	| 'PRIMARY'	
	| 'PRIVATE'	| 'PRECEDING'	| 'PROCEDURE'	| 'PROFILE'	
	| 'QUOTA'	
	| 'READ'	| 'REAL'	| 'RECOVER'	| 'REFERENCES'	| 'REFERENCING'	| 'REJECT'	| 'RETURN'	| 'RETURNING'
	| 'RESETLOGS'	| 'RESTRICT' | 'RESTRICTED'	| 'REUSE'	| 'ROLE'	| 'ROLES'	| 'ROLLBACK'
    | 'RESPECT'
	| 'SAVEPOINT'	| 'SECOND'	| 'SESSIONTIMEZONE'	| 'SCHEMA'	| 'SCN'	| 'SECTION'	| 'SEGMENT'	| 'SEQUENCE'
	| 'SHARED'	| 'SKIP'	| 'SNAPSHOT'	| 'SOME'	| 'SORT'	| 'SQL'	| 'SQLCODE'	| 'SQLERROR'	| 'SQLSTATE'
	| 'STATEMENT_ID'	| 'STATISTICS'	| 'STOP'	| 'STORAGE'	| 'SUM'	| 'SWITCH'	| 'SYSTEM'
    | 'SEED'
	| 'TABLES'	| 'TABLESPACE'	| 'TEMPORARY'	| 'THREAD'	| 'TIME'	| 'TRACING'	| 'TRANSACTION'	| 'TRIGGERS'	
	| 'TRUNCATE'	
	| 'UNDER'	| 'UNLIMITED'	| 'UNTIL'	| 'USE'
    //| 'USING'
    | 'VALUE'	| 'VERSIONS'
	| 'WHEN'	| 'WORK'	| 'WRITE'
   	| 'YEAR'
	| 'ZONE'
    | 'AUTOMATIC'	| 'BFILE'	| 'BINARY_DOUBLE'
    | 'BINARY_FLOAT'	| 'BINARY_INTEGER'	| 'BLOB'	| 'BOOLEAN'
    | 'BYTE'	| 'CAST'	| 'CLOB'	| 'CLUSTER_SET'
    | 'COLUMN_VALUE'
    | 'CONNECT_BY_ISCYCLE'	| 'CONNECT_BY_ISLEAF'	| 'CONNECT_BY_ROOT'
    | 'CORR'	| 'COVAR_POP'	| 'COVAR_SAMP'	| 'CROSS'
    | 'CUBE'	| 'CUME_DIST'	| 'DECREMENT'	| 'DENSE_RANK'
    | 'DIMENSION'	| 'EMPTY'	|    'EQUALS_PATH'	| 'FIRST_VALUE'
    | 'FULL'	| 'GROUPING'	| 'IGNORE'	| 'INFINITE'
    | 'INNER'
    | 'INTERVAL'	| 'ITERATE'
    //| 'JOIN'
    | 'KEEP'	| 'LAG'	| 'LAST'	| 'LAST_VALUE'
    | 'LEAD'	| 'LEFT'	| 'MAIN'	| 'MEASURES'
    | 'MEMBER'	| 'MLSLABEL'
    //| 'MODEL'
    //| 'MULTISET'
    | 'NAN'	| 'NATIONAL'	| 'NATURAL'	| 'NAV'
    | 'NCHAR'	| 'NCLOB'	| 'NTILE'	| 'NULLS'
    | 'NVARCHAR'	| 'NVARCHAR2'	| 'OBJECT_ID'	|    'OBJECT_VALUE'
    | 'ORA_ROWSCN'
    //| 'OUTER'
    | 'OVER'
    //| 'PARTITION'
    //| 'PERCENTILE_CONT'	| 'PERCENTILE_DISC'	| 'PERCENT_RANK'	|
    | 'PIVOT'
    | 'PLS_INTEGER'	| 'POSITIVE'	| 'PRESENT'
    | 'RANGE'    | 'RANK'
    | 'RATIO_TO_REPORT'	| 'REFERENCE'	| 'REGEXP_LIKE'	| 'REGR_AVGX'
    | 'REGR_AVGY'	| 'REGR_COUNT'	| 'REGR_INTERCEPT'	| 'REGR_R2'
    | 'REGR_SLOPE'	| 'REGR_SXX'	| 'REGR_SXY'	| 'REGR_SYY'
    | 'RIGHT'	| 'ROLLUP'	| 'ROW_NUMBER'	| 'RULES'
    | 'SAMPLE'	| 'SEARCH'	| 'SEQUENTIAL'	| 'SETS'
    | 'SIBLINGS'
    | 'SINGLE'	| 'STDDEV'	| 'STDDEV_POP'	| 'STDDEV_SAMP'
    | 'SUBMULTISET'	| 'SUBPARTITION'	| 'THE'	| 'TIMESTAMP'
    | 'TYPE'	| 'UNBOUNDED'	| 'UNDER_PATH'	| 'UNPIVOT'	| 'UNSIGNED'
    | 'UPDATED'
    | 'UPSERT'	| 'UROWID'	| 'VARIANCE'	| 'VARYING'
    | 'VAR_POP'	| 'VAR_SAMP'
    //| 'VERSIONS_ENDSCN'	| 'VERSIONS_ENDTIME' | 'VERSIONS_OPERATION'	| 'VERSIONS_STARSCN'	| 'VERSIONS_STARTTIME'	|
    | 'VERSIONS_XID'
    | 'XML'        
    | 'XMLDATA'        
    // mysql select hints
    | 'HIGH_PRIORITY' | 'STRAIGHT_JOIN' | 'SQL_SMALL_RESULT' | 'SQL_BIG_RESULT' | 'SQL_BUFFER_RESULT' | 'SQL_CACHE' | 'SQL_NO_CACHE' | 'SQL_CALC_FOUND_ROWS'
    | 'LOW_PRIORITY'
    | 'FULLTEXT'
    | 'CURRENT_TIMESTAMP'
    | 'INNODB'
    | 'MYISAM'
    | 'CONCAT'
    | 'CONCAT_WS'
    | 'USER'
    | 'NULLIF'
    | 'IFNULL'
    | 'FOUND_ROWS'
	;

quoted_string
	:	QUOTED_STRING | QSTRING
	;

QUOTED_STRING
	:	'\'' ('\\' ('\'')? | ~('\\' | '\''))* '\''
		//( 'n'|'N' )? QUOTE ( '\'\'' | '\\\'' | ~(QUOTE | '\\\'')* ) QUOTE
	{
		// stupid mysql escapes
		if(PGIFY_IS_ESCAPE(LEXSTATE->userp)) {
			pANTLR3_STRING str = GETTEXT();
			str->insert(str, 0, "E");
			SETTEXT(str);
/*			int p;
			pANTLR3_STRING str = GETTEXT();
			for(p = 0; p < str->len - 1; p++) {
				ANTLR3_UCHAR c = str->charAt(str, p);
				ANTLR3_UCHAR n = str->charAt(str, p + 1);
				if(c == '\\' && n == '\'') {
					pANTLR3_STRING a, b;
					a = str->subString(str, 0, p);
					b = str->subString(str, p + 1, str->len);
					a->append(a, "'");
					a->appendS(a, b);
					str = a;
				}
			}
			SETTEXT(str);
*/
		}
	}
	;
	
/* Perl-style quoted string */
QSTRING             : ('q'|'Q') ( QS_ANGLE | QS_BRACE | QS_BRACK | QS_PAREN | QS_OTHER) ;
fragment QS_ANGLE   : QUOTE '<' ( options {greedy=false;} : . )* '>' QUOTE ;
fragment QS_BRACE   : QUOTE '{' ( options {greedy=false;} : . )* '}' QUOTE ;
fragment QS_BRACK   : QUOTE '[' ( options {greedy=false;} : . )* ']' QUOTE ;
fragment QS_PAREN   : QUOTE '(' ( options {greedy=false;} : . )* ')' QUOTE ;

fragment QS_OTHER_CH: ~('<'|'{'|'['|'('|' '|'\t'|'\n'|'\r');
fragment QS_OTHER
		@init {
    		ANTLR3_UINT32 (*oldLA)(struct ANTLR3_INT_STREAM_struct *, ANTLR3_INT32);
			oldLA = INPUT->istream->_LA;
            INPUT->setUcaseLA(INPUT, ANTLR3_FALSE);
		}
		:	
		QUOTE delimiter=QS_OTHER_CH
/* JAVA Syntax */        
// 		( { input.LT(1) != $delimiter.text.charAt(0) || ( input.LT(1) == $delimiter.text.charAt(0) && input.LT(2) != '\'') }? => . )*
// 		( { input.LT(1) == $delimiter.text.charAt(0) && input.LT(2) == '\'' }? => . ) QUOTE
/* C Syntax */ 
		( { LA(1) != $delimiter->getText(delimiter)->chars[0] || LA(2) != '\'' }? => . )*
		( { LA(1) == $delimiter->getText(delimiter)->chars[0] && LA(2) == '\'' }? => . ) QUOTE
 		{ INPUT->istream->_LA = oldLA; }
		;

ID /*options { testLiterals=true; }*/
    :	'A' .. 'Z' ( 'A' .. 'Z' | '0' .. '9' | '_' | '$' | '#' )*
    |	DOUBLEQUOTED_STRING
    |   BACKQUOTED_STRING
    ;
SEMI
	:	';'
	;
COLON
	:	':'
	;
DOUBLEDOT
	:	POINT POINT
	;
DOT
	:	POINT
	;
fragment
POINT
	:	'.'
	;
COMMA 
	:	','
	;
EXPONENT
	:	'**'
	;
ASTERISK
	:	'*'
	;
AT_SIGN
	:	'@'
	;
RPAREN
	:	')'
	;
LPAREN
	:	'('
	;
RBRACK
	:	']'
	;
LBRACK
	:	'['
	;
PLUS
	:	'+'
	;
MINUS
	:	'-'
	;
DIVIDE
	:	'/'
	;
EQ
	:	'='
	;
PERCENTAGE
	:	'%'
	;
LLABEL
	:	'<<'
	;
RLABEL
	:	'>>'
	;
ASSIGN
	:	':='
	;
ARROW
	:	'=>'
	;
VERTBAR
	:	'|'
	;
DOUBLEVERTBAR
	:	'||'
	;
NOT_EQ
	:	'<>' | '!=' | '^='
	;
LTH
	:	'<'
	;
LEQ
	:	'<='
	;
GTH
	:	'>'
	;
GEQ
	:	'>='
	;
NUMBER
	:	//( PLUS | MINUS )?
		(	( NUM POINT NUM ) => NUM POINT NUM
		|	POINT NUM
		|	NUM
		)
		( 'E' ( PLUS | MINUS )? NUM )?
    ;
fragment
NUM
	: '0' .. '9' ( '0' .. '9' )*
	;
QUOTE
	:	'\''
	;
BACKTICK
	:	'`';
fragment
DOUBLEQUOTED_STRING
	:	'"' ( ~('"') )* '"'
	;
fragment
BACKQUOTED_STRING
	:	BACKTICK ( ~('`') )* BACKTICK
	{
		pANTLR3_STRING str = GETTEXT();
		str = str->subString(str, 1, str->len - 1);
		str->insert(str, 0, "\"");
		str->append(str, "\"");
			
		if(PGIFY_IS_LOWERID(LEXSTATE->userp)) {
			// mysql backticks are case-insensitive
			str = str->toUTF8(str);
			//printf("\%s len \%i\n", str->chars, str->len);
			gchar *lower = g_utf8_strdown(str->chars, -1);
			str->set(str, lower);
			g_free(lower);
		}
			
		SETTEXT(str);
	}
	;
WS	:	(' '|'\r'|'\t'|'\n') {$channel=HIDDEN;}
	;
SL_COMMENT
	:	'--' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
	;
MYSQL_COMMENT
	:	'#' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
	;
ML_COMMENT
	:	'/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
	;
