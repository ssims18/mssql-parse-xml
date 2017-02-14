/*
    Function: f_temp_table_exists

	Checks for the existence of a temp table
	(## name or # name), and returns a 1 if
	it exists, and a 0 if it doesn't exist.

*/
Create function  [dbo].[f_temp_table_exists]
	( @temp_table_name sysname )
returns int
as
begin

    if exists (
        select  *
        from tempdb.dbo.sysobjects o
        where o.xtype in ('U') 
            and o.id = object_id( N'tempdb..' + @temp_table_name )
        )
        begin return 1 end

    return 0

end
