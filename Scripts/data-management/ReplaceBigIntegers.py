"""
Tool Name: Replace Big Integer with Double
Purpose: Replace all fields of type "Big Integer" (Long) in a feature class with fields of type "Double".
Author: Izzy Youngs
Date: 2024-12-09
Copyright: Izzy Youngs
Python Version: 3.x
"""

import arcpy

def replace_big_integer_with_double(feature_class):
    """
    Replace all big integer fields in the input feature class with double fields.

    Parameters:
    feature_class (str): The path to the feature class to process.
    """
    try:
        # Describe the feature class
        fields = arcpy.ListFields(feature_class)
        
        # Identify big integer fields
        big_integer_fields = [field for field in fields if field.type in ('Integer', 'OID') and field.length >= 10]
        
        if not big_integer_fields:
            arcpy.AddMessage("No big integer fields found to replace.")
            return

        arcpy.AddMessage(f"Found {len(big_integer_fields)} big integer fields to process.")

        for field in big_integer_fields:
            arcpy.AddMessage(f"Processing field: {field.name}")
            
            # Construct new field name for double field
            new_field_name = field.name + "_dbl"
            new_field_alias = field.aliasName if field.aliasName else field.name + " (Double)"
            
            # Add a new double field
            arcpy.AddField_management(
                in_table=feature_class,
                field_name=new_field_name,
                field_type="DOUBLE",
                field_precision=15,
                field_scale=2,
                field_alias=new_field_alias
            )
            arcpy.AddMessage(f"Created new double field: {new_field_name}")

            # Copy values from big integer field to the new double field
            arcpy.CalculateField_management(
                in_table=feature_class,
                field=new_field_name,
                expression=f"!{field.name}!",
                expression_type="PYTHON3"
            )
            arcpy.AddMessage(f"Copied values from {field.name} to {new_field_name}.")

            # Delete the original big integer field
            arcpy.DeleteField_management(in_table=feature_class, drop_field=field.name)
            arcpy.AddMessage(f"Deleted original field: {field.name}.")

            # Rename the new double field to the original field's name
            arcpy.AlterField_management(
                in_table=feature_class,
                field=new_field_name,
                new_field_name=field.name,
                new_field_alias=field.aliasName if field.aliasName else field.name
            )
            arcpy.AddMessage(f"Renamed field {new_field_name} back to {field.name}.")

        arcpy.AddMessage("All big integer fields have been replaced successfully.")
    
    except arcpy.ExecuteError:
        arcpy.AddError(arcpy.GetMessages(2))
    except Exception as ex:
        arcpy.AddError(f"An error occurred: {ex}")

# Ensure the script can be run directly or imported
if __name__ == "__main__":
    # Define script parameters for ArcGIS script tool
    input_feature_class = arcpy.GetParameterAsText(0)
    replace_big_integer_with_double(input_feature_class)
