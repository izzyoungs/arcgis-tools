# Name: UpdateAliases.py
# Purpose: This tool will take a csv where the first field is the field name and the second field is the alias and update the aliases of the fields in the input feature class or table.
# Author: Izzy Youngs
# Last Modified: 10/16/2024
# Copyright: Alta Planning & Design
# Python Version:  3.6
# --------------------------------
# Import Modules
import csv
try:
    import arcpy
except:
    arcpy.AddMessage("Could not import arcpy. Make sure you use Pro if the tool requires it.")

def alias_update(infc, in_csv):
    """Update the aliases of fields in the input feature class or table.
    Parameters:
    ----------------
    infc -- The input feature class or table.
    in_csv -- The csv file containing the field names and aliases."""

    # Create a dictionary to store field-alias pairs from CSV
    field_alias_dict = {}

    # Open and read CSV file to populate the dictionary
    with open(in_csv, 'r', newline='', encoding='utf-8') as csvfile:
        alias_csv = csv.reader(csvfile)
        field_alias_dict = {row[0]: row[1] for row in alias_csv}

    # Get list of field names from the input feature class or table
    fields = {f.name: f for f in arcpy.ListFields(infc)}

    # Loop through the field-alias dictionary and update aliases where fields exist
    for field_name, alias in field_alias_dict.items():
        if field_name in fields:
            arcpy.AlterField_management(infc, field_name, new_field_alias=alias)
            arcpy.AddMessage(f"Alias updated for field {alias}")
        else:
            arcpy.AddMessage(f"Table does not contain field {field_name}; alias not updated")


if __name__ == '__main__':
    # Define Inputs
    infc = arcpy.GetParameterAsText(0)
    in_csv = arcpy.GetParameterAsText(1)
    arcpy.env.overwriteOutput = True
    alias_update(infc, in_csv)