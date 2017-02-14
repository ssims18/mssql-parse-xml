
/*
 
 Use Case:
 
 A client posts a file for importing into the database. One 
 field in the file contains a comma separated list, which 
 needs to be parsed and loaded as a normalized set of data.

 This set of steps converts the target field to xml, then 
 splits the values into a temp table for inserting with the 
 associated parent ID.

 The file could be parsed in a another script upstream before 
 the import. This process was used since the data was already 
 staged, and there was a time contraint to complete the core 
 table load.

*/

/* ------------------------------------

 ------------------------------------ */
-- check for existing temp table (allows re-execution of script)
if (dbo.f_temp_table_exists('#AiCodes')>0) drop table #AiCodes;
go

-- temp table for working
create table #AiCodes (
	npID varchar(20)        -- ID
	,AiCodes varchar(255)   -- comma separated codes
	,CodeCnt int            -- count of codes
);
create index ix1 on #AiCodes (npID);
go

-- load working table
insert into #AiCodes (npID, AiCodes, CodeCnt)
SELECT c.cID as npID, ltrim(rtrim(c.ai_codes)) as AiCodes, 
    (len(c.ai_codes) - len(replace(c.ai_codes, ' ','')) + 1) as CodeCnt
FROM CUSTOMERS c
where isnull(c.ai_codes, '') <> ''
order by 3 desc


/* ------------------------------------
	loop through xml nodes for code values
 ------------------------------------ */
SET QUOTED_IDENTIFIER ON
GO

if (dbo.f_temp_table_exists('#ai_wrk')>0) drop table #ai_wrk;
go

create table #ai_wrk (
	npID varchar(20)
	,code varchar(75)
);
create index ix1 on #ai_wrk (npID);
go



-------------------------------------------------------------
-------------------------------------------------------------
-- loop through xml nodes and load into temp wrk table.

declare @i int;
declare @query nvarchar(2000);

-- get number of delimiters + 1 for number of codes to loop through
set @i = (select max((len(AiCodes) - len(replace(AiCodes, ' ',''))))+1 from #AiCodes);

-- replace spaces with xml tags and query the xml node
set @query = ';WITH Split_Codes (npID, AiCodes, xmlname)
AS
(
    SELECT npID,
    AiCodes,
    CONVERT(XML,''<Codes><code>''  
		+ REPLACE(AiCodes,'' '', ''</code><code>'') + ''</code></Codes>'') AS xmlname
    FROM #AiCodes
)
insert into #ai_wrk (npID, code)
 SELECT  npID
	,xmlname.value(''/Codes[1]/code['+convert(nvarchar(5), @i)+']'',''nvarchar(100)'') AS code
FROM Split_Codes
where xmlname.value(''/Codes[1]/code['+convert(nvarchar(5), @i)+']'',''nvarchar(100)'') is not null';

while @i > 0
begin
	
	exec sp_executesql @query;
	
	set @i = @i -1;

	set @query = ';WITH Split_Codes (npID, AiCodes, xmlname)
		AS
		(
			SELECT npID,
			AiCodes,
			CONVERT(XML,''<Codes><code>''  
				+ REPLACE(AiCodes,'' '', ''</code><code>'') + ''</code></Codes>'') AS xmlname
			FROM #AiCodes
		)
		insert into #ai_wrk (npID, code)
		 SELECT  npID
			,xmlname.value(''/Codes[1]/code['+convert(nvarchar(5), @i)+']'',''nvarchar(100)'') AS code
		FROM Split_Codes
		where xmlname.value(''/Codes[1]/code['+convert(nvarchar(5), @i)+']'',''nvarchar(100)'') is not null';

end 
go
-------------------------------------------------------------
-------------------------------------------------------------
-- load to target DB table
-------------------------------------------------------------
-- loads the code reference from provided reference file
insert into REF_PROFILE_CODES (code_family, code_value, code_desc)
select 'ai_code', code, Description
from stg_codes
where Field_Name = 'ai_code'

-- from file
insert into PROFILES (cID, code_family, code_value)
select w.npID
	,'ai_code' as code_family
	,p.Code as code_value
from stg_ai_codes w
inner join stg_codes p on w.ai_code = p.Code
	and  Field_Name = 'ai_code'
inner join CUSTOMERS c on c.cID = w.npID
where ISNULL(w.code, '') <> ''
group by w.npID,p.Code,p.Description 
go


-- ai_code from xml
insert into PROFILES (cID, code_family, code_value, code_desc)
select w.npID
	,'ai_code' as code_family
	,w.code as code_value
    ,p.Description
from #ai_wrk w
inner join stg_codes p on w.code = p.Code
	and p.Field_Name = 'ai_code'
inner join CUSTOMERS c on c.cID = w.npID
where ISNULL(w.code, '') <> ''
	and not exists (select k.cID from PROFILES k where k.cID = w.npID and k.code_family = p.Field_Name and k.code_value = p.Code)
group by w.npID, p.Code, p.Description 
go
------------------------------------------------------------- 
------------------------------------------------------------- 
