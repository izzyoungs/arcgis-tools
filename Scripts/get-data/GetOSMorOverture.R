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
  
  output <- out_params[[1]]
  
  # unlist the feature types from boolean to "Amenities", "Streets", or "Buildings"
  all_options <- c("Amenities", "Streets", "Buildings")
  feature_types_corrected <- unlist(strsplit(feature_types, " "))
  boolean_vector <- feature_types_corrected == "true"
  selected_type <- all_options[boolean_vector]
  
  arc.progress_pos(10)
  print("Extracting bounding box from input study area...")
  
  # Convert study area to sf and get bounding box
  study_area_sf <- arc.data2sf(study_area) |>
    st_transform(4326) |> 
    st_make_valid()
  bbox <- st_bbox(study_area_sf)
  
  arc.progress_pos(30)
  

# OSM ---------------------------------------------------------------------
  
  if (any(data_source %in% c("OSM", "Both"))) {
    
    osm_query <- opq(bbox = bbox)
    

## OSM Amenities -----------------------------------------------------------
    
    # Process different geometry types
    if ("Amenities" %in% selected_type) {
      
      print("Fetching OSM amenities...")
      
      osm_amenities <- osm_query |>
        add_osm_feature(key = "amenity") |>
        osmdata_sf()
      
      osm_amentities_sf <- osm_amenities$osm_points |> 
        select(osm_id, name, geometry) |> 
        st_make_valid()
      
      print("Writing OSM amenities to output geodatabase...")
      arc.write(paste0(output, "_OSM_Amenities"), osm_amentities_sf, overwrite = TRUE)
      
    }

# OSM Streets -------------------------------------------------------------    

    if ("Streets" %in% selected_type) {
      
      print("Fetching OSM streets...")
      
      osm_streets <- osm_query |>
        add_osm_feature(key = "highway") |>
        osmdata_sf()
      
      osm_streets_sf <- osm_streets$osm_lines |> 
        select(osm_id, name, geometry) |> 
        st_make_valid()
      
      print("Writing OSM streets to output geodatabase...")
      arc.write(paste0(output, "_OSM_Streets"), osm_streets_sf, overwrite = TRUE)
      
    }
    
# OSM Buildings -----------------------------------------------------------

    if ("Buildings" %in% selected_type) {
      
      print("Fetching OSM buildings...")
      
      osm_buildings <- osm_query |>
        add_osm_feature(key = "building") |>
        osmdata_sf()
      
      osm_buildings_sf <- osm_buildings$osm_polygons |> 
        select(osm_id, name, amenity, geometry) |> 
        st_make_valid()
      
      print("Writing OSM buildings to output geodatabase...")
      arc.write(paste0(output, "_OSM_Buildings"), osm_buildings_sf, overwrite = TRUE)
    }
  }
  
# Overture ---------------------------------------------------------------
  
  if (any(data_source %in% c("Overture", "Both"))) {
    
    bbox_overture <- bbox |>
      as.vector()
    

## Overture Amenities ------------------------------------------------------
    
    if ("Amenities" %in% selected_type) {
      
      print("Fetching Overture amenities...")
      
      suppressWarnings({
        overture_amentiy <- record_batch_reader(schema_type = 'place', bbox = bbox_overture) |>
          suppressMessages()
        
        overture_amentiy_sf <- overture_amentiy |>
          mutate(geometry = st_as_sfc(geometry, EWKB = TRUE),
                 name = names[[1]],
                 primary_category = categories$primary, 
                 secondary_categories = purrr::map_chr(categories$alternate, ~ paste(.x, collapse = ", ")),
                 confidence = confidence[[1]]) |>
          select(id, name, primary_category, secondary_categories, confidence, geometry) |>
          st_as_sf(crs = 4326)

      })

      if (nrow(overture_amentiy_sf) == 0) {
        print("No amenities found in the specified bounding box in Overture.")
      } else {
        print("Writing Overture amenities to output geodatabase...")
        arc.write(paste0(output, "_Overture_Amenities"), overture_amentiy_sf, overwrite = TRUE)
      }
    
    }
    
# Overture Streets -------------------------------------------------------

    if ("Streets" %in% selected_type) {
      
      print("Fetching Overture streets...")
      
      suppressWarnings({
        overture_streets <- record_batch_reader(schema_type = 'segment', bbox = bbox_overture) |>
          suppressMessages()
        
        overture_streets_sf <- overture_streets |>
          mutate(name = names[[1]],
                 class = class[[1]]) |>
          select(id, name, class, geometry) |>
          st_as_sf(crs = 4326)
        
      })
      
      if (nrow(overture_streets_sf) == 0) {
        print("No streets found in the specified bounding box in Overture.")
      } else {
        print("Writing Overture streets to output geodatabase...")
        arc.write(paste0(output, "_Overture_Streets"), overture_streets_sf, overwrite = TRUE)
      }
    }
    
# Overture Buildings -----------------------------------------------------
    
    if ("Buildings" %in% selected_type) {
      
      print("Fetching Overture buildings...")
      
      suppressWarnings({
        overture_buildings <- record_batch_reader(schema_type = 'building', bbox = bbox_overture)
        
        overture_buildings_sf <- overture_buildings |>
          mutate(name = names[[1]],
                 subtype = subtype[[1]], 
                 height = height[[1]],
                 source = sources[[1]]$dataset[[1]],
                 confidence = sources[[1]]$confidence[[1]]) |>
          select(id, name, subtype, height, source, confidence, geometry) |>
          st_as_sf(crs = 4326)
      })
      
      print("Writing Overture buildings to output geodatabase...")
      arc.write(paste0(output, "_Overture_Buildings"), overture_buildings_sf, overwrite = TRUE)
    }
  }
  
  arc.progress_pos(100)
  print("Process complete.")
}