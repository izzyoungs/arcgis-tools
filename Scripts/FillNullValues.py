"""
Tool Name: Fill Null Values
Purpose: Fills null values in specified fields of a feature class with a user-defined value.
Author: Izzy Youngs
Date: 2024-12-09
Copyright: © 2024 Izzy Youngs
Python Version: 3.9
"""

import arcpy
import os

def fill_null_values(feature_class, fields, fill_value):
    """
    Fills null values in the specified fields of a feature class with the provided value.

    :param feature_class: Path to the input feature class
    :param fields: List of field names to process
    :param fill_value: Value to replace nulls
    """
    try:
        # Check if the feature class exists
        if not arcpy.Exists(feature_class):
            raise FileNotFoundError(f"Feature class '{feature_class}' does not exist.")
        
        field_list = arcpy.ListFields(feature_class)
        field_type_map = {f.name: f.type for f in field_list}

        user_fields = [f for f in fields if f in field_type_map]

        numeric_types = {"Double", "Float", "Short", "Long"}
        user_has_numeric = any(field_type_map[f] in numeric_types for f in user_fields)

        # Check that if the field type is numeric, the fill_value is not a string
        if user_has_numeric:
            try:
                fill_value = float(fill_value)
            except ValueError:
                raise ValueError(f"Fill value '{fill_value}' is not valid for numeric fields (must be castable to float).")

        # Start editing the feature class
        with arcpy.da.UpdateCursor(feature_class, fields) as cursor:
            updated_count = 0
            for row in cursor:
                row_updated = False
                for i, value in enumerate(row):
                    if value is None or value == "":
                        row[i] = fill_value
                        row_updated = True
                if row_updated:
                    cursor.updateRow(row)
                    updated_count += 1
        
        arcpy.AddMessage(f"Updated {updated_count} rows. Null values in fields {', '.join(fields)} have been successfully updated.")
    
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # Allow the script to be used as a geoprocessing tool or standalone script
    arcpy.env.overwriteOutput = True

    # Get parameters from the user when run as a tool
    feature_class = arcpy.GetParameterAsText(0)  # Feature class
    fields = arcpy.GetParameterAsText(1).split(";")  # Semicolon-separated field names
    fill_value = arcpy.GetParameterAsText(2)  # Fill value

    # Call the function
    fill_null_values(feature_class, fields, fill_value)
