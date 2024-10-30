# Toolbox Summary
This repository holds a collection of custom ArcGIS Geoprocessing scripts for ArcGIS Pro 3.2. This repository also contains an atbx to assist in automated running of repeated tasks. The tools are described below:
* *Guess CRS* - This geoprocessing tool was created with R with the help of [Kyle Walker](https://walker-data.com/)'s [crssuggest](https://github.com/walkerke/crsuggest) library. The tool takes a custom bounding box and returns a list of possible projections.
* *Create Feature Datasets* - This geoprocessing tool takes a list of feature dataset names, a workspace, and a projection, and writes all of the feature datasets to the workspace with the selected projection settings.
* *Copy Layers to Feature Dataset* - This tool takes a series of layers as an input as well as names of feature datasets and copies all the feature layers to the feature dataset. It will create new feature datasets if they do not exist. 
* *BigQuery Replica Data Pull* - This tool takes in a feature layer as well as the email used to authenticate to [Replica](https://replicahq.com) trip tables in BigQuery. It returns the trips that end within the study area boundary and returns them as a table, containing mode, distance, purpose, start, end, and home locations (lat and long) for each trip that ends in the study area. The Lat and Lon values are in WGS 84 (4326 WKID/ESPG)
* *Enrich Layer* - **This tool is under development**. It will grab ACS variables and enrich the input features based on variables and proportional allocation. 
* *Pivot Fields* - This tool takes an input dataset where each row represents a single unit of analysis but contains categorical data that needs to be converted to numeric/dummy variables. It takes the fields as an input and pivots the features so that each possible categorical variable is its own field with a 0 or 1 indicating row inclusion. 
* *Predominant Category* - This tool is designed to reflect the logic within ArcGIS Online's predominant category symbology. It takes multiple fields as inputs and calcualtes which field is predominant for the feature and returns the field and the strength of that predominance. 
* *Update Aliases* - This tool takes an input feature layer and a csv and updates the aliases based on the csv's first two columns. The first column represents the field name and the second represents the updated alias. 
* *Proportional Allocation* - **This tool is under development**. It will use Esri's methodology for using population in census blocks to proportionally allocate population to non-census geometries. 

# Guess CRS
| Parameter | Type | Description |
|---|---|---|
| Extent Envelope |     Envelope | Click the "map" button to automatically enter the active map's view as an extent envelope. |
| Coordinate Reference System | Coordinate Reference System | Select the spatial reference for the active map used to select the extent envelope.  |

# Create Feature Datasets
| Parameter | Type | Description |
|---|---|---|
| Feature Dataset Names | String | The names of all the feature datasets to be created.  |
| Workspace | Workspace | The workspace where the feature datasets will be saved.  |
| Coordinate Reference System| Coordinate Reference System | The spatial reference of the feature datasets to be create in the workspace.  |

# Copy Layers to Feature Dataset
| Parameter | Type | Description |
|---|---|---|
| Workspace | Workspace | The workspace where the features will be copied. *Note*: You cannot have duplicate names in the same workspace, even if they are in different feature datasets.   |
| Feature Layers and Datasets | Value Table | The layers and the name of the feature dataset the layer should be copied to.  |
| Coordinate Reference System | Coordinate Reference System | The CRS of the feature dataset to be created.  |

# BigQuery Replica Data Pull
| Parameter | Type | Description |
|---|---|---|
| Feature Layer | Feature Layer | The feature layer where trip destinations will be grabbed from Spring 2024 Thursday Replica tables.   |
| Email Address | String | The email address used to authenticate to BigQuery.  |
| Output Table | Table | The output table name. Will contain mode, distance, purpose, start, end, and home locations (lat and long) for each trip that ends in the study area.  |

# Enrich Layer
**This Tool is Under Development and Currently Does Not Work**

# Pivot Fields
| Parameter | Type | Description |
|---|---|---|
| Feature Layer | Feature Layer | The feature layer which will be pivoted.    |
| Fields | Value Table | A list of categorical (string) fields which will be converted to fields and dummy variables.  |
| Output Feature Name | Feature Class | The output features with the updated fields.  |

# Predominant Category
| Parameter | Type | Description |
|---|---|---|
| Feature Layer | Feature Layer | The feature layer which will be assigned a predominant category.    |
| Fields | Value Table | A list of numeric fields which will be summed together and evaluated for which field is predominant within the feature.  |
| Output Feature Name | Feature Class | The output features with a predominant category field and the strength of that predominance.  |

# Update Aliases
| Parameter | Type | Description |
|---|---|---|
| Feature Layer | Feature Layer | The feature layer where the fields will be updated    |
| Fields CSV | CSV | A csv with the original field name and the updated alias.  |

# Proportional Allocation
**This Tool is Under Development and Currently Does Not Work**