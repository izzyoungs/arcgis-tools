# Name: UpdateAliases.py
# Purpose: Update field aliases in a feature class or table based on a CSV mapping.
# Author: Izzy Youngs
# Last Modified: 10/16/2024
# Copyright: Alta Planning & Design
# Python Version:  3.6
# --------------------------------

# Import Modules
import csv, tempfile, os, arcpy
import pandas as pd
import numpy as np

def alias_update(out_fc, in_table):
    """Update the aliases of fields in the input feature class or table.
    
    Parameters:
    ----------
    infc : str
        The input feature class or table.
    in_csv : str
        The CSV file containing the field names and aliases.
    """
    
    arcpy.AddMessage("Importing feature class to update aliases...")
    # create a copy of out_fc as a temp copy
    in_fc = arcpy.conversion.ExportFeatures(out_fc, "memory\in_fc")

    array = arcpy.da.TableToNumPyArray(in_table, field_names="*")
    df = pd.DataFrame(array)

    arcpy.AddMessage("Reading alias table...")

    # Create a temporary CSV file and write the DataFrame to it
    with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as temp_csv:
        temp_csv_name = temp_csv.name
        df.to_csv(temp_csv_name, index=False)

    arcpy.conversion.ExportTable(in_table=in_table, out_table=temp_csv_name)

    arcpy.AddMessage("Updating fields...")
    arcpy.management.BatchUpdateFields(in_fc, out_fc, temp_csv_name, script_file=None, output_field_name="target_field", source_field_name="source_field", output_field_type=None, output_field_decimals_or_length=None, output_field_alias="field_alias", output_field_script=None)
    

if __name__ == '__main__':
    try:
        # Define Inputs
        out_fc = arcpy.GetParameterAsText(0)
        in_table = arcpy.GetParameterAsText(1)
        arcpy.env.overwriteOutput = True
        alias_update(out_fc, in_table)
    except Exception as e:
        arcpy.AddError(f"An unexpected error occurred: {e}")
