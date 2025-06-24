"""
Tool Name: Get Overture places
Purpose: This script retrieves places from the Overture database.
Author: Izzy Youngs
Date: 2025-05-22
Copyright: © 2025 Izzy Youngs
Python Version: 3.9
"""

import arcpy
import os
from pyplaces import overture_maps as om

def get_overture_places(bounding_box, search_radius, output_fc):
    """
    Retrieves places from the Overture database within a specified bounding box and search radius.

    :param bounding_box: Tuple of (min_x, min_y, max_x, max_y) defining the bounding box
    :param search_radius: Search radius with distance units
    :param output_fc: Path to the output feature class
    """

    release = '2025-04-23.0'
    
    try:
        # Create an empty feature class to store results
        spatial_ref = arcpy.SpatialReference(4326)  # WGS 84
        arcpy.CreateFeatureclass_management(os.path.dirname(output_fc), os.path.basename(output_fc), "POINT", spatial_reference=spatial_ref)

        # Add fields to the feature class
        arcpy.AddField_management(output_fc, "Name", "TEXT")
        arcpy.AddField_management(output_fc, "Type", "TEXT")

        # Retrieve places from Overture
        places = om.get_places(bounding_box, search_radius)

        # Insert places into the feature class
        with arcpy.da.InsertCursor(output_fc, ["SHAPE@", "Name", "Type"]) as cursor:
            for place in places:
                cursor.insertRow([place.geometry, place.name, place.type])

        arcpy.AddMessage(f"Retrieved {len(places)} places and saved to {output_fc}")

    except Exception as e:
        print(f"An error occurred: {e}")