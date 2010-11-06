tree grammar topg;

options {
    tokenVocab	    = mysql;
    language	    = C;
    output          = AST;
    ASTLabelType	= pANTLR3_BASE_TREE;
}

statement
	: select_statement?
	;

select_statement
	: t_select
	SEMI
	;

t_select : -> ;
