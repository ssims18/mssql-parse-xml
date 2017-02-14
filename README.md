# mssql-parse-xml
Example of using MSSQL to parse some xml records

A client posts a file for importing into the database. One field in the file contains a comma separated list, which needs to be parsed and loaded as a normalized set of data.
This set of steps converts the target field to xml, then splits the values into a temp table for inserting with the associated parent ID.
The file could be parsed in a another script upstream before the import. This process was used since the data was already staged, and there was a time contraint to complete the core table load.
