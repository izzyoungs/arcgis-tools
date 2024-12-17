# -------------------------------------------------------------------------------
# Tool Name: Export Feature Layers to Geodatabase
# Purpose: This script creates a new file geodatabase and exports specified 
#          feature layers to the newly created geodatabase.
# Author: Izzy Youngs
# Date: 2024-11-18
# Copyright: © 2024 by Izzy Youngs
# Python Version: 3.x (compatible with ArcGIS Pro Python environment)
# -------------------------------------------------------------------------------

import arcpy
import os

def export_layers_to_gdb(feature_layers, gdb_location):
    """
    Creates a new file geodatabase and exports feature layers to it.
    
    :param feature_layers: List of feature layers to export.
    :param gdb_location: Location of the gdb.
    """
    try:
        # Check if the geodatabase already exists
        if arcpy.Exists(gdb_location):
            print(f"Geodatabase already exists. New data will be added to it.")
        else:
            # Create the geodatabase
            arcpy.CreateFileGDB_management(os.path.dirname(gdb_location), os.path.basename(gdb_location))
            print(f"Created new geodatabase: {os.path.dirname(gdb_location)}.gdb")

        # Export each feature layer to the geodatabase
        for layer in feature_layers:
            layer_name = os.path.basename(layer)
            print(f"Exporting {layer_name} to {gdb_name}.gdb...")
            arcpy.FeatureClassToGeodatabase_conversion(layer, gdb_location)
            print(f"Exported {layer_name} successfully.")

        print(f"All layers have been exported to gdb.")

    except Exception as e:
        arcpy.AddError(f"An error occurred: {e}")
        print(f"An error occurred: {e}")

# Main block to enable running the script directly or importing as a module
if __name__ == "__main__":
    # Example of user inputs
    # Replace these paths and names with your inputs when running the script.
    feature_layers = [
        r"C:\Path\To\Your\FeatureLayer1.shp",
        r"C:\Path\To\Your\FeatureLayer2.shp"
    ]
    gdb_name = "MyNewGeodatabase"
    output_folder = r"C:\Path\To\Output\Folder"

    # Run the function
    export_layers_to_gdb(feature_layers, gdb_location)
