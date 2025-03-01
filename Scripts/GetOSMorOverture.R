#' Tool Name: OSM & Overture Data Extractor
#' Purpose: Extract OpenStreetMap (OSM) and/or Overture data for a user-defined study area
#' Author: Izzy Youngs
#' Date: February 2025
#' Copyright: 2025

# Load required libraries
arc.progress_label("Loading libraries...")
suppressMessages({
  library(arcgisbinding)
  arc.check_product()
  library(sf)
  library(dplyr)
  library(osmdata)
  library(overturemapsr)
})

tool_exec <- function(in_params, out_params) {
  
  # Read input parameters
  study_area <- arc.open(in_params[[1]]) |> arc.select()
  data_source <- in_params[[2]]  # "OSM", "Overture", or "Both"
  feature_types <- in_params[[3]]  # "Amenities", "Streets", or "Buildings"
  output_gdb <- in_params[[4]]
  
  output <- out_params[[1]]
  
  print(output_gdb)
  
  # unlist the feature types from boolean to "Amenities", "Streets", or "Buildings"
  all_options <- c("Amenities", "Streets", "Buildings")
  feature_types_corrected <- unlist(strsplit(feature_types, " "))
  boolean_vector <- feature_types_corrected == "true"
  selected_type <- all_options[boolean_vector]
  
  arc.progress_pos(10)
  print("Extracting bounding box from input study area...")
  
  # Convert study area to sf and get bounding box
  study_area_sf <- arc.data2sf(study_area)
  bbox <- st_bbox(study_area_sf)
  
  arc.progress_pos(30)
  
  if (any(data_source %in% c("OSM", "Both"))) {
    
    osm_query <- opq(bbox = bbox)
    
    # Process different geometry types
    if (selected_type %in% "Amenities") {
      
      print("Fetching OSM amenities...")
      
      osm_amenities <- osm_query |>
        add_osm_feature(key = "amenity") |>
        osmdata_sf()
      
      osm_amentities_sf <- osm_amenities$osm_points |> 
        select(osm_id, name, geometry) |> 
        st_make_valid()
      
      print("Writing OSM amenities to output geodatabase...")
      arc.write(file.path(output_gdb, "OSM_Amenities"), osm_amentities_sf, overwrite = TRUE)
      
    }
    if (selected_type %in% "Streets") {
      
      print("Fetching OSM streets...")
      
      osm_streets <- osm_query |>
        add_osm_feature(key = "highway") |>
        osmdata_sf()
      
      osm_streets_sf <- osm_streets$osm_lines |> 
        select(osm_id, name, geometry) |> 
        st_make_valid()
      
      print("Writing OSM streets to output geodatabase...")
      arc.write(file.path(output_gdb, "OSM_Streets"), osm_streets_sf, overwrite = TRUE)
      
    }
    if (selected_type %in% "Buildings") {
      
      print("Fetching OSM buildings...")
      
      osm_buildings <- osm_query |>
        add_osm_feature(key = "building") |>
        osmdata_sf()
      
      osm_buildings_sf <- osm_buildings$osm_polygons |> 
        select(osm_id, name, amenity, geometry) |> 
        st_make_valid()
      
      print("Writing OSM buildings to output geodatabase...")
      arc.write(file.path(output_gdb, "/OSM_Buildings"), osm_buildings_sf, overwrite = TRUE)
    }
  }
  
  if (any(data_source %in% c("Overture", "Both"))) {
    
    bbox_overture <- bbox |>
      as.vector()
    
    if (selected_type %in% "Amenities") {
      
      print("Fetching Overture amenities...")
      
      suppressWarnings({
        overture_amentiy <- record_batch_reader(overture_type = 'place', bbox = bbox_overture)
        overture_amentiy_sf <- as.data.frame(overture_amentiy)
        overture_amentiy_sf$name <- overture_amentiy_sf$names[[1]]
        overture_amentiy_sf$category <- overture_amentiy_sf$categories[[1]]
        
        overture_amentiy_sf_cleaned <- overture_amentiy_sf |> 
          select(c('id', 'geometry', 'name', 'category', 'confidence'))
      })
      
      print("Writing Overture amenities to output geodatabase...")
      arc.write(file.path(output_gdb, "/Overture_Amenities"), overture_amentiy_sf_cleaned, overwrite = TRUE)
    
    }
    if (selected_type %in% "Streets") {
      
      print("Fetching Overture streets...")
      
      suppressWarnings({
        overture_streets <- record_batch_reader(overture_type = 'segments', bbox = bbox_overture)
        overture_streets_sf <- as.data.frame(overture_streets)
        
        overture_streets_sf$name <- overture_streets_sf$name[[1]]
        overture_streets_sf$class <- overture_streets_sf$class[[1]]
        
        overture_streets_cleaned <- overture_streets_sf |> 
          select(c('id', 'geometry', 'name', 'class', 'confidence'))
      })
      
      print("Writing Overture streets to output geodatabase...")
      arc.write(file.path(output_gdb, "/Overture_Streets"), overture_streets_cleaned, overwrite = TRUE)
    }
    
    if (selected_type %in% "Buildings") {
      
      print("Fetching Overture buildings...")
      
      suppressWarnings({
        overture_buildings <- record_batch_reader(overture_type = 'building', bbox = bbox_overture)
        overture_buildings_sf <- as.data.frame(overture_buildings)
        
        overture_buildings_sf$name <- overture_buildings_sf$name[[1]]
        overture_buildings_sf$subtype <- overture_buildings_sf$subtype[[1]]
        overture_buildings_sf$height <- overture_buildings_sf$height[[1]]
        overture_buildings_sf$source <- overture_buildings_sf$source[[1]]
        
        overture_buildings_cleaned <- overture_buildings_sf |> 
          select(c('id', 'geometry', 'name', 'subtype', 'height', 'source', 'confidence'))
      })
      
      print("Writing Overture buildings to output geodatabase...")
      arc.write(file.path(output_gdb, "/Overture_Buildings"), overture_buildings_cleaned, overwrite = TRUE)
    }
  }


  # out_params[[1]] <- output_fcs
  
  arc.progress_pos(100)
  print("Process complete.")
}