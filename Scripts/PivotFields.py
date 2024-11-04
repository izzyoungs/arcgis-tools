# Tool Name: PivotFieldsToDouble
# Purpose: Pivot the table of a feature class based on the values of one or more text fields.
# Author: Izzy Youngs
# Date: 2024-10-31
# Copyright: (C) 2024, Izzy Youngs
# Python Version: 3.6

import arcpy

def pivot_fields_to_double(input_fc, fields, output_fc):
    """
    This function pivots the specified text fields of the input feature class so that 
    each unique value in those fields becomes a new double field. The value will be set to 1 
    if the original field's value matches that unique value, and 0 otherwise.

    Parameters:
    input_fc (str): The path to the input feature class.
    fields (list): A list of field names to pivot.
    output_fc (str): The path to the output feature class.

    Returns:
    str: The path to the output feature class.
    """
    # Set workspace
    arcpy.env.workspace = 'memory'

    # Get the unique values for each of the specified fields
    unique_values = {}
    for field in fields:
        unique_values[field] = set(row[0] for row in arcpy.da.SearchCursor(input_fc, [field]))
        arcpy.AddMessage(f"{field} has {len(unique_values[field])} unique values")

    # Copy the input feature class to create the output with all original fields
    arcpy.CopyFeatures_management(input_fc, output_fc)

    # Create a layer from the output feature class
    arcpy.MakeFeatureLayer_management(output_fc, "output_layer")

    # Add new fields for each unique value in each input field, default value is 0
    for field, values in unique_values.items():
        for value in values:
            field_name = f"{str(value)}".replace(" ", "_").replace("-", "_").replace(".", "_")
            arcpy.AddField_management(output_fc, field_name, "DOUBLE", field_is_nullable="NULLABLE")
            # Initialize the field to 0 using the default value
            arcpy.CalculateField_management("output_layer", field_name, 0, "PYTHON3")

    # For each field and value, select records where field == value and set corresponding field to 1
    for field in fields:
        for value in unique_values[field]:
            field_name = f"{str(value)}".replace(" ", "_").replace("-", "_").replace(".", "_")
            # Build where clause, handling single quotes in values
            value_escaped = str(value).replace("'", "''")
            where_clause = f"{arcpy.AddFieldDelimiters(input_fc, field)} = '{value_escaped}'"
            # Select records
            arcpy.SelectLayerByAttribute_management("output_layer", "NEW_SELECTION", where_clause)
            # Set the field value to 1 for the selected records
            arcpy.CalculateField_management("output_layer", field_name, 1, "PYTHON3")

    # Clear selection
    arcpy.SelectLayerByAttribute_management("output_layer", "CLEAR_SELECTION")

    arcpy.AddMessage(f"Pivoted feature class created: {output_fc}")
    return output_fc

# Allows the script to be run as a script tool, from the command line, or imported as a module
if __name__ == "__main__":
    input_fc = arcpy.GetParameterAsText(0)
    fields = arcpy.GetParameterAsText(1).split(";")  # Assume input fields are separated by a semicolon
    output_fc = arcpy.GetParameterAsText(2)
    pivot_fields_to_double(input_fc, fields, output_fc)
