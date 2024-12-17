tool_exec<- function(in_params, out_params){
  
  arc.progress_label("Loading libraries...")
  arc.progress_pos(0)

  suppressMessages({
    library(sf)
    library(tidyverse)
    library(tidycensus)
    library(tigris)
    library(arcgisbinding)
    arc.check_product()
  })
  
  arc.progress_label("Loading data...")
  
  input_polygons <- in_params[[1]]
  fields_to_apportion <- in_params[[2]]
  type_boolean <- in_params[[3]]
  target_polygons <- in_params[[4]]
  apportion_method <- in_params[[5]]
  weight_field <- in_params[[6]]
  output_features <- out_params[[1]]
  
  study_area <- arc.open(target_polygons) |>
    arc.select() |>
    arc.data2sf() |>
    st_transform(4269)|>
    st_cast("POLYGON") |>
    st_make_valid()
  
  # get the state and counties for the input polygons
  intersecting_counties <- counties(year = 2020) |>
    st_intersection(study_area) |>
    select(STATEFP, COUNTYFP) |>
    st_drop_geometry() |>
    suppressWarnings()
  
  state <- intersecting_counties$STATEFP[1]
  county <- intersecting_counties$COUNTYFP[1]
  
  # get the blocks for the study area
  blocks_customarea <- blocks(state = state, county = county, year = 2020) |>
    suppressMessages()
  
  blockgroups_customarea <- blocks_customarea |>
    st_drop_geometry() |>
    group_by(GEOID20) |>
    summarise(total_population = sum(POP20, na.rm = TRUE))
  
  block_centroids <- blocks_customarea |>
    st_centroid() |>
    left_join(blockgroups_customarea, by = "GEOID20") |>
    mutate(weight = POP20 / total_population) |>
    suppressWarnings()
  
  study_area_weights <- st_intersection(block_centroids, study_area) |>
    st_drop_geometry() |>
    suppressWarnings()
  
  
  
  # get the input polygons
  input_polygons <- arc.open(input_polygons) |>
    arc.select() |>
    arc.data2sf() |>
    st_transform(4269)|>
    st_cast("POLYGON") |>
    st_make_valid()
  
  # apportion each field based on weights 
  apportioned_data <- input_polygons |>
    st_intersection(study_area) |>
    st_drop_geometry() |>
    left_join(study_area_weights, by = c("GEOID" = "GEOID")) |>
    group_by(GEOID) |>
    summarise(across(all_of(fields_to_apportion), ~sum(.x * weight, na.rm = TRUE))) |>
    suppressWarnings()
  

  
  
  
  

  
  print(crs_suggestions)
}