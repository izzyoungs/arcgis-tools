# Name: GetOSMfromFS.py
# Purpose: Will pull OSM data (based on the data validation) for a study area
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

def get_osm(study_area, osm_tag, output_fc):
    """
    This function uses a study area and any osm tags to return OSM features.

    Args:
        study_area (feature class): The study area to return OSM points as
        osm_tag (string): the type of OSM features to return
        output_fc (feature class): The output OSM feature class
    """

    medical = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Medical/FeatureServer/0"
    education = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Educational/FeatureServer/0"
    tourism = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Tourism/FeatureServer/0"
    shops = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Shops/FeatureServer/0"
    leisure = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Leisure/FeatureServer/0"
    amenities = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_Amenities/FeatureServer/0"
    poi = r"https://services6.arcgis.com/Do88DoK2xjTUCXd1/arcgis/rest/services/OSM_NA_POIs/FeatureServer/0"


    try:
        arcpy.AddMessage(f"Returning OSM data for {osm_tag}...")

        osm_dict = {
            "Medical Facilities": medical,
            "Education": education,
            "Tourism": tourism,
            "Shops": shops,
            "Leisure": leisure,
            "Amenities": amenities,
            "POI": poi
        }

        # Select the key value pair that matches osm_tag
        feature_service = osm_dict[osm_tag] if osm_tag in osm_dict else None

        osm_layer = "osm_layer"

        arcpy.MakeFeatureLayer_management(feature_service, osm_layer)

        arcpy.SelectLayerByLocation_management(
        in_layer=osm_layer,
        overlap_type="INTERSECT",
        select_features=study_area,
        selection_type="NEW_SELECTION"
    )
        
        arcpy.AddMessage("Exporting OSM data...")
        arcpy.management.CopyFeatures(osm_layer, output_fc)

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
    osm_tag = arcpy.GetParameterAsText(1)
    output_lehd = arcpy.GetParameterAsText(2)

    get_osm(
        study_area,
        osm_tag,
        output_lehd
    )