# Name: GeneratePandanaNetwork.py
# Purpose: Will pull network from OSMNX and generate a pandana network for a study area
# Author: Izzy Youngs
# Last Modified: 12/24/2025
# Copyright: David Wasserman, Izzy Youngs
# Python Version:   3.11.10
# ArcGIS Version: 10.5 (Pro)
# --------------------------------
# Copyright 2025 David Wasserman, Izzy Youngs
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
import geopandas as gpd
import seaborn as sns
import osmnx as ox
import networkx as nx
from shapely.geometry import Point, Polygon, LineString
from descartes import PolygonPatch
import pyproj, fiona, os
import keplergl, pickle
import pandana as pdna
import warnings
warnings.filterwarnings('ignore')
import arcpy
from arcgis.features import GeoAccessor, GeoSeriesAccessor
import sys
sys.path.append("..")
import tempfile
import srosm
import lts
import access
import network
import geolib as gl
import demo

ox.settings.use_cache = False

def generate_pandana(study_area, output_network):
    """_summary_

    Args:
        study_area (_type_): _description_
        output_network (_type_): _description_
    """
    temp_dir = tempfile.TemporaryDirectory()
    graph_saved = os.path.join(temp_dir,"StreetGraph.gpkg ")
    final_graph_saved = os.path.join(temp_dir,"WebNetworkWLTS.graphml")
    pdna_store = os.path.join(temp_dir,"WebNetworkWLTS.h5")


    try:
        arcpy.AddMessage("Preparing a network with lts...")
        G = network.prepare_multimodal_network_with_lts(study_area)
        # nodes_gdf = ox.graph_to_gdfs(G,edges=False)

        weights = ["Walk_Min", "Bike_Min", "EBike_Min", "LTSBike_Wlk_Min", "LTSEBike_Wlk_Min"]
        net_nodes, net_edges = network.generate_pandana_nodes_edges_from_G(G,weights,"oneway_num",pdna_store,overwrite_existing=False)

        # pdna_net = pdna.Network(net_nodes["x"], net_nodes["y"], net_edges["from"], net_edges["to"],
        #          net_edges[weights], twoway=False)
        
        G_undirected = ox.get_undirected(G)
        gdf_nodes, gdf_edges = ox.graph_to_gdfs(G_undirected)

        gdf_edges_sanitized = gl.sanitize_gdf(gdf_edges)
        gdf_edges_sanitized.memory_usage(deep=True)

        out_gpkg = os.path.join(temp_dir,"LTS_OSM_OpenData.gpkg") 

        lts_network = "OSM_LTS_Analysis"
        arcpy.AddMessage("Exporting access results...")

        print("Exporting Network...")
        gdf_edges_sanitized.to_file(out_gpkg,layer=lts_network, driver="GPKG")

        arcpy.AddMessage("Export Geojson")
        out_geojson_network = os.path.join(temp_dir, lts_network+".geojson")
        gdf_edges_sanitized.to_crs(4326).to_file(out_geojson_network,driver="GeoJSON")

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
    output_network = arcpy.GetParameterAsText(1)

    generate_pandana(
        study_area,
        output_network
    )