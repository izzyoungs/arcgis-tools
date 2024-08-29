# Toolbox Summary
This repository holds a collection of custom ArcGIS Geoprocessing scripts for ArcGIS Pro 3.2. This repository also contains an atbx to assist in automated running of repeated tasks. The tools are described below:
* *Guess CRS* - This geoprocessing tool was created with R with the help of [Kyle Walker](https://walker-data.com/)'s [crssuggest](https://github.com/walkerke/crsuggest) library. The tool takes a custom bounding box and returns a list of possible projections.
* *Create Feature Datasets* - This geoprocessing tool takes a list of feature dataset names, a workspace, and a projection, and writes all of the feature datasets to the workspace with the selected projection settings.
* *Copy Layers to Feature Dataset* - This tool takes a series of layers as an input as well as names of feature datasets and copies all the feature layers to the feature dataset. It will create new feature datasets if they do not exist. 

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
