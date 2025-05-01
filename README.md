# Toolbox Summary
This repository holds a collection of custom ArcGIS Geoprocessing scripts for ArcGIS Pro 3.2. This repository also contains an atbx to assist in automated running of repeated tasks. The tools are described below:
## Data Management Toolbox
* *Apportion Polygon (Updated)* - **This tool is under development**. It will use Esri's methodology for using population in census blocks to proportionally allocate population to non-census geometries. 
* *Guess CRS from Point* - This geoprocessing tool was created with R with the help of [Kyle Walker](https://walker-data.com/)'s [crssuggest](https://github.com/walkerke/crsuggest) library. The tool takes a custom bounding box and returns a list of possible projections.
* *Pivot Fields in Feature Class* - This tool takes an input dataset where each row represents a single unit of analysis but contains categorical data that needs to be converted to numeric/dummy variables. It takes the fields as an input and pivots the features so that each possible categorical variable is its own field with a 0 or 1 indicating row inclusion. 
* *Predominant Category* - This tool is designed to reflect the logic within ArcGIS Online's predominant category symbology. It takes multiple fields as inputs and calcualtes which field is predominant for the feature and returns the field and the strength of that predominance. 
* *Replace Null Values* - This tool takes a feature class, selected fields, and a fill value and fills all selected fields with input value. If the field types are not compatible it will return an error. 
* *Update Aliases* - This tool takes an input feature layer and a csv and updates the aliases based on the csv's first two columns. The first column represents the field name and the second represents the updated alias. 

## Get Data Toolbox
* *Enrich Study Area with Census Data* - **This tool is under development**. It will grab ACS variables and enrich the input features based on variables and proportional allocation. 
* *Get ACS for a Study Area* - This tool returns ACS data for the selected study area for select ACS concepts. Some data processing and cleaning is done on the back end for more out-of-the-box usable varaibles. 
* *Get Overture or OSM Data* - This tool returns OSM and/or Overture points, lines, or polygons for the bounding box of a selected study area.
* *Generate Isochrones from Geometry* - This tool returns isochrones for points or lines using Kyle Walker's [mapboxapi](https://walker-data.com/mapboxapi/) library. Custom modes and time bands can be set. 

## Replica Toolbox
* *BigQuery Replica Data Pull* - This tool takes in a feature layer as well as the email used to authenticate to [Replica](https://replicahq.com) trip tables in BigQuery. It returns the trips that end within the study area boundary and returns them as a table, containing mode, distance, purpose, start, end, and home locations (lat and long) for each trip that ends in the study area. The Lat and Lon values are in WGS 84 (4326 WKID/ESPG)
* *Get Replica Network Volumes Equity Areas* - This tool takes in a study area feature class and optionally an equity areas feasture class. It returns loaded network volumes (not including home trips) that end within the study area boundary. If equity areas are returned, it only returns loaded volumes for population who live within the defined equity areas. 