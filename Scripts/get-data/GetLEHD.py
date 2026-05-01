# Name: GetLEHD.py
# Purpose: Will pull LEHD data from url based on a study area
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

def get_lehd(study_area, output_lehd):
    """
    This function will take a study area, grab the census block groups for the study area, and return the LEHD Worker Area Characteristics for 2022 
    for the block groups intersecting the study area. 
    Parameters
    -----------------
    study_area (feature class): 
    output_lehd (feature class): 
    """
    
    try:
        arcpy.AddMessage("Getting block group feature service for 2020 from Living Atlas...")
        blockgroups_url = (
        r"https://services.arcgis.com/P3ePLMYs2RVChkJx/arcgis/rest/services/USA_Census_BlockGroups/FeatureServer/0"
    )
        bg_layer = "blockgroups_lyr"

        arcpy.MakeFeatureLayer_management(blockgroups_url, bg_layer)

        arcpy.AddMessage("Returning only block groups for study area...")
        arcpy.SelectLayerByLocation_management(
        in_layer=bg_layer,
        overlap_type="INTERSECT",
        select_features=study_area,
        selection_type="NEW_SELECTION"
    )
        
        out_fc = "memory\intersecting_block_groups"

        result = arcpy.CopyFeatures_management(bg_layer, out_fc)

        out_df = pd.DataFrame.spatial.from_featureclass(result[0])

        arcpy.AddMessage("Identifying the state for LEHD data...")
        state_info = (
                out_df["STATE_ABBR"]
                .unique()
                .tolist()
            )
        
        # If there is more than one unique state, return an error:
        if len(state_info) > 1:
            raise ValueError(f"Multiple states found: {list(state_info)}")
        elif len(state_info) == 0:
            raise ValueError("No valid states found.")

        url = f"https://lehd.ces.census.gov/data/lodes/LODES8/{state_info[0].lower()}/wac/{state_info[0].lower()}_wac_S000_JT00_2022.csv.gz"
    
        arcpy.AddMessage("Returning LEHD WAC data...")
        lehd = (
            pd.read_csv(url)
            # Force w_geocode to string and pad LEFT with zeros to length 15
            .assign(
                w_geocode=lambda df: df["w_geocode"].astype(str).str.zfill(15),
                GEOID=lambda df: df["w_geocode"].str.slice(0, 12)
            )
            .groupby("GEOID", as_index=False)
            .agg(jobs=("C000", "sum"))
        )

        arcpy.AddMessage("Joining LEHD data to block groups...")
        # left join the lehd df to the out_df by geoid
        out_df_merged = (
                            out_df
                            .assign(FIPS=lambda df: df["FIPS"].astype(str))
                            .merge(
                                lehd.assign(GEOID=lambda df: df["GEOID"].astype(str)),
                                how="left",
                                left_on="FIPS",
                                right_on="GEOID"
                            )
                        )
        
        out_df_merged = out_df_merged[['FIPS', 'jobs', 'SHAPE']]

        arcpy.AddMessage("Exporting LEHD data to feature class...")
        out_df_merged.spatial.to_featureclass(output_lehd)

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
    output_lehd = arcpy.GetParameterAsText(1)

    get_lehd(
        study_area,
        output_lehd
    )