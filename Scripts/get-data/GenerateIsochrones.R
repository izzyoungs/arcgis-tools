#' Tool Name: Generate isochrones from geometry
#' Purpose: Get isochrones from geometry
#' Author: Izzy Youngs
#' Date: 2025-05-01
#' Copyright: © 2025 Izzy Youngs
#'
#' Inputs:
#'  - input_geom: Geometry (point or line)
#'  - input_profile: Profile (driving, walking, cycling)
#'  - input_time: Time (in minutes)
#'
#' Outputs:
#'   - An output feature class containing the isochrones
# -----------------------------------------------------------------------


tool_exec <- function(in_params, out_params) {
  # Load libraries
  arc.progress_label("Loading libraries")
  suppressMessages({
    library(sf)
    library(tidyverse)
    library(mapboxapi)
    library(lwgeom)
    library(crsuggest)
    library(units)
    library(arcgisbinding)
  })
  arc.check_product()
  
  arc.progress_label("Running script...")
  
  # Extract input parameters
  print("Extracting input parameters")
  input_geom <- arc.open(in_params[[1]]) |> arc.select() # Geometry
  input_profile <- in_params[[2]] # Profile
  input_time <- in_params[[3]] |> as.numeric() # Time
  access_token <- in_params[[4]] # Access token
  output_path <- out_params[[1]]  # Output path
  
  if(length(access_token) == 0){access_token = NULL}
  
  input_profile <- lapply(input_profile, tolower)
  input_profile <- gsub("driving in traffic", "driving-traffic", input_profile)
  
  print(input_profile)
  
  # Load the study area
  print("Checking and loading geometry")
  input_geom_sf <- arc.data2sf(input_geom)
  
  # Get projected coordinate system 
  pcs <- suggest_crs(input_geom_sf) |>
    filter(crs_units == 'us-ft') |>
    slice(1L) |>
    pull(crs_code) |>
    as.numeric()
  
  input_geom_sf <- input_geom_sf |>
    mutate(unique_id = row_number()) |>
    st_transform(pcs) |>
    st_make_valid()
  
  geometry_type <- st_geometry_type(input_geom_sf, by_geometry = FALSE)
  
  # If geometry type is line, print "Converting line to points", else print "Geometry is a point"
  if(geometry_type == "LINESTRING") {
    print("Geometry is a line feature class. Generating points along lines.")
    
    # Convert line to points every 300 feet
    sampled_pts <- st_line_sample(input_geom_sf, density = 1 / set_units(500, "ft"), type = "regular")|>
      suppressWarnings()
    
    input_geom_points <- st_sf(input_geom_sf, geometry = sampled_pts) |>
      st_cast("POINT") |>
      suppressWarnings()

  } else if(geometry_type == "POINT") {
    print("Geometry is a point feature class.")
  } else {
    stop("Input geometry must be a point or line.")
  }
  
  print("Generating isochrones from points...")
  
  # Generate isochrones
  isochrones <- mb_isochrone(
    input_geom_sf,
    profile = input_profile,
    time = input_time,
    distance = NULL,
    depart_at = "2025-03-31T09:00",
    denoise = .25,
    generalize = 5,
    access_token = access_token,
    geometry = "polygon",
    output = "sf",
    rate_limit = 300,
    keep_color_cols = FALSE,
    id_column = "unique_id")

  # Save the output geometry
  arc.write(output_path, isochrones, overwrite = TRUE, validate = TRUE) |>
    suppressMessages()|>
    suppressWarnings()
  } 

