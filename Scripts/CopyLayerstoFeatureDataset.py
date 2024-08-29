# Name: InitializeSchema.py
# Purpose: Will create a feature dataset to store local data, copy local data 
# to the feature dataset, update field names, and merge the data into a single feature class.
# Author: Izzy Youngs
# Last Modified: 06/25/24
# Copyright: Alta Planning + Design
# Python Version:   
# ArcGIS Version: 3.1 (Pro)
# --------------------------------
# Copyright 2024 Alta Planning + Design
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# --------------------------------
# Import Modules
import os
from sys import argv
try:
    import arcpy
except:
    arcpy.AddMessage("Could not import arcpy. Make sure you use Pro if the tool requires it.")

def CreateFeatureDataset(Workspace, FDSName, SpatialReference):
    """Create a feature dataset to store local data.
    Parameters:
    ----------------
    Workspace -- The workspace where the feature dataset will be created.
    FDSName -- The value table holding the feature layers and the feature dataset names.
    SpatialReference -- The spatial reference of the feature dataset."""

    value_table = arcpy.ValueTable(2)
    value_table.loadFromString(FDSName)

    unique_fds = []
    for i in range(value_table.rowCount):
        # Get the entire row
        FDS = value_table.getTrueValue(i, 1)
        # Grab only unique values in FDS
        if FDS not in unique_fds:
            unique_fds.append(FDS)

    # Check if the workspace already has feature datasets with the same name
    fds = arcpy.ListDatasets("*", "Feature")
    arcpy.AddMessage(f"Feature datasets in the workspace: {fds}")
    # Remove the feature datasets that already exist in the workspace
    for i in unique_fds:
        if i in fds:
            unique_fds.remove(i)
            arcpy.AddWarning(f"{i} already exists in the workspace. It will not be created.")

    try:
        for i in unique_fds:
            arcpy.AddMessage(f"Creating feature dataset {i}")
            FDSName = i
            arcpy.management.CreateFeatureDataset(out_dataset_path=Workspace, out_name=FDSName, spatial_reference=SpatialReference)
                
            arcpy.AddMessage(f"{FDSName} feature dataset has been created.")
    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

def CopyFeatures(FDSName, Workspace):
    """Copy local data to the feature dataset.
        Parameters:
        ----------------
        FDSName -- The value table holding the feature layers and the feature dataset names.
        Workspace -- The workspace where the feature dataset will be created."""
    
    value_table = arcpy.ValueTable(2)
    value_table.loadFromString(FDSName)
    
    try:
        n = 0
        for i in range(value_table.rowCount):
            # Get the entire row
            Layer = value_table.getTrueValue(i, 0)
            FDS_Name = value_table.getTrueValue(i, 1)
            n += 1
            new_lyrs = Layer.replace(" ", "_").replace("-", "_").replace(".", "").replace("\\", "_") + f"_s{n}"
            new_lyrs = f"fc_{new_lyrs}" if new_lyrs[0].isdigit() else new_lyrs
            lyr = os.path.join(Workspace, FDS_Name, new_lyrs)
            arcpy.management.CopyFeatures(in_features=Layer, out_feature_class=lyr)
            arcpy.AddMessage(f"{new_lyrs} has been copied to {FDS_Name}.")

    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

if __name__ == '__main__':
    # Define Inputs
    Workspace = arcpy.GetParameterAsText(0)
    FDSName = arcpy.GetParameterAsText(1)
    SpatialReference = arcpy.GetParameterAsText(2)
    arcpy.env.overwriteOutput = True
    arcpy.env.workspace = Workspace
    CreateFeatureDataset(Workspace, FDSName, SpatialReference)
    CopyFeatures(FDSName, Workspace)