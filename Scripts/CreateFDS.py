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
    
    # Set the workspace
    arcpy.env.workspace = workspace
    
    # Check if the workspace exists
    if not arcpy.Exists(workspace):
        arcpy.AddError(f"The workspace '{workspace}' does not exist.")
        return

    # Create spatial reference object
    spatial_ref = arcpy.SpatialReference(projection)
    
    for dataset_name in dataset_names:
        try:
            # Create feature dataset
            arcpy.CreateFeatureDataset_management(workspace, dataset_name, spatial_ref)
            arcpy.AddMessage(f"Feature dataset '{dataset_name}' created successfully.")
        except Exception as e:
            arcpy.AddError(f"Failed to create feature dataset '{dataset_name}': {str(e)}")
            continue


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