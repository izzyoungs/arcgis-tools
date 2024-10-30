# Tool Name: PivotFieldsToDouble
# Purpose: Pivot the table of a feature class based on the values of one or more text fields.
# Author: Izzy Youngs
# Date: 2024-10-17
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

    Returns:
    str: The path to the output feature class.
    """
    # Set workspace
    # arcpy.env.workspace = arcpy.Describe(input_fc).path
    arcpy.env.workspace = 'memory'

    # Create a new feature class name for the output
    # output_fc = arcpy.CreateUniqueName("Pivoted_" + arcpy.Describe(input_fc).baseName, arcpy.env.workspace)
    
    # Get the unique values for each of the specified fields
    unique_values = {}
    for field in fields:
        unique_values[field] = set(row[0] for row in arcpy.da.SearchCursor(input_fc, [field]))

        arcpy.AddMessage(f"{field} has {len(unique_values[field])} unique values")

    # Create a list of new field names for the pivoted table
    pivot_fields = []
    for field, values in unique_values.items():
        for value in values:
            # Clean up the field name by removing invalid characters
            field_name = f"{str(value)}".replace(" ", "_").replace("-", "_").replace(".", "_")
            pivot_fields.append(field_name)

    arcpy.AddMessage(f"Creating {len(pivot_fields)} new fields for the pivoted table")

    # Copy the input feature class to create the output with all original fields
    arcpy.CopyFeatures_management(input_fc, output_fc)

    # Add the new fields for each unique value in each input field
    for new_field in pivot_fields:
        arcpy.AddField_management(output_fc, new_field, "DOUBLE")

    # Create an update cursor to fill in the pivoted values
    with arcpy.da.UpdateCursor(output_fc, fields + pivot_fields) as cursor:

        pivot_field_indices = {field: cursor.fields.index(field) for field in pivot_fields}
        
        for row in cursor:
            # Initialize pivot values to 0
            for pivot_field in pivot_fields:
                row[pivot_field_indices[pivot_field]] = 0.0

            # Set the corresponding field to 1 for each field's value
            for i, field in enumerate(fields):
                field_value = row[i]
                field_name = f"{str(field_value)}".replace(" ", "_").replace("-", "_").replace(".", "_")
                
                # Only update if the corresponding pivot field exists in the mapping
                if field_name in pivot_field_indices:
                    row[pivot_field_indices[field_name]] = 1.0

            # Update the row with the pivoted values
            cursor.updateRow(row)

    # Delete original fields
    # arcpy.DeleteField_management(output_fc, fields)

    arcpy.AddMessage(f"Pivoted feature class created: {output_fc}")
    return output_fc

# Allows the script to be run as a script tool, from the command line, or imported as a module
if __name__ == "__main__":
    input_fc = arcpy.GetParameterAsText(0)
    fields = arcpy.GetParameterAsText(1).split(";")  # Assume input fields are separated by a semicolon
    output_fc = arcpy.GetParameterAsText(2)
    pivot_fields_to_double(input_fc, fields, output_fc)