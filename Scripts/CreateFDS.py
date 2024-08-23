# Name: CreateFDS.py
# Purpose: This tool will take a series of strings, a workspace, and a projection and create new feature datasets in the workspace.
# Author: Izzy Youngs
# Last Modified: 8/23/2024
# Copyright: Alta Planning & Design
# Python Version:  3.6
# --------------------------------
# Import Modules
import arcpy, os

# Define the geoprocessing tool
def create_feature_datasets(dataset_names, workspace, projection):
    """
    Create new feature datasets in a given workspace using the specified projection.

    Parameters:
    dataset_names (list): List of feature dataset names to be created
    workspace (str): The path to the workspace (e.g., file geodatabase)
    projection (str): The spatial reference to apply to the feature datasets (e.g., WKID or projection string)
    """
    
    arcpy.AddMessage(f"Creating feature datasets in '{workspace}'...")

    # Set the workspace
    arcpy.env.workspace = workspace

    value_table = arcpy.ValueTable(1)
    value_table.loadFromString(dataset_names)
    
    # Check if the workspace exists
    if not arcpy.Exists(workspace):
        arcpy.AddError(f"The workspace '{workspace}' does not exist.")
        return

    for i in range(0, value_table.rowCount):
        name = value_table.getValue(i, 0)
        name = name.strip().strip("'\"")

        arcpy.AddMessage(f"Creating feature dataset '{name}'...")

        # Check if the feature dataset already exists
        if arcpy.Exists(os.path.join(workspace, name)):
            arcpy.AddWarning(f"Feature dataset '{name}' already exists. Skipping creation.")
        else:
                try:
                    arcpy.CreateFeatureDataset_management(workspace, name, projection)
                    arcpy.AddMessage(f"Feature dataset '{name}' created successfully.")
                except Exception as e:
                    arcpy.AddError(f"Failed to create feature dataset '{name}': {str(e)}")


# This test allows the script to be used from the operating
# system command prompt (stand-alone), in a Python IDE,
# as a geoprocessing script tool, or as a module imported in
# another script
if __name__ == '__main__':
    # Define Inputs
    dataset_names = arcpy.GetParameterAsText(0)
    workspace = arcpy.GetParameterAsText(1)
    projection = arcpy.GetParameterAsText(2)

    # Call the function to create the feature datasets
    create_feature_datasets(dataset_names, workspace, projection)