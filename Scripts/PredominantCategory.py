# -----------------------------------------------------------------------------
# Tool Name: Predominant Category Calculator
# Purpose: Calculate the predominant category from selected fields and the count of that predominance.
# Author: Izzy Youngs
# Date: 2024-08-30
# Copyright: (C) 2024, Izzy Youngs
# Python Version: 3.9
# -----------------------------------------------------------------------------

try:
    import arcpy
except:
    arcpy.AddMessage("Could not import arcpy. Make sure you use Pro if the tool requires it.")

def calculate_predominance(input_layer, fields_value_table):
    """Calculate the predominant category from selected fields and the count of that predominance.
    Parameters:
    ----------------
    layer -- The feature layer to calculate the predominant category.
    field_list -- The value table holding the fields to calculate the predominant category."""

    predominant_field_name = "Predominant_Category"
    predominant_value_name = "Predominance"

    arcpy.AddMessage("Calculating the predominant category and value...")

    fields_value_table = fields_value_table.split(";")
    fields_value_table = [item.strip('"').strip("'") for item in fields_value_table]

    fields_in_fc = {f.name: f.aliasName for f in arcpy.ListFields(input_layer)}
    fields_aliases = {key: value for key, value in fields_in_fc.items() if key in fields_value_table or value in fields_value_table}
    field_names = list(fields_aliases.keys())

    if predominant_field_name not in [f.name for f in arcpy.ListFields(input_layer)]:
        arcpy.AddField_management(input_layer, predominant_field_name, "TEXT", field_length=255)
    else:
        arcpy.AddWarning(f"{predominant_field_name} already exists in the input layer. Please delete first and rerun the tool.")
        
    if predominant_value_name not in [f.name for f in arcpy.ListFields(input_layer)]:
        arcpy.AddField_management(input_layer, predominant_value_name, "DOUBLE")

    # Calculate the predominant category and percentage
    with arcpy.da.UpdateCursor(input_layer, field_names + [predominant_field_name, predominant_value_name]) as cursor:
        for row in cursor:
            # Create a dictionary to hold counts for each field
            field_counts = [(field_names[i], row[i]) for i in range(len(field_names)) if isinstance(row[i], (int, float))]

            # Get the predominant field and count
            predominant_field = max(field_counts, key=lambda x: x[1])[0]
            predominant_count = max(field_counts, key=lambda x: x[1])[1]
           
            total = sum([row[i] for i in range(len(field_names)) if isinstance(row[i], (int, float))])
            percentage = predominant_count / total

            # replace the field name with the alias
            predominant_field = fields_aliases[predominant_field]

            # Update the row with the results
            row[-2] = predominant_field  # Update Predominant_Field
            row[-1] = percentage  # Update Predominant_Count
            
            # Update the cursor
            cursor.updateRow(row)

    arcpy.AddMessage("Predominant category and value have been calculated.")

# This test allows the script to be used from the operating
# system command prompt (stand-alone), in a Python IDE,
# as a geoprocessing script tool, or as a module imported in
# another script
if __name__ == '__main__':
    # Define Inputs
    input_layer = arcpy.GetParameter(0)
    fields_value_table = arcpy.GetParameterAsText(1)
    calculate_predominance(input_layer, fields_value_table)