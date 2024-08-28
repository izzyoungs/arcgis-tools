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
import os, updateschema
from sys import argv
try:
    import arcpy
except:
    arcpy.AddMessage("Could not import arcpy. Make sure you use Pro if the tool requires it.")

def CreateFeatureDataset(Workspace):
    """Create a feature dataset to store local data.
    Parameters:
    ----------------
    Workspace -- The workspace where the feature dataset will be created."""

    try:
        if Boolean == False:
            arcpy.AddMessage("Creating feature dataset...")

            # Process: Create Feature Dataset (Create Feature Dataset) (management)
            arcpy.management.CreateFeatureDataset(out_dataset_path=Workspace, out_name='LocalData', 
                                                spatial_reference="PROJCS[\"NAD_1983_2011_StatePlane_North_Carolina_FIPS_3200_Ft_US\",GEOGCS[\"GCS_NAD_1983_2011\",DATUM[\"D_NAD_1983_2011\",SPHEROID[\"GRS_1980\",6378137.0,298.257222101]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.0174532925199433]],PROJECTION[\"Lambert_Conformal_Conic\"],PARAMETER[\"False_Easting\",2000000.0],PARAMETER[\"False_Northing\",0.0],PARAMETER[\"Central_Meridian\",-79.0],PARAMETER[\"Standard_Parallel_1\",34.33333333333334],PARAMETER[\"Standard_Parallel_2\",36.16666666666666],PARAMETER[\"Latitude_Of_Origin\",33.75],UNIT[\"Foot_US\",0.3048006096012192]];-121841900 -93659000 3048.00609601219;-100000 10000;-100000 10000;3.28083333333333E-03;0.001;0.001;IsHighPrecision")[0]
        
            arcpy.AddMessage("Feature dataset has been created.")
    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

def CopyFeatures(Map):
    """Copy local data to the feature dataset.
        Parameters:
        ----------------
        Map -- The map containing the local data."""
    
    try:
        if Boolean == False:
            arcpy.AddMessage("Copying local data to the feature dataset...")
            FeatureDataset = os.path.join(Workspace, 'LocalData')
            aprx = arcpy.mp.ArcGISProject("CURRENT")
            m = aprx.listMaps(Map)[0]
            map_layers = m.listLayers()
            n = 0

            for lyr in map_layers:
                if lyr.isFeatureLayer:
                    lyrs = lyr.listLayers()
                    if not lyrs:
                        desc = arcpy.Describe(lyr)
                        if desc.shapeType == "Polyline":
                            n += 1
                            new_lyrs = str(lyr.longName)
                            new_lyrs = new_lyrs.replace(" ", "_").replace("-", "_").replace(".", "").replace("\\", "_") + f"_s{n}"
                            new_lyrs = f"fc_{new_lyrs}" if new_lyrs[0].isdigit() else new_lyrs
                            arcpy.FeatureClassToFeatureClass_conversion(lyr, FeatureDataset, new_lyrs)
                            arcpy.AddMessage(f"{new_lyrs} has been copied to the feature dataset.")

            arcpy.AddMessage("Local data has been copied to the feature dataset.")
    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

def UpdateFieldNames(Workspace,fds = 'LocalData'): 
    """Update field names in the feature dataset.
    Parameters:
    ----------------
    Workspace -- The workspace where the feature dataset is located.
    fds -- The feature dataset where the field names will be updated."""

    try:
        if Boolean == False:
            arcpy.AddMessage("Updating field names...")
            arcpy.env.workspace = Workspace
            n = 0
            for fc in arcpy.ListFeatureClasses(feature_dataset=fds):
                f = 0
                n += 1
                fields = arcpy.ListFields(fc)
                for field in fields:
                    f += 1
                    not_edit_fields = ["OID", "Geometry"]
                    if field.type not in not_edit_fields:
                        new_field_name = f"{field.name}_s{n}f{f}"
                        new_field_name = new_field_name[:31] # truncate to 31 characters
                        arcpy.AlterField_management(fc, field.name, new_field_name, new_field_name)
                arcpy.AddMessage(f"Field names have been updated for {fc}.")

            arcpy.AddMessage("Field names have been updated for all features in feature dataset.")
    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

def MergeData(MergedData,fds="LocalData"): # 03 - Merge Data
    """Merge data into a single feature class.
    Parameters:
    ----------------
    MergedData -- The feature class where the data will be merged."""

    try:
        arcpy.AddMessage("Merging data...")
        arcpy.Merge_management(arcpy.ListFeatureClasses(feature_dataset=fds), MergedData, add_source='ADD_SOURCE_INFO')

        schema_fields = updateschema.schema()
        
        merge_field = schema_fields[schema_fields['tag'] == 'merge']['field'].iloc[0]

        arcpy.management.AddField(MergedData, merge_field, "TEXT")

        with arcpy.da.UpdateCursor(MergedData, ["MERGE_SRC", merge_field]) as cursor:
            for row in cursor:
                row[1] = os.path.basename(row[0])
                cursor.updateRow(row)

        arcpy.AddMessage("The data has been merged successfully.")

        try:
            arcpy.AddMessage("Creating schema domains...")
            arcpy.management.CreateDomain(in_workspace=Workspace, 
                    domain_name="SchemaFieldDomains", 
                    domain_description="Schema Field Domains", 
                    field_type="TEXT", 
                    domain_type="CODED", 
                    split_policy="DEFAULT", 
                    merge_policy="DEFAULT")
        except:
            domains = arcpy.da.ListDomains(Workspace)
            for domain in domains:
                if domain.name == "SchemaFieldDomains":
                    coded_values = domain.codedValues
                    for code in list(coded_values.keys()):
                        arcpy.DeleteCodedValueFromDomain_management(Workspace, domain.name, code)

        try:
            arcpy.AddMessage("Creating script domains...")
            arcpy.management.CreateDomain(in_workspace=Workspace, 
                    domain_name="ScriptFieldDomains", 
                    domain_description="Script Field Domains", 
                    field_type="TEXT", 
                    domain_type="CODED", 
                    split_policy="DEFAULT", 
                    merge_policy="DEFAULT")
        except:
            domains = arcpy.da.ListDomains(Workspace)
            for domain in domains:
                if domain.name == "ScriptFieldDomains":
                    coded_values = domain.codedValues
                    for code in list(coded_values.keys()):
                        arcpy.DeleteCodedValueFromDomain_management(Workspace, domain.name, code)

        arcpy.AddMessage("Adding domain values...")

        for index, row in schema_fields.iterrows():
            if row['script'] != '':
                arcpy.management.AddCodedValueToDomain(in_workspace=Workspace, domain_name="SchemaFieldDomains", code=f"{row['field']}", code_description=f"{row['field']}")
                arcpy.management.AddCodedValueToDomain(in_workspace=Workspace, domain_name="ScriptFieldDomains", code=f"{row['script']}", code_description=f"{row['script']}")

        arcpy.AddMessage("Domain values are up-to-date.")

        arcpy.AddMessage("Creating field statistics table...")
        stats = ''

        for field in arcpy.ListFields(MergedData):
            stats += f"{field.name};"
        
        arcpy.management.FieldStatisticsToTable(in_table=MergedData, in_fields=stats, 
                                                out_location= Workspace,
                                                out_tables="ALL Merged_Local_Data_Fieldmap",
                                                group_by_field=None,
                                                out_statistics="FIELDNAME FieldName; FIELDTYPE FieldType; MODE Mode; MEAN Mean")
        

        arcpy.management.AddField(in_table="Merged_Local_Data_Fieldmap",
                                    field_name="Schema_Field",
                                    field_type="TEXT",
                                    field_precision=None,
                                    field_scale=None,
                                    field_length=None,
                                    field_alias="Schema Field",
                                    field_is_nullable="NULLABLE",
                                    field_is_required="NON_REQUIRED",
                                    field_domain="SchemaFieldDomains")
        
        arcpy.management.AddField(in_table="Merged_Local_Data_Fieldmap",
                                    field_name="Script_Field",
                                    field_type="TEXT",
                                    field_precision=None,
                                    field_scale=None,
                                    field_length=None,
                                    field_alias="Script Field",
                                    field_is_nullable="NULLABLE",
                                    field_is_required="NON_REQUIRED",
                                    field_domain="ScriptFieldDomains")
        
        arcpy.management.CreateFieldGroup(target_table="Merged_Local_Data_Fieldmap",
                                        name="ContingentValues",
                                        fields="Schema_Field;Script_Field",
                                        is_restrictive="DO_NOT_RESTRICT")
        
        for index, row in schema_fields.iterrows():
            if row['script'] != '':
                formatted_string = f"Schema_Field CODED_VALUE {row['field']}; Script_Field CODED_VALUE {row['script']}"
                arcpy.management.AddContingentValue(target_table="Merged_Local_Data_Fieldmap",
                                                    field_group_name="ContingentValues",
                                                    values=formatted_string,
                                                    subtype="",
                                                    retire_value="DO_NOT_RETIRE")

        arcpy.AddMessage("The script has completed successfully.")
    except arcpy.ExecuteError:
        arcpy.AddError(str(arcpy.GetMessages(2)))
    except Exception as e:
        arcpy.AddError(str(e.args[0]))

if __name__ == '__main__':
    # Define Inputs
    Map = arcpy.GetParameter(0)
    Workspace = arcpy.GetParameterAsText(1)
    Boolean = arcpy.GetParameter(2)
    MergedData = arcpy.GetParameterAsText(3)
    arcpy.env.overwriteOutput = True
    arcpy.env.workspace = Workspace
    CreateFeatureDataset(Workspace)
    CopyFeatures(Map)
    UpdateFieldNames(Workspace)
    MergeData(MergedData)