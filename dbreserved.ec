/*
    dbreserved.ec - scans Informix database tables for key words
    Copyright (C) 1990,1994  David A. Snyder
 
    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; version 2 of the License.
 
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
 
    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef lint
static char sccsid[] = "@(#) dbreserved.ec 1.2  94/09/25 12:21:17";
#endif /* not lint */


#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <search.h>
#include "keyword.h"
$include sqlca;
$include sqltypes;

#define SUCCESS	0

char	*database = NULL, *table = NULL;
void	exit();

$struct _systables {
	char	tabname[19];
	char	owner[9];
	char	dirpath[65];
	long	tabid;
	short	rowsize;
	short	ncols;
	short	nindexes;
	long	nrows;
	long	created;
	long	version;
	char	tabtype[2];
	char	audpath[65];
} systables;

$struct _syscolumns {
	char	colname[19];
	long	tabid;
	short	colno;
	short	coltype;
	short	collength;
} syscolumns;

main(argc, argv)
int	argc;
char	*argv[];
{

	$char	exec_stmt[32], qry_stmt[72];
	extern char	*optarg;
	extern int	optind, opterr;
	int	c, dflg = 0, errflg = 0, tflg = 0;

	/* Print copyright message */
	(void)fprintf(stderr, "DBRESERVED version 1.2, Copyright (C) 1990,1994 David A. Snyder\n\n");

	/* get command line options */
	while ((c = getopt(argc, argv, "d:t:")) != EOF)
		switch (c) {
		case 'd':
			dflg++;
			database = optarg;
			break;
		case 't':
			tflg++;
			table = optarg;
			break;
		default:
			errflg++;
			break;
		}

	/* validate command line options */
	if (errflg || !dflg) {
		(void)fprintf(stderr, "usage: %s -d dbname [-t tabname]\n", argv[0]);
		exit(1);
	}

	/* locate the database in the system */
	sprintf(exec_stmt, "database %s", database);
	$prepare db_exec from $exec_stmt;
	$execute db_exec;
	if (sqlca.sqlcode != SUCCESS) {
		(void)fprintf(stderr, "Database not found or no system permission.\n\n");
		exit(1);
	}

	/* build the select statement */
	if (tflg) {
		if (strchr(table, '*') == NULL &&
		    strchr(table, '[') == NULL &&
		    strchr(table, '?') == NULL)
			sprintf(qry_stmt, "select tabname, tabid from systables where tabname = \"%s\" and tabtype = \"T\"", table);
		else
			sprintf(qry_stmt, "select tabname, tabid from systables where tabname matches \"%s\" and tabtype = \"T\"", table);
	} else
		sprintf(qry_stmt, "select tabname, tabid from systables where tabtype = \"T\" order by tabname");

	/* declare some cursors */
	$prepare tab_query from $qry_stmt;
	$declare tab_cursor cursor for tab_query;
	$declare col_cursor cursor for
	  select colname, colno from syscolumns
	    where tabid = $systables.tabid order by colno;

	/* read the database for the table(s) and create some output */
	$open tab_cursor;
	$fetch tab_cursor into $systables.tabname, $systables.tabid;
	if (sqlca.sqlcode == SQLNOTFOUND)
		fprintf(stderr, "Table %s not found.\n", table);
	while (sqlca.sqlcode == SUCCESS) {
		rtrim(systables.tabname);
		if (systables.tabid >= 100 &&
		   (strcmp(systables.tabname, "sysmenus") &&
		    strcmp(systables.tabname, "sysmenuitems") &&
		    strcmp(systables.tabname, "syscolatt") &&
		    strcmp(systables.tabname, "sysvalatt") || tflg))
			read_syscolumns();
		$fetch tab_cursor into $systables.tabname, $systables.tabid;
	}
	$close tab_cursor;

	exit(0);
}


read_syscolumns()
{
	char	*bsearch(), tmp_column[19];
	int	i, node_compare();
	struct node *node_ptr, node;

	node.string = tmp_column;

	$open col_cursor;
	$fetch col_cursor into $syscolumns.colname, $syscolumns.colno;
	while (sqlca.sqlcode == SUCCESS) {
		rtrim(syscolumns.colname);
		strcpy(node.string, syscolumns.colname);
		node_ptr = (struct node *)bsearch((char *)(&node),
		    (char *)word_table, WORD_TABSIZE,
		    sizeof(struct node ), node_compare);
		if (node_ptr != NULL)
			(void)printf("Reserved: %s.%s\n", systables.tabname, node_ptr->string);
		$fetch col_cursor into $syscolumns.colname, $syscolumns.colno;
	}
	$close col_cursor;
}


/*******************************************************************************
* This function will trim trailing spaces from s.                              *
*******************************************************************************/

rtrim(s)
char *s;
{
	int	i;

	for (i = strlen(s) - 1; i >= 0; i--)
		if (!isgraph(s[i]) || !isascii(s[i]))
			s[i] = '\0';
		else
			break;
}


/*******************************************************************************
* This routine does the actual comparing for bsearch().                        *
*******************************************************************************/

node_compare(node1, node2)
struct node *node1, *node2;
{
	return strcmp(node1->string, node2->string);
}


