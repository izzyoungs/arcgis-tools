# Name: InitializeSchema.py
# Purpose: Will create a feature dataset to store all data from a map document.
# Author: Izzy Youngs
# Last Modified: 05/07/2024
# Copyright: Izzy Youngs
# Python Version:   
# ArcGIS Version: 3.1 (Pro)
# --------------------------------
# Copyright 2024 Izzy Youngs
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

def CreateFeatureDataset(Workspace, FeatureDataset, Projection):
    """Create a feature dataset to store local data.
    Parameters:
    ----------------
    Workspace -- The workspace where the feature dataset will be created.
    FeatureDataset -- The name of the feature dataset.
    Projection -- The projection of the feature dataset."""
    arcpy.AddMessage("Creating feature dataset...")
    
    # Process: Create Feature Dataset (Create Feature Dataset) (management)
    arcpy.management.CreateFeatureDataset(out_dataset_path=Workspace, out_name=FeatureDataset, 
                                        spatial_reference=Projection)
    arcpy.AddMessage("Feature dataset has been created.")

def CopyFeatures(Map, FeatureDataset):
    """Copy local data to the feature dataset.
        Parameters:
        ----------------
        Map -- The map containing the local data.
        FeatureDataset -- The feature dataset where the local data will be copied."""
    arcpy.AddMessage(f"Copying data from the {Map} map to the {FeatureDataset} feature dataset...")
    FeatureDataset = os.path.join(Workspace, FeatureDataset)
    aprx = arcpy.mp.ArcGISProject("CURRENT")
    m = aprx.listMaps(Map)[0]
    map_layers = m.listLayers()
    n = 0

    for lyr in map_layers:
        if lyr.isFeatureLayer:
            lyrs = lyr.listLayers()
            if not lyrs:
                new_lyrs = str(lyr.longName)
                new_lyrs = new_lyrs.replace(" ", "_").replace("-", "_").replace(".", "").replace("\\", "_")
                new_lyrs = f"fc_{new_lyrs}" if new_lyrs[0].isdigit() else new_lyrs
                arcpy.AddMessage(f"{new_lyrs} is being copied to the feature dataset...")
                arcpy.FeatureClassToFeatureClass_conversion(lyr, FeatureDataset, new_lyrs)
                

    arcpy.AddMessage("The script has completed successfully.")

if __name__ == '__main__':
    # Define Inputs
    Workspace = arcpy.GetParameterAsText(0)
    Map = arcpy.GetParameter(1)
    FeatureDataset = arcpy.GetParameter(2)
    Projection = arcpy.GetParameterAsText(3)
    arcpy.env.overwriteOutput = True
    arcpy.env.workspace = Workspace
    CreateFeatureDataset(Workspace, FeatureDataset, Projection)
    CopyFeatures(Map, FeatureDataset)