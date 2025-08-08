"""
Tool Name: Fill Null Values
Purpose: Fills null values in specified fields of a feature class with a user-defined value.
Author: Izzy Youngs
Date: 2024-12-09
Copyright: © 2024 Izzy Youngs
Python Version: 3.9
"""

import arcpy

def fill_null_values(feature_class, fields, fill_value):
    """
    Updates NULL values in the specified fields of a feature class with the provided fill_value.
    Throws an error if the fill_value cannot be cast to the field's data type.
    """
    # Ensure the feature class exists
    if not arcpy.Exists(feature_class):
        raise arcpy.ExecuteError(f"Feature class {feature_class} does not exist.")

    # Get field metadata for type checking
    field_info = {f.name: f.type for f in arcpy.ListFields(feature_class) if f.name in fields}

    # Check for missing fields
    missing_fields = [f for f in fields if f not in field_info]
    if missing_fields:
        raise arcpy.ExecuteError(f"Fields not found: {', '.join(missing_fields)}")

    # Validate fill_value against each field type
    for f_name, f_type in field_info.items():
        try:
            if f_type in ("Double", "Single", "Integer", "SmallInteger"):
                _ = float(fill_value)  # allows int or float
            elif f_type in ("Date",):
                _ = arcpy.datetime.datetime.fromisoformat(fill_value)
            elif f_type in ("String", "Text"):
                _ = str(fill_value)
            else:
                raise arcpy.ExecuteError(f"Unsupported field type: {f_type}")
        except Exception as e:
            raise arcpy.ExecuteError(
                f"Incompatible fill_value '{fill_value}' for field '{f_name}' (type {f_type}): {e}"
            )

    # Perform update cursor
    with arcpy.da.UpdateCursor(feature_class, fields) as cursor:
        for row in cursor:
            updated = False
            for i, f_name in enumerate(fields):
                if row[i] is None:
                    # Cast fill_value to correct type before assignment
                    f_type = field_info[f_name]
                    if f_type in ("Double", "Single"):
                        row[i] = float(fill_value)
                    elif f_type in ("Integer", "SmallInteger"):
                        row[i] = int(float(fill_value))
                    elif f_type in ("Date",):
                        row[i] = arcpy.datetime.datetime.fromisoformat(fill_value)
                    elif f_type in ("String", "Text"):
                        row[i] = str(fill_value)
                    updated = True
            if updated:
                cursor.updateRow(row)

    arcpy.AddMessage("Script completed successfully.")


if __name__ == "__main__":
    # Parameters from GP tool
    fc = arcpy.GetParameterAsText(0)
    fields_param = arcpy.GetParameterAsText(1)  # Multivalue comes as semicolon-separated string
    fields_list = [f.strip() for f in fields_param.split(";") if f.strip()]
    fill_val = arcpy.GetParameterAsText(2)

    fill_null_values(fc, fields_list, fill_val)

