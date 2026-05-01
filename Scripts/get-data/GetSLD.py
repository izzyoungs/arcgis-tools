# Name: GetSLD.py
# Purpose: Will pull Smart Location Database fields from feature service for study area.
# Author: Izzy Youngs
# Last Modified: 11/25/2025
# Copyright: Izzy Youngs
# Python Version:   3.11.10
# ArcGIS Version: 10.4 (Pro)
# --------------------------------
# Copyright 2025 Izzy Youngs
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
import pandas as pd
import arcpy

from arcgis.features import GeoAccessor, GeoSeriesAccessor

def get_sld(study_area, output_fc):
    """
    This function uses a study area and returns the SLD fields most used in Civic Analytics for the study area.

    Args:
        study_area (feature class): The study area to return SLD geometries for
        output_fc (feature class): The output feature class
    """

    try:
        arcpy.AddMessage("Retrieving SLD feature service...")

        sld_feature_service = "https://services.arcgis.com/cJ9YHowT8TU7DUyn/ArcGIS/rest/services/Smart_Location_Database_/FeatureServer/0"

        sld_layer = "sld_layer"

        arcpy.MakeFeatureLayer_management(sld_feature_service, sld_layer)

        arcpy.SelectLayerByLocation_management(
        in_layer=sld_layer,
        overlap_type="INTERSECT",
        select_features=study_area,
        selection_type="NEW_SELECTION"
    )

        arcpy.AddMessage("Cleaning field names...")
        sld_df = pd.DataFrame.spatial.from_featureclass(sld_layer)

        sld_df = sld_df[['GEOID20', 'D4A', 'SHAPE']]
        sld_df = sld_df.rename(columns={'GEOID20':'GEOID', 'D4A':'Distance_Nearest_Transit'})

        arcpy.AddMessage("Exporting SLD data...")
        sld_df.spatial.to_featureclass(output_fc)

        arcpy.AddMessage("Script completed successfully.")


        
    except arcpy.ExecuteError:
        arcpy.AddError(arcpy.GetMessages(2))
    except Exception as e:
        arcpy.AddError(e.args[0])



# This test allows the script to be used from the operating
# system command prompt (stand-alone), in a Python IDE,
# as a geoprocessing script tool, or as a module imported in
# another script
if __name__ == "__main__":
    # Define Inputs
    study_area = arcpy.GetParameterAsText(0)
    output_fc = arcpy.GetParameterAsText(1)

    get_sld(
        study_area,
        output_fc
    )